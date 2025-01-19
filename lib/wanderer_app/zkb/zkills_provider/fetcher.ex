defmodule WandererApp.Zkb.KillsProvider.Fetcher do
  @moduledoc """
  Handles kills fetch from zKillboard for the last N hours.
  Uses `ZkbApi` for HTTP + parse, and `KillsCache` for caching logic.

  ## Key entry points

    - `fetch_limited_for_system/4` (single-page)
    - `fetch_kills_for_system/3` (multi-page)
    - `fetch_kills_for_systems_with_state_limited/4`
    - `fetch_kills_for_systems_with_state/3`
  """

  require Logger
  alias WandererApp.Zkb.KillsProvider.Parser
  alias WandererApp.Zkb.KillsProvider.KillsCache
  alias WandererApp.Zkb.KillsProvider.ZkbApi

  # For the "retry" library from hex.pm => {:retry, "~> 0.18.0"}
  use Retry

  @page_size 200

  @doc """
  Fetch kills for multiple systems, up to `limit` per system, returning updated state.
  Single-page only.
  """
  def fetch_kills_for_systems_with_state_limited(system_ids, since_hours, limit, state)
      when is_list(system_ids) do
    try do
      Enum.reduce(system_ids, {:ok, %{}, state}, fn sid, {:ok, acc_map, acc_st} ->
        case fetch_limited_for_system(sid, since_hours, limit, acc_st) do
          {:ok, kills, new_st} ->
            {:ok, Map.put(acc_map, sid, kills), new_st}

          {:error, reason, new_st} ->
            {:ok, Map.put(acc_map, sid, {:error, reason}), new_st}
        end
      end)
      |> case do
        {:ok, final_map, final_state} ->
          {:ok, final_map, final_state}
      end
    rescue
      e ->
        Logger.error("""
        [KillsProvider.Fetcher] EXCEPTION in fetch_kills_for_systems_with_state_limited
          system_ids=#{inspect(system_ids)}
          since_hours=#{inspect(since_hours)}
          limit=#{inspect(limit)}
          message=#{Exception.message(e)}
          stacktrace=#{Exception.format_stacktrace(__STACKTRACE__)}
        """)
        {:error, e, state}
    end
  end

  @doc """
  Single-page fetch (up to 200 kills) for one system, limited by `limit`.
  Short-circuits if recently fetched.
  """
  def fetch_limited_for_system(system_id, since_hours, limit, state) do
    {:ok, state1} = increment_calls_count(state)

    if KillsCache.recently_fetched?(system_id) do
      kills = KillsCache.fetch_cached_kills(system_id)
      {:ok, Enum.take(kills, limit), state1}
    else
      retry with: exponential_backoff(200)
             |> randomize()
             |> cap(2_000)
             |> expiry(10_000) do
        case do_partial_page_fetch(system_id, since_hours, limit, state1) do
          {:ok, new_st, kills} ->
            {:ok, new_st, kills}

          {:error, reason, new_st} ->
            # Raise triggers another retry attempt
            raise """
            [KillsProvider.Fetcher] do_partial_page_fetch failed:
              system_id=#{system_id}, reason=#{inspect(reason)}, state=#{inspect(new_st)}
            """
        end
      after
        {:ok, new_st, kills} ->
          KillsCache.put_full_fetched_timestamp(system_id)
          {:ok, kills, new_st}
      else
        # <== No rescue context => cannot use __STACKTRACE__
        exception ->
          Logger.error("""
          [KillsProvider.Fetcher] EXHAUSTED RETRIES => system_id=#{system_id}
            message=#{Exception.message(exception)}
          """)
          {:error, exception, state1}
      end
    end
  rescue
    e ->
      # Here we are in a rescue block => can use __STACKTRACE__
      Logger.error("""
      [KillsProvider.Fetcher] EXCEPTION in fetch_limited_for_system
        system_id=#{inspect(system_id)}
        since_hours=#{inspect(since_hours)}
        limit=#{inspect(limit)}
        message=#{Exception.message(e)}
        stacktrace=#{Exception.format_stacktrace(__STACKTRACE__)}
      """)
      {:error, e, state}
  end

  # Single-page partial fetch: fetches page=1 only
  defp do_partial_page_fetch(system_id, since_hours, limit, st) do
    try do
      case increment_calls_count(st) do
        {:ok, st2} ->
          case ZkbApi.fetch_and_parse_page(system_id, 1, st2) do
            {:ok, st3, partials} ->
              cutoff_dt = hours_ago(since_hours)

              Enum.reduce_while(partials, {[], 0}, fn partial, {acc_list, count} ->
                if count >= limit do
                  {:halt, {acc_list, count}}
                else
                  case parse_partial_if_recent(partial, cutoff_dt) do
                    :older ->
                      {:halt, {acc_list, count}}

                    :ok ->
                      {:cont, {[partial | acc_list], count + 1}}

                    :skip ->
                      {:cont, {acc_list, count}}
                  end
                end
              end)

              stored_kills = KillsCache.fetch_cached_kills(system_id)
              {:ok, st3, Enum.take(stored_kills, limit)}

            {:error, reason, st3} ->
              {:error, reason, st3}
          end

        {:error, reason} ->
          {:error, reason, st}
      end
    rescue
      e ->
        Logger.error("""
        [KillsProvider.Fetcher] EXCEPTION in do_partial_page_fetch
          system_id=#{inspect(system_id)}
          since_hours=#{inspect(since_hours)}
          limit=#{inspect(limit)}
          message=#{Exception.message(e)}
          stacktrace=#{Exception.format_stacktrace(__STACKTRACE__)}
        """)
        {:error, e, st}
    end
  end

  # ------------------------------------------------------
  # Multi-page fetch for one system
  # ------------------------------------------------------
  @doc """
  Fetch *all* kills for `system_id` in the last `since_hours`, across multiple pages.
  If cached, short-circuits. Returns `{:ok, kills, state} | {:error, reason, state}`.
  """
  def fetch_kills_for_system(system_id, since_hours, %{calls_count: _ccount} = state) do
    if KillsCache.recently_fetched?(system_id) do
      _age_ms = KillsCache.fetch_age_ms(system_id)
      kills = KillsCache.fetch_cached_kills(system_id)


      {:ok, kills, state}
    else
      case do_multi_page_fetch(system_id, since_hours, 1, state) do
        {:ok, new_st} ->
          KillsCache.put_full_fetched_timestamp(system_id)
          kills = KillsCache.fetch_cached_kills(system_id)
          {:ok, kills, new_st}

        {:error, reason, new_st} ->
          Logger.warning("[KillsProvider.Fetcher] multi-page error => #{inspect(reason)}")
          {:error, reason, new_st}
      end
    end
  rescue
    e ->
      Logger.error("""
      [KillsProvider.Fetcher] EXCEPTION in fetch_kills_for_system
        system_id=#{inspect(system_id)}
        since_hours=#{inspect(since_hours)}
        message=#{Exception.message(e)}
        stacktrace=#{Exception.format_stacktrace(__STACKTRACE__)}
      """)
      {:error, e, state}
  end

  # Multi-system fetch with state
  @doc """
  Similar to `fetch_kills_for_systems/3`, but returns updated state as well.
  """
  def fetch_kills_for_systems_with_state(system_ids, since_hours, state) when is_list(system_ids) do
    try do
      {final_map, final_state} =
        Enum.reduce(system_ids, {%{}, state}, fn sid, {acc_map, acc_st} ->
          case fetch_kills_for_system_with_state(sid, since_hours, acc_st) do
            {:ok, kills, new_st} ->
              {Map.put(acc_map, sid, kills), new_st}

            {:error, reason, new_st} ->
              {Map.put(acc_map, sid, {:error, reason}), new_st}
          end
        end)

      {:ok, final_map, final_state}
    rescue
      e ->
        Logger.error("""
        [KillsProvider.Fetcher] EXCEPTION in fetch_kills_for_systems_with_state
          system_ids=#{inspect(system_ids)}
          since_hours=#{inspect(since_hours)}
          message=#{Exception.message(e)}
          stacktrace=#{Exception.format_stacktrace(__STACKTRACE__)}
        """)
        {:error, e, state}
    end
  end

  defp fetch_kills_for_system_with_state(system_id, since_hours, state) do
    {:ok, state1} = increment_calls_count(state)

    case fetch_kills_for_system(system_id, since_hours, state1) do
      {:ok, kills, new_st} -> {:ok, kills, new_st}
      {:error, reason, new_st} -> {:error, reason, new_st}
    end
  end

  # Multi-system fetch (NO state returned)
  @doc """
  Fetch kills for multiple systems, ignoring updates to the state.
  Useful if you don't need the `calls_count` or other state data.
  """
  def fetch_kills_for_systems(system_ids, since_hours, preloader_state) when is_list(system_ids) do
    try do
      {final_map, _maybe_error} =
        Enum.reduce(system_ids, {%{}, nil}, fn sid, {acc_map, acc_error} ->
          case fetch_kills_for_system(sid, since_hours, preloader_state) do
            {:ok, kills, _st} ->
              {Map.put(acc_map, sid, kills), acc_error}

            {:error, reason, _st} ->
              {Map.put(acc_map, sid, {:error, reason}), reason}
          end
        end)

      {:ok, final_map}
    rescue
      e ->
        Logger.error("""
        [KillsProvider.Fetcher] fetch_kills_for_systems => EXCEPTION
          system_ids=#{inspect(system_ids)}
          since_hours=#{inspect(since_hours)}
          message=#{Exception.message(e)}
          stacktrace=#{Exception.format_stacktrace(__STACKTRACE__)}
        """)
        {:error, e}
    end
  end

  # ------------------------------------------------------
  # Recursive multi-page logic
  # ------------------------------------------------------
  defp do_multi_page_fetch(system_id, since_hours, page, state) do
    case do_fetch_page(system_id, page, since_hours, state) do
      {:stop, new_st, :found_older} ->
        {:ok, new_st}

      {:ok, new_st, count} when count < @page_size ->
        {:ok, new_st}

      {:ok, new_st, _count} ->
        do_multi_page_fetch(system_id, since_hours, page + 1, new_st)

      {:error, reason, new_st} ->
        {:error, reason, new_st}
    end
  end

  defp do_fetch_page(system_id, page, since_hours, st) do
    with {:ok, st2} <- increment_calls_count(st),
         {:ok, st3, partials} <- ZkbApi.fetch_and_parse_page(system_id, page, st2) do
      cutoff_dt = hours_ago(since_hours)

      {count_stored, older_found?} =
        Enum.reduce_while(partials, {0, false}, fn partial, {acc_count, _had_older} ->
          case parse_partial_if_recent(partial, cutoff_dt) do
            :older -> {:halt, {acc_count, true}}
            :ok    -> {:cont, {acc_count + 1, false}}
            :skip  -> {:cont, {acc_count, false}}
          end
        end)

      if older_found? do
        {:stop, st3, :found_older}
      else
        {:ok, st3, count_stored}
      end
    else
      {:error, reason, stX} ->
        {:error, reason, stX}

      other ->
        Logger.warning("[KillsProvider.Fetcher] parse error => #{inspect(other)}")
        {:error, :unexpected, st}
    end
  end

  # Parse partial if it's recent enough
  defp parse_partial_if_recent(%{"killmail_id" => k_id, "zkb" => %{"hash" => k_hash}} = partial, cutoff_dt) do
    with {:ok, full_km} <- fetch_full_killmail(k_id, k_hash),
         {:ok, dt} <- parse_killmail_time(full_km),
         false <- older_than_cutoff?(dt, cutoff_dt) do
      enriched = Map.merge(full_km, %{"zkb" => partial["zkb"]})
      parse_and_store(enriched)
    else
      {:error, reason} ->
        Logger.warning("[KillsProvider.Fetcher] ESI fail => kill_id=#{k_id}, reason=#{inspect(reason)}")
        :skip

      true -> :older
      :skip -> :skip
    end
  end

  defp fetch_full_killmail(k_id, k_hash) do
    case WandererApp.Esi.get_killmail(k_id, k_hash) do
      {:ok, full_km} -> {:ok, full_km}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_killmail_time(full_km) do
    killmail_time_str = Map.get(full_km, "killmail_time", "")

    case DateTime.from_iso8601(killmail_time_str) do
      {:ok, dt, _offset} -> {:ok, dt}
      _ -> :skip
    end
  end

  defp older_than_cutoff?(dt, cutoff_dt),
    do: DateTime.compare(dt, cutoff_dt) == :lt

  defp parse_and_store(enriched) do
    case Parser.parse_and_store_killmail(enriched) do
      {:ok, _ktime} -> :ok
      :skip -> :skip
      :older -> :older
      _other -> :skip
    end
  end

  # ------------------------------------------------------
  # Helpers
  # ------------------------------------------------------
  defp increment_calls_count(%{calls_count: n} = st) do
    st2 = %{st | calls_count: n + 1}
    {:ok, st2}
  end

  defp hours_ago(h),
    do: DateTime.utc_now() |> DateTime.add(-h * 3600, :second)
end
