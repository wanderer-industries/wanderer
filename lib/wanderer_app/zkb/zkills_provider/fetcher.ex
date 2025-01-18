defmodule WandererApp.Zkb.KillsProvider.Fetcher do
  @moduledoc """
  Handles multi-page fetch from zKillboard for the last N hours.
  If fetched <15 min => skip. Uses `Parser` for final parse+store.
  """

  require Logger
  alias WandererApp.Zkb.KillsProvider.Parser
  alias WandererApp.Zkb.KillsProvider.KillsCache
  alias WandererApp.Esi
  alias ExRated

  # ~2 calls/sec
  @exrated_bucket :zkb_preloader_provider
  @exrated_interval_ms 5_000
  @exrated_max_requests 50

  # If we fetched this system within the last 15 min => skip
  @full_fetch_cache_expiry_ms 900_000
  # Each page returns up to 200 kills
  @page_size 200

  @zkillboard_api "https://zkillboard.com/api"

  @doc """
  Similar to `fetch_kills_for_systems/3`, but returns the updated state, too.
  (Used by the Preloader so we can track calls_count, etc.)
  """
  def fetch_kills_for_systems_with_state(system_ids, since_hours, state) when is_list(system_ids) do
    try do
      # Start with the state's current calls_count (or anything else)
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
        {:error, e, state}
    end
  end

  # A helper that calls fetch_kills_for_system
  # but increments the calls_count in `state`.
  defp fetch_kills_for_system_with_state(system_id, since_hours, state) do
    {:ok, state1} = increment_calls_count(state)

    case fetch_kills_for_system(system_id, since_hours, state1) do
      {:ok, kills, new_st} ->
        {:ok, kills, new_st}

      {:error, reason, new_st} ->
        {:error, reason, new_st}
    end
  end

  @doc """
  Fetch kills for a system from the zKillboard API, up to `since_hours`.
  If the system was recently fetched (<15 min), we short-circuit and return cached kills.

  Returns:
    - `{:ok, kills, new_state}` if successful
    - `{:error, reason, new_state}` if an error occurs
  """
  def fetch_kills_for_system(system_id, since_hours, %{calls_count: ccount} = state) do
    Logger.debug("""
    [KillsProvider.Fetcher] fetch_kills_for_system =>
      system=#{system_id}, since_hours=#{since_hours}, calls_count=#{ccount}
    """)

    if recently_fetched?(system_id) do
      age_ms = fetch_age_ms(system_id)
      kills = fetch_cached_kills(system_id)

      Logger.debug("""
      [KillsProvider.Fetcher] system=#{system_id} short-circuited (fetched #{age_ms}ms ago)
      => kills.size=#{length(kills)}
      """)

      {:ok, kills, state}
    else
      case do_multi_page_fetch(system_id, since_hours, 1, state) do
        {:ok, new_st} ->
          put_full_fetched_timestamp(system_id)
          kills = fetch_cached_kills(system_id)

          Logger.debug("""
          [KillsProvider.Fetcher] final kills => system=#{system_id}, count=#{length(kills)}
          """)

          {:ok, kills, new_st}

        {:error, reason, new_st} ->
          Logger.warning("[KillsProvider.Fetcher] multi-page error => #{inspect(reason)}")
          {:error, reason, new_st}
      end
    end
  rescue
    e ->
      Logger.error("[KillsProvider.Fetcher] EXCEPTION => system=#{system_id} => #{Exception.message(e)}")
      {:error, e, state}
  end


   @doc """
  Fetch kills for multiple systems. Loops over each system, re-using `fetch_kills_for_system/3`
  and returning a map of system_id => kills (or system_id => {:error, reason}).
  """
  def fetch_kills_for_systems(system_ids, since_hours, preloader_state) when is_list(system_ids) do
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
  catch
    e ->
      Logger.error("[KillsProvider.Fetcher] fetch_kills_for_systems => EXCEPTION => #{Exception.message(e)}")
      {:error, e}
  end

  defp do_multi_page_fetch(system_id, since_hours, page, state) do
    case do_fetch_page(system_id, page, since_hours, state) do
      # short-circuit if older kills found
      {:stop, new_st, :found_older} ->
        {:ok, new_st}

      # if < 200 => done
      {:ok, new_st, count} when count < @page_size ->
        {:ok, new_st}

      # exactly 200 => next page
      {:ok, new_st, _count} ->
        do_multi_page_fetch(system_id, since_hours, page + 1, new_st)

      {:error, reason, new_st} ->
        {:error, reason, new_st}
    end
  end

  defp do_fetch_page(system_id, page, since_hours, %{calls_count: _ccount} = st) do
    with :ok <- check_rate(),
         {:ok, st2} <- increment_calls_count(st),
         {:ok, resp} <- do_req_get(system_id, page, st2),
         partials when is_list(partials) <- parse_response_body(resp)
    do
      cutoff_dt = hours_ago(since_hours)

      {count_stored, older_found?} =
        Enum.reduce_while(partials, {0, false}, fn partial, {acc_count, _had_older} ->
          case parse_partial_if_recent(partial, cutoff_dt) do
            :older ->
              {:halt, {acc_count, true}}

            :ok ->
              {:cont, {acc_count + 1, false}}

            :skip ->
              {:cont, {acc_count, false}}
          end
        end)

      if older_found? do
        {:stop, st2, :found_older}
      else
        {:ok, st2, count_stored}
      end
    else
      {:error, :rate_limited} ->
        Logger.warning("[KillsProvider.Fetcher] RATE_LIMIT => sys_id=#{system_id}")
        {:error, :rate_limited, st}

      {:error, reason} ->
        Logger.warning("[KillsProvider.Fetcher] do_req_get => error=#{inspect(reason)} for sys_id=#{system_id}")
        {:error, reason, st}

      other ->
        Logger.warning("[KillsProvider.Fetcher] parse error => #{inspect(other)}")
        {:error, :unexpected, st}
    end
  end

  defp parse_partial_if_recent(%{"killmail_id" => k_id, "zkb" => %{"hash" => k_hash}} = partial, cutoff_dt) do
    with {:ok, full_km} <- fetch_full_killmail(k_id, k_hash),
         {:ok, dt} <- parse_killmail_time(full_km),
         false <- older_than_cutoff?(dt, cutoff_dt) do
      # Merge partial info into the full killmail before we parse & store
      enriched = Map.merge(full_km, %{"zkb" => partial["zkb"]})
      parse_and_store(enriched)
    else
      {:error, reason} ->
        Logger.warning("[KillsProvider.Fetcher] ESI fail => kill_id=#{k_id}, reason=#{inspect(reason)}")
        :skip

      true ->
        # The comparison returned `true` => older than cutoff
        :older

      :skip ->
        # parse_killmail_time failed
        :skip
    end
  end

  defp fetch_full_killmail(k_id, k_hash) do
    case Esi.get_killmail(k_id, k_hash) do
      {:ok, full_km} ->
        {:ok, full_km}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_killmail_time(full_km) do
    killmail_time_str = Map.get(full_km, "killmail_time", "")

    case DateTime.from_iso8601(killmail_time_str) do
      {:ok, dt, _offset} ->
        {:ok, dt}

      _ ->
        :skip
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

  defp do_req_get(system_id, page, %{calls_count: _n}) do
    url = "#{@zkillboard_api}/kills/systemID/#{system_id}/page/#{page}/"
    start_ms = System.monotonic_time(:millisecond)

    try do
      resp = Req.get!(url, decode_body: :json)
      elapsed = System.monotonic_time(:millisecond) - start_ms

      Logger.debug("[KillsProvider.Fetcher] GET #{url} => #{resp.status} (#{elapsed}ms)")

      if resp.status == 200, do: {:ok, resp}, else: {:error, {:http_status, resp.status}}
    rescue
      e ->
        Logger.error("[KillsProvider.Fetcher] do_req_get => exception: #{Exception.message(e)}")
        {:error, :exception}
    end
  end

  defp parse_response_body(%{status: 200, body: body}) when is_list(body), do: body
  defp parse_response_body(_), do: :not_list

  defp check_rate do
    case ExRated.check_rate(@exrated_bucket, @exrated_interval_ms, @exrated_max_requests) do
      {:ok, _count} ->
        :ok

      {:error, limit} ->
        Logger.warning("[KillsProvider.Fetcher] RATE_LIMIT => limit=#{inspect(limit)}")
        {:error, :rate_limited}
    end
  end

  defp increment_calls_count(%{calls_count: n} = st) do
    st2 = %{st | calls_count: n + 1}
    {:ok, st2}
  end

  defp recently_fetched?(system_id) do
    key = "zkb_system_fetched_at_#{system_id}"

    case WandererApp.Cache.lookup(key) do
      {:ok, ms} when is_integer(ms) ->
        now_ms = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
        age = now_ms - ms
        age < @full_fetch_cache_expiry_ms

      _ ->
        false
    end
  end

  defp put_full_fetched_timestamp(system_id) do
    now_ms = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
    key = "zkb_system_fetched_at_#{system_id}"
    WandererApp.Cache.put(key, now_ms)
  end

  defp fetch_age_ms(system_id) do
    key = "zkb_system_fetched_at_#{system_id}"

    case WandererApp.Cache.lookup(key) do
      {:ok, ms} when is_integer(ms) ->
        now_ms = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
        now_ms - ms

      _ ->
        -1
    end
  end

  @doc """
  Fetch kills for `system_id` from the local cache only.
  Returns a list of killmail maps (could be empty).
  """
  def fetch_cached_kills(system_id) do
    system_id
    |> KillsCache.get_system_killmail_ids()
    |> Enum.map(&KillsCache.get_killmail/1)
    |> Enum.reject(&is_nil/1)
  end

  defp hours_ago(h),
    do: DateTime.utc_now() |> DateTime.add(-h * 3600, :second)
end
