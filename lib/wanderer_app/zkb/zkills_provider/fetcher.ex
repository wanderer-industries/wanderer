defmodule WandererApp.Zkb.KillsProvider.Fetcher do
  @moduledoc """
  Low-level API for fetching killmails from zKillboard + ESI.
  """

  require Logger
  use Retry

  alias WandererApp.Zkb.KillsProvider.{Parser, KillsCache, ZkbApi}
  alias WandererApp.Utils.HttpUtil

  @page_size 200
  @max_pages 2

  @doc """
  Fetch killmails for multiple systems, returning a map of system_id => kills.
  """
  def fetch_kills_for_systems(system_ids, since_hours, state, _opts \\ [])
      when is_list(system_ids) do
    try do
      {final_map, final_state} =
        Enum.reduce(system_ids, {%{}, state}, fn sid, {acc_map, acc_st} ->
          case fetch_kills_for_system(sid, since_hours, acc_st) do
            {:ok, kills, new_st} ->
              {Map.put(acc_map, sid, kills), new_st}

            {:error, reason, new_st} ->
              Logger.debug(fn -> "[Fetcher] system=#{sid} => error=#{inspect(reason)}" end)
              {Map.put(acc_map, sid, {:error, reason}), new_st}
          end
        end)

      Logger.debug(fn ->
        "[Fetcher] fetch_kills_for_systems => done, final_map_size=#{map_size(final_map)} calls=#{final_state.calls_count}"
      end)

      {:ok, final_map}
    rescue
      e ->
        Logger.error("[Fetcher] EXCEPTION in fetch_kills_for_systems => #{Exception.message(e)}")
        {:error, e}
    end
  end

  @doc """
  Fetch killmails for a single system within `since_hours` cutoff.

  Options:
    - `:limit` => integer limit on how many kills to fetch (optional).
      If `limit` is nil (or not set), we fetch until we exhaust pages or older kills.
    - `:force` => if true, ignore the "recently fetched" check and forcibly refetch.

  Returns `{:ok, kills, updated_state}` on success, or `{:error, reason, updated_state}`.
  """
  def fetch_kills_for_system(system_id, since_hours, state, opts \\ []) do
    limit = Keyword.get(opts, :limit, nil)
    force? = Keyword.get(opts, :force, false)

    log_prefix = "[Fetcher] fetch_kills_for_system => system=#{system_id}"

    # Check the "recently fetched" cache if not forced
    if not force? and KillsCache.recently_fetched?(system_id) do
      cached_kills = KillsCache.fetch_cached_kills(system_id)
      final = maybe_take(cached_kills, limit)

      Logger.debug(fn ->
        "#{log_prefix}, recently_fetched?=true => returning #{length(final)} cached kills"
      end)

      {:ok, final, state}
    else
      Logger.debug(fn ->
        "#{log_prefix}, hours=#{since_hours}, limit=#{inspect(limit)}, force=#{force?}"
      end)

      cutoff_dt = hours_ago(since_hours)

      result =
        retry with:
                exponential_backoff(300)
                |> randomize()
                |> cap(5_000)
                |> expiry(120_000) do
          case do_multi_page_fetch(system_id, cutoff_dt, 1, 0, limit, state) do
            {:ok, new_st, total_fetched} ->
              # Mark system as fully fetched (to prevent repeated calls).
              KillsCache.put_full_fetched_timestamp(system_id)
              final_kills = KillsCache.fetch_cached_kills(system_id) |> maybe_take(limit)

              Logger.debug(fn ->
                "#{log_prefix}, total_fetched=#{total_fetched}, final_cached=#{length(final_kills)}, calls_count=#{new_st.calls_count}"
              end)

              {:ok, final_kills, new_st}

            {:error, :rate_limited, _new_st} ->
              raise ":rate_limited"

            {:error, reason, _new_st} ->
              raise "#{log_prefix}, reason=#{inspect(reason)}"
          end
        end

      case result do
        {:ok, kills, new_st} ->
          {:ok, kills, new_st}

        error ->
          Logger.error("#{log_prefix}, EXHAUSTED => error=#{inspect(error)}")
          {:error, error, state}
      end
    end
  rescue
    e ->
      Logger.error("[Fetcher] EXCEPTION in fetch_kills_for_system => #{Exception.message(e)}")
      {:error, e, state}
  end

  defp do_multi_page_fetch(_system_id, _cutoff_dt, page, total_so_far, _limit, state)
       when page > @max_pages do
    # No more pages
    {:ok, state, total_so_far}
  end

  defp do_multi_page_fetch(system_id, cutoff_dt, page, total_so_far, limit, state) do
    Logger.debug(
      "[Fetcher] do_multi_page_fetch => system=#{system_id}, page=#{page}, total_so_far=#{total_so_far}, limit=#{inspect(limit)}"
    )

    with {:ok, st1} <- increment_calls_count(state),
         {:ok, st2, partials} <- ZkbApi.fetch_and_parse_page(system_id, page, st1) do
      Logger.debug(fn ->
        "[Fetcher] system=#{system_id}, page=#{page}, partials_count=#{length(partials)}"
      end)

      {_count_stored, older_found?, total_now} =
        Enum.reduce_while(partials, {0, false, total_so_far}, fn partial,
                                                                 {acc_count, had_older, acc_total} ->
          # If we have a limit and reached it, stop immediately
          if reached_limit?(limit, acc_total) do
            {:halt, {acc_count, had_older, acc_total}}
          else
            case parse_partial(partial, cutoff_dt) do
              :older ->
                # Found an older kill => we can halt the entire multi-page fetch
                {:halt, {acc_count, true, acc_total}}

              :ok ->
                {:cont, {acc_count + 1, false, acc_total + 1}}

              :skip ->
                {:cont, {acc_count, had_older, acc_total}}
            end
          end
        end)

      cond do
        # If we found older kills, stop now
        older_found? ->
          {:ok, st2, total_now}

        # If we have a limit and just reached or exceeded it
        reached_limit?(limit, total_now) ->
          {:ok, st2, total_now}

        # If partials < @page_size, no more kills are left
        length(partials) < @page_size ->
          {:ok, st2, total_now}

        # Otherwise, keep going to next page
        true ->
          do_multi_page_fetch(system_id, cutoff_dt, page + 1, total_now, limit, st2)
      end
    else
      {:error, :rate_limited, stx} ->
        {:error, :rate_limited, stx}

      {:error, reason, stx} ->
        {:error, reason, stx}

      other ->
        Logger.warning("[Fetcher] Unexpected result => #{inspect(other)}")
        {:error, :unexpected, state}
    end
  end

  defp parse_partial(
         %{"killmail_id" => kill_id, "zkb" => %{"hash" => kill_hash}} = partial,
         cutoff_dt
       ) do
    # If we've already cached this kill, skip
    if KillsCache.get_killmail(kill_id) do
      :skip
    else
      # Actually fetch the full kill from ESI
      case fetch_full_killmail(kill_id, kill_hash) do
        {:ok, full_km} ->
          # Delegate the time check & storing to Parser
          Parser.parse_full_and_store(full_km, partial, cutoff_dt)

        {:error, reason} ->
          Logger.warning("[Fetcher] ESI fail => kill_id=#{kill_id}, reason=#{inspect(reason)}")
          :skip
      end
    end
  end

  defp parse_partial(_other, _cutoff_dt), do: :skip

  defp fetch_full_killmail(k_id, k_hash) do
    retry with: exponential_backoff(300) |> randomize() |> cap(5_000) |> expiry(30_000),
          rescue_only: [RuntimeError] do
      case WandererApp.Esi.get_killmail(k_id, k_hash) do
        {:ok, full_km} ->
          {:ok, full_km}

        {:error, :timeout} ->
          Logger.warning("[Fetcher] ESI get_killmail timeout => kill_id=#{k_id}, retrying...")
          raise "ESI timeout, will retry"

        {:error, :not_found} ->
          Logger.warning("[Fetcher] ESI get_killmail not_found => kill_id=#{k_id}")
          {:error, :not_found}

        {:error, reason} ->
          if HttpUtil.retriable_error?(reason) do
            Logger.warning(
              "[Fetcher] ESI get_killmail retriable error => kill_id=#{k_id}, reason=#{inspect(reason)}"
            )

            raise "ESI error: #{inspect(reason)}, will retry"
          else
            Logger.warning(
              "[Fetcher] ESI get_killmail failed => kill_id=#{k_id}, reason=#{inspect(reason)}"
            )

            {:error, reason}
          end

        error ->
          Logger.warning(
            "[Fetcher] ESI get_killmail failed => kill_id=#{k_id}, reason=#{inspect(error)}"
          )

          error
      end
    end
  end

  defp hours_ago(h),
    do: DateTime.utc_now() |> DateTime.add(-h * 3600, :second)

  defp increment_calls_count(%{calls_count: c} = st),
    do: {:ok, %{st | calls_count: c + 1}}

  defp reached_limit?(nil, _count_so_far), do: false

  defp reached_limit?(limit, count_so_far) when is_integer(limit),
    do: count_so_far >= limit

  defp maybe_take(kills, nil), do: kills
  defp maybe_take(kills, limit), do: Enum.take(kills, limit)
end
