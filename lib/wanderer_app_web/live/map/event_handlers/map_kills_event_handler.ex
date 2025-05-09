defmodule WandererAppWeb.MapKillsEventHandler do
  @moduledoc """
  Handles kills-related UI/server events.
  """

  use WandererAppWeb, :live_component
  require Logger

  alias WandererAppWeb.{MapEventHandler, MapCoreEventHandler}
  alias WandererApp.Zkb.KillsProvider
  alias WandererApp.Zkb.KillsProvider.KillsCache

  def handle_server_event(
        %{event: :init_kills},
        %{
          assigns: %{
            map_id: map_id
          }
        } = socket
      ) do
    {:ok, kills} = WandererApp.Cache.lookup("map_#{map_id}:zkb_kills", Map.new())

    socket
    |> MapEventHandler.push_map_event(
      "map_updated",
      %{
        kills:
          kills
          |> Enum.filter(fn {_, kills} -> kills > 0 end)
          |> Enum.map(&map_ui_kill/1)
      }
    )
  end

  def handle_server_event(%{event: :kills_updated, payload: kills}, socket) do
    kills =
      kills
      |> Enum.map(&map_ui_kill/1)

    socket
    |> MapEventHandler.push_map_event(
      "kills_updated",
      kills
    )
  end

  def handle_server_event(
        %{event: :detailed_kills_updated, payload: payload},
        %{
          assigns: %{
            map_id: map_id
          }
        } = socket
      ) do
    case WandererApp.Map.is_subscription_active?(map_id) do
      {:ok, true} ->
        socket
        |> MapEventHandler.push_map_event(
          "detailed_kills_updated",
          payload
        )

      _ ->
        socket
    end
  end

  def handle_server_event(
        %{event: :fetch_system_kills_error, payload: {system_id, reason}},
        socket
      ) do
    Logger.warning(
      "[#{__MODULE__}] fetch_kills_for_system failed for sid=#{system_id}: #{inspect(reason)}"
    )

    socket
  end

  def handle_server_event(%{event: :systems_kills_error, payload: {system_ids, reason}}, socket) do
    Logger.warning(
      "[#{__MODULE__}] fetch_kills_for_systems => error=#{inspect(reason)}, systems=#{inspect(system_ids)}"
    )

    socket
  end

  def handle_server_event(%{event: :system_kills_error, payload: {system_id, reason}}, socket) do
    Logger.warning(
      "[#{__MODULE__}] fetch_kills_for_system => error=#{inspect(reason)} for system=#{system_id}"
    )

    socket
  end

  def handle_server_event(event, socket),
    do: MapCoreEventHandler.handle_server_event(event, socket)

  def handle_ui_event(
        "get_system_kills",
        %{"system_id" => sid, "since_hours" => sh} = payload,
        socket
      ) do
    with {:ok, system_id} <- parse_id(sid),
         {:ok, since_hours} <- parse_id(sh) do
      kills_from_cache = KillsCache.fetch_cached_kills(system_id)
      reply_payload = %{"system_id" => system_id, "kills" => kills_from_cache}

      Task.async(fn ->
        case KillsProvider.Fetcher.fetch_kills_for_system(system_id, since_hours, %{
               calls_count: 0
             }) do
          {:ok, fresh_kills, _new_state} ->
            {:detailed_kills_updated, %{system_id => fresh_kills}}

          {:error, reason, _new_state} ->
            Logger.warning("[#{__MODULE__}] fetch_kills_for_system => error=#{inspect(reason)}")
            {:system_kills_error, {system_id, reason}}
        end
      end)

      {:reply, reply_payload, socket}
    else
      :error ->
        Logger.warning("[#{__MODULE__}] Invalid input to get_system_kills: #{inspect(payload)}")
        {:reply, %{"error" => "invalid_input"}, socket}
    end
  end

  def handle_ui_event(
        "get_systems_kills",
        %{"system_ids" => sids, "since_hours" => sh} = payload,
        socket
      ) do
    with {:ok, since_hours} <- parse_id(sh),
         {:ok, parsed_ids} <- parse_system_ids(sids) do
      Logger.debug(fn ->
        "[#{__MODULE__}] get_systems_kills => system_ids=#{inspect(parsed_ids)}, since_hours=#{since_hours}"
      end)

      # Get the cutoff time based on since_hours
      cutoff = DateTime.utc_now() |> DateTime.add(-since_hours * 3600, :second)

      Logger.debug(fn ->
        "[#{__MODULE__}] get_systems_kills => cutoff=#{DateTime.to_iso8601(cutoff)}"
      end)

      # Fetch and filter kills for each system
      cached_map =
        Enum.reduce(parsed_ids, %{}, fn sid, acc ->
          # Get all cached kills for this system
          all_kills = KillsCache.fetch_cached_kills(sid)

          # Filter kills based on the cutoff time
          filtered_kills =
            Enum.filter(all_kills, fn kill ->
              kill_time = kill["kill_time"]

              case kill_time do
                %DateTime{} = dt ->
                  # Keep kills that occurred after the cutoff
                  DateTime.compare(dt, cutoff) != :lt

                time when is_binary(time) ->
                  # Try to parse the string time
                  case DateTime.from_iso8601(time) do
                    {:ok, dt, _} -> DateTime.compare(dt, cutoff) != :lt
                    _ -> false
                  end

                # If it's something else (nil, or a weird format), skip
                _ ->
                  false
              end
            end)

          Logger.debug(fn ->
            "[#{__MODULE__}] get_systems_kills => system_id=#{sid}, all_kills=#{length(all_kills)}, filtered_kills=#{length(filtered_kills)}"
          end)

          Map.put(acc, sid, filtered_kills)
        end)

      reply_payload = %{"systems_kills" => cached_map}

      Task.async(fn ->
        case KillsProvider.Fetcher.fetch_kills_for_systems(parsed_ids, since_hours, %{
               calls_count: 0
             }) do
          {:ok, systems_map} ->
            {:detailed_kills_updated, systems_map}

          {:error, reason} ->
            Logger.warning("[#{__MODULE__}] fetch_kills_for_systems => error=#{inspect(reason)}")
            {:systems_kills_error, {parsed_ids, reason}}
        end
      end)

      {:reply, reply_payload, socket}
    else
      :error ->
        Logger.warning("[#{__MODULE__}] Invalid multiple-systems input: #{inspect(payload)}")
        {:reply, %{"error" => "invalid_input"}, socket}
    end
  end

  def handle_ui_event(event, payload, socket) do
    MapCoreEventHandler.handle_ui_event(event, payload, socket)
  end

  defp parse_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _ -> :error
    end
  end

  defp parse_id(value) when is_integer(value), do: {:ok, value}
  defp parse_id(_), do: :error

  defp parse_system_ids(ids) when is_list(ids) do
    parsed =
      Enum.reduce_while(ids, [], fn sid, acc ->
        case parse_id(sid) do
          {:ok, int_id} -> {:cont, [int_id | acc]}
          :error -> {:halt, :error}
        end
      end)

    case parsed do
      :error -> :error
      list -> {:ok, Enum.reverse(list)}
    end
  end

  defp parse_system_ids(_), do: :error

  defp map_ui_kill({solar_system_id, kills}),
    do: %{solar_system_id: solar_system_id, kills: kills}

  defp map_ui_kill(_kill), do: %{}
end
