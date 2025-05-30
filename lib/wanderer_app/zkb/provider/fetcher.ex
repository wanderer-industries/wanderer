defmodule WandererApp.Zkb.Provider.Fetcher do
  @moduledoc """
  Fetches killmails from zKB.

  • Parses partial → full killmails via Parser
  • Caches results via Cache
  • Handles rate limiting and retries
  """

  require Logger

  alias WandererApp.Zkb.Provider.{Cache, HttpClient, Parser}

  @type killmail_id :: pos_integer()
  @type system_id    :: pos_integer()
  @type killmail     :: map()
  @type fetch_opts   :: [
          limit: pos_integer(),
          force: boolean(),
          since_hours: pos_integer()
        ]

  @default_limit       5
  @default_since_hours 24

  #-------------------------------------------------
  # Single killmail
  #-------------------------------------------------

  @doc """
  Fetch and parse a single killmail by ID.
  Returns `{:ok, enriched_killmail}` or `{:error, reason}`.
  """
  @spec fetch_killmail(killmail_id()) :: {:ok, killmail()} | {:error, term()}
  def fetch_killmail(id) when is_integer(id) do
    case Cache.get_killmail(id) do
      {:ok, nil} ->
        fetch_and_parse_killmail(id)

      {:ok, enriched} ->
        {:ok, enriched}

      {:error, reason} ->
        Logger.warning("[Fetcher] Cache error for #{id}, retrying: #{inspect(reason)}")
        fetch_and_parse_killmail(id)
    end
  end

  defp fetch_and_parse_killmail(id) do
    # For individual killmail fetches, use a very old cutoff to avoid rejecting historical killmails
    # Individual fetches are typically for specific killmails and shouldn't be time-restricted
    cutoff = DateTime.utc_now() |> DateTime.add(-365 * 24 * 3600, :second)  # 1 year ago

    with {:ok, raw}      <- HttpClient.get_killmail(id),
         {:ok, enriched} <- Parser.parse_full_and_store(raw, raw, cutoff) do
      {:ok, enriched}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  #-------------------------------------------------
  # System-scoped killmails
  #-------------------------------------------------

  @doc """
  Fetch and parse killmails for a given system_id.
  Options:
    • `:limit` (default #{@default_limit})
    • `:force` (ignore recent cache)
    • `:since_hours` (default #{@default_since_hours})

  Returns `{:ok, [enriched_killmail]}` or `{:error, reason}`.
  """
  @spec fetch_killmails_for_system(system_id() | String.t(), fetch_opts()) ::
          {:ok, [killmail()]} | {:error, term()}
  def fetch_killmails_for_system(system_id, opts \\ [])

  def fetch_killmails_for_system(system_id, opts) when is_binary(system_id) do
    case Integer.parse(system_id) do
      {id, ""} -> fetch_killmails_for_system(id, opts)
      _ -> {:error, :invalid_system_id}
    end
  end

  def fetch_killmails_for_system(system_id, opts) when is_integer(system_id) do
    limit       = Keyword.get(opts, :limit, @default_limit)
    force       = Keyword.get(opts, :force, false)
    since_hours = Keyword.get(opts, :since_hours, @default_since_hours)


    if force || not Cache.recently_fetched?(system_id) do
      do_fetch_killmails_for_system(system_id, limit, since_hours)
    else
      case Cache.get_killmails_for_system(system_id) do
        {:ok, killmails} ->
          # Cache always contains enriched killmails, return as-is
          {:ok, killmails}

        {:error, reason} ->
          Logger.warning("[Fetcher] Cache error for system #{system_id}, falling back to fresh fetch: #{inspect(reason)}")
          do_fetch_killmails_for_system(system_id, limit, since_hours)
      end
    end
  end

  defp do_fetch_killmails_for_system(system_id, limit, since_hours) do
    with {:ok, raws} <- HttpClient.get_system_killmails(system_id) do
      # API always returns raw killmails, always process them
      cutoff = DateTime.utc_now() |> DateTime.add(-since_hours * 3600, :second)

      kills =
        raws
        |> Enum.take(limit)
        |> parse_until_older(cutoff)

      Cache.put_full_fetched_timestamp(system_id)
      {:ok, kills}
    else
      {:error, reason} ->
        Logger.error("[Fetcher] API error for system #{system_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Stop parsing as soon as we hit an "older" kill
  defp parse_until_older([], _cutoff), do: []
  defp parse_until_older(raws, cutoff) when is_list(raws) do
    raws
    |> Enum.reduce_while([], fn raw, acc ->
      # API returns raw killmails, always parse them
      case Parser.parse_partial(raw, cutoff) do
        {:ok, enriched} when is_map(enriched) ->
          {:cont, [enriched | acc]}

        {:ok, :kill_skipped} ->
          {:cont, acc}

        :older ->
          {:halt, acc}

        {:error, {:enrichment_failed, _}} ->
          Logger.warning("[Fetcher] Enrichment failed for killmail: #{inspect(raw["killmail_id"])}")
          {:cont, acc}

        {:error, reason} ->
          Logger.error("[Fetcher] parse_partial failed for #{inspect(raw["killmail_id"])}: #{inspect(reason)}")
          {:cont, acc}
      end
    end)
    |> Enum.reverse()
  end

  #-------------------------------------------------
  # Batch fetch
  #-------------------------------------------------

  @doc """
  Fetch killmails for multiple systems in parallel.
  Returns a map `%{system_id => {:ok, kills} | {:error, reason}}`.
  """
  @spec fetch_killmails_for_systems([system_id()], fetch_opts()) ::
          %{system_id() => {:ok, [killmail()]} | {:error, term()}}
  def fetch_killmails_for_systems(system_ids, opts \\ []) when is_list(system_ids) do
    system_ids
    |> Task.Supervisor.async_stream(
      WandererApp.TaskSupervisor,
      &safe_fetch_for_system(&1, opts),
      max_concurrency: 8,
      timeout: 30_000
    )
    |> Enum.map(fn
      {:ok, {sid, result}} -> {sid, result}
      {:exit, {sid, reason}} ->
        Logger.error("[Fetcher] Task exit for system #{sid}: #{inspect(reason)}")
        {sid, {:error, {:task_exit, reason}}}
      {:exit, reason} ->
        # This should not happen with our safe wrapper, but kept as fallback
        Logger.error("[Fetcher] Unexpected task exit without system ID: #{inspect(reason)}")
        {:unknown_system, {:error, {:unexpected_exit, reason}}}
    end)
    |> Enum.reject(fn {sid, _result} -> sid == :unknown_system end)
    |> Map.new()
  end

  # Safe wrapper that ensures system ID is always preserved, even on crashes
  defp safe_fetch_for_system(system_id, opts) do
    try do
      result = fetch_killmails_for_system(system_id, opts)
      {system_id, result}
    catch
      kind, reason ->
        Logger.error("[Fetcher] Task failed for system #{system_id}: #{inspect({kind, reason})}")
        {system_id, {:error, {:task_failed, kind, reason}}}
    rescue
      error ->
        Logger.error("[Fetcher] Task error for system #{system_id}: #{inspect(error)}")
        {system_id, {:error, {:task_error, error}}}
    end
  end

end
