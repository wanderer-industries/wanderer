defmodule WandererApp.Zkb.Provider.Parser do
  @moduledoc """
  Parses and stores killmails from zKillboard (partial) or ESI (full).
  Combines partial and full data, validates time, enriches, and caches results.
  """

  require Logger

  alias WandererApp.Esi.ApiClient
  alias WandererApp.Zkb.Provider.Parser.{Core, TimeHandler, Enricher, CacheHandler}
  alias WandererApp.Utils.HttpUtil

  @type killmail :: map()
  @type parse_result :: {:ok, killmail()} | {:ok, :kill_skipped} | :older | :skip | {:error, term()}

  # How far back to accept kills (in seconds)
  @cutoff_seconds 3_600
  # Number of retries for transient ESI failures
  @api_retry_count 3
  # Delay between retries in milliseconds
  @retry_delay_ms 1_000

  # HTTP status codes that indicate retriable errors
  @retriable_http_codes [502, 503, 504]

  @doc """
  Entry-point for handling any killmail payload.
  Calculates a cutoff timestamp (UTC now minus cutoff seconds) and parses.
  """
  @spec parse_and_store_killmail(killmail()) :: {:ok, killmail()} | :older | :skip
  def parse_and_store_killmail(%{} = km) do
    cutoff = DateTime.utc_now() |> DateTime.add(-@cutoff_seconds, :second)
    do_parse(km, cutoff)
  end
  def parse_and_store_killmail(_), do: :skip

  @doc """
  Merges a full killmail with its partial zKB envelope and parses it.
  """
  @spec parse_full_and_store(killmail(), killmail(), DateTime.t()) ::
          {:ok, killmail()} | :older | :skip
  def parse_full_and_store(full, %{"zkb" => zkb}, cutoff) when is_map(full) do
    full
    |> Map.put("zkb", zkb)
    |> do_parse(cutoff)
  end
  def parse_full_and_store(_, _, _), do: :skip

  @doc """
  Fetches and parses a partial killmail via ESI.
  Retries on transient failures like timeouts or network errors.
  """
  @spec parse_partial(killmail(), DateTime.t()) :: parse_result()
  def parse_partial(%{"killmail_id" => id, "zkb" => %{"hash" => hash}} = partial, cutoff) do
    HttpUtil.retry_with_backoff(
      fn ->
        case ApiClient.get_killmail(id, hash) do
          {:ok, full} ->
            full
            |> Map.put("zkb", partial["zkb"])
            |> do_parse(cutoff)
          {:error, reason} ->
            Logger.error("[ZkbParser] parse_partial fetch failed for #{id}: #{inspect(reason)}")
            # Convert retriable errors to exceptions so HttpUtil.retry_with_backoff can handle them
            if is_retriable_error?(reason) do
              raise %HttpUtil.ConnectionError{message: "#{inspect(reason)}"}
            else
              {:error, reason}
            end
        end
      end,
      max_retries: @api_retry_count,
      base_delay: @retry_delay_ms,
      rescue_only: [HttpUtil.ConnectionError, HttpUtil.TimeoutError, HttpUtil.RateLimitError]
    )
  end
  def parse_partial(_, _), do: {:error, :invalid_killmail}

  @doc """
  Parses a full killmail directly, without any fetching.
  """
  @spec parse_full(killmail(), DateTime.t()) :: {:ok, killmail()} | :older | :skip
  def parse_full(km, cutoff), do: do_parse(km, cutoff)

  @spec do_parse(killmail(), DateTime.t()) :: parse_result()
  defp do_parse(%{"killmail_id" => id} = km, cutoff) do
    parse_result =
      with {:ok, {km_with_time, time_dt}} <- TimeHandler.validate_killmail_time(km, cutoff),
           {:ok, built}        <- Core.build_kill_data(km_with_time, time_dt),
           {:ok, enriched}     <- Enricher.enrich_killmail(built) do
        CacheHandler.store_killmail(enriched)
      end

    case parse_result do
      {:ok, %{} = stored} ->
        handle_count_update(stored, id)

      {:ok, :kill_skipped} ->
        {:ok, :kill_skipped}

      :older ->
        :older

      :skip ->
        {:ok, :kill_skipped}

      {:error, reason} ->
        Logger.error("[ZkbParser] parsing failed for #{id}: #{inspect(reason)}")
        {:error, reason}

      other ->
        Logger.error("[ZkbParser] unexpected result for #{id}: #{inspect(other)}")
        {:error, {:unexpected_result, other}}
    end
  end
  defp do_parse(_, _), do: {:ok, :kill_skipped}

  @spec handle_count_update(killmail(), integer() | binary()) :: {:ok, killmail()}
  defp handle_count_update(stored, id) do
    case CacheHandler.update_kill_count(stored) do
      :ok -> {:ok, stored}
      :skip -> {:ok, stored}
      other ->
        Logger.error("[ZkbParser] update_kill_count #{inspect(other)} for #{id}")
        {:ok, stored}
    end
  end

  # Check if an error should be retried - combines HttpUtil's network errors with ESI-specific errors
  defp is_retriable_error?(reason) do
    HttpUtil.retriable_error?(reason) ||
      case reason do
        :network_error -> true
        :bad_gateway -> true
        :service_unavailable -> true
        :gateway_timeout -> true
        {:http_error, code} when code in @retriable_http_codes -> true
        _ -> false
      end
  end
end
