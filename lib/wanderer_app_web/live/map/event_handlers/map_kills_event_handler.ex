defmodule WandererAppWeb.MapKillsEventHandler do
  @moduledoc """
  Handles kills-related UI/server events.
  Uses cache data populated by the WandererKills WebSocket service.
  """

  use WandererAppWeb, :live_component
  require Logger

  alias WandererAppWeb.{MapCoreEventHandler, MapEventHandler}

  def handle_server_event(
        %{event: :init_kills},
        %{assigns: %{map_id: map_id} = assigns} = socket
      ) do
    # Get kill counts from cache
    case WandererApp.Map.get_map(map_id) do
      {:ok, %{systems: systems}} ->
        kill_counts = build_kill_counts(systems)

        kills_payload =
          kill_counts
          |> Enum.map(fn {system_id, kills} ->
            %{solar_system_id: system_id, kills: kills}
          end)

        MapEventHandler.push_map_event(
          socket,
          "kills_updated",
          kills_payload
        )

      error ->
        Logger.warning("[#{__MODULE__}] Failed to get map #{map_id}: #{inspect(error)}")
        socket
    end
  end

  def handle_server_event(%{event: :update_system_kills, payload: solar_system_id}, socket) do
    # Get kill count for the specific system
    kills_count =
      case WandererApp.Cache.get("zkb:kills:#{solar_system_id}") do
        count when is_integer(count) and count >= 0 ->
          count

        nil ->
          0

        invalid_data ->
          Logger.warning(
            "[#{__MODULE__}] Invalid kill count data for new system #{solar_system_id}: #{inspect(invalid_data)}"
          )

          0
      end

    # Only send update if there are kills
    if kills_count > 0 do
      MapEventHandler.push_map_event(socket, "kills_updated", [
        %{solar_system_id: solar_system_id, kills: kills_count}
      ])
    else
      socket
    end
  end

  def handle_server_event(%{event: :kills_updated, payload: kills}, socket) do
    kills =
      kills
      |> Enum.map(fn {system_id, count} ->
        %{solar_system_id: system_id, kills: count}
      end)

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
    handle_get_system_kills(sid, sh, payload, socket)
  end

  def handle_ui_event(
        "get_systems_kills",
        %{"system_ids" => sids, "since_hours" => sh} = payload,
        socket
      ) do
    handle_get_systems_kills(sids, sh, payload, socket)
  end

  def handle_ui_event(event, payload, socket) do
    MapCoreEventHandler.handle_ui_event(event, payload, socket)
  end

  defp handle_get_system_kills(sid, sh, payload, socket) do
    with {:ok, system_id} <- parse_id(sid),
         # Parse since_hours for validation, but filtering is done on frontend
         {:ok, _since_hours} <- parse_id(sh) do
      cache_key = "map:#{socket.assigns.map_id}:zkb:detailed_kills"

      # Get from WandererApp.Cache (not Cachex)
      kills_data =
        case WandererApp.Cache.get(cache_key) do
          cached_map when is_map(cached_map) ->
            # Validate cache structure and extract system kills
            case Map.get(cached_map, system_id) do
              kills when is_list(kills) -> kills
              _ -> []
            end

          nil ->
            []

          invalid_data ->
            Logger.warning(
              "[#{__MODULE__}] Invalid cache data structure for key: #{cache_key}, got: #{inspect(invalid_data)}"
            )

            # Clear invalid cache entry
            WandererApp.Cache.delete(cache_key)
            []
        end

      reply_payload = %{"system_id" => system_id, "kills" => kills_data}

      Logger.debug(fn ->
        "[#{__MODULE__}] get_system_kills => system_id=#{system_id}, cached_kills=#{length(kills_data)}"
      end)

      {:reply, reply_payload, socket}
    else
      :error ->
        Logger.warning("[#{__MODULE__}] Invalid input to get_system_kills: #{inspect(payload)}")
        {:reply, %{"error" => "invalid_input"}, socket}
    end
  end

  defp handle_get_systems_kills(sids, sh, payload, socket) do
    # Parse since_hours for validation, but filtering is done on frontend
    with {:ok, _since_hours} <- parse_id(sh),
         {:ok, parsed_ids} <- parse_system_ids(sids) do
      cache_key = "map:#{socket.assigns.map_id}:zkb:detailed_kills"

      # Get from WandererApp.Cache (not Cachex)
      filtered_data = get_kills_for_systems(cache_key, parsed_ids)

      # filtered_data is already the final result, not wrapped in a tuple
      systems_data = filtered_data

      reply_payload = %{"systems_kills" => systems_data}

      {:reply, reply_payload, socket}
    else
      :error ->
        Logger.warning("[#{__MODULE__}] Invalid multiple-systems input: #{inspect(payload)}")
        {:reply, %{"error" => "invalid_input"}, socket}
    end
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

  defp build_kill_counts(systems) do
    systems
    |> Enum.map(&extract_system_kill_count/1)
    |> Enum.filter(fn {_system_id, count} -> count > 0 end)
    |> Enum.into(%{})
  end

  defp extract_system_kill_count({solar_system_id, _system}) do
    kills_count = get_validated_kill_count(solar_system_id)
    {solar_system_id, kills_count}
  end

  defp get_validated_kill_count(solar_system_id) do
    case WandererApp.Cache.get("zkb:kills:#{solar_system_id}") do
      count when is_integer(count) and count >= 0 ->
        count

      nil ->
        0

      invalid_data ->
        Logger.warning(
          "[#{__MODULE__}] Invalid kill count data for system #{solar_system_id}: #{inspect(invalid_data)}"
        )

        0
    end
  end

  defp get_kills_for_systems(cache_key, system_ids) do
    case WandererApp.Cache.get(cache_key) do
      cached_map when is_map(cached_map) ->
        extract_cached_kills(cached_map, system_ids)

      nil ->
        %{}

      invalid_data ->
        Logger.warning(
          "[#{__MODULE__}] Invalid cache data structure for key: #{cache_key}, got: #{inspect(invalid_data)}"
        )

        # Clear invalid cache entry
        WandererApp.Cache.delete(cache_key)
        %{}
    end
  end

  defp extract_cached_kills(cached_map, system_ids) do
    Enum.reduce(system_ids, %{}, fn system_id, acc ->
      case Map.get(cached_map, system_id) do
        kills when is_list(kills) ->
          Map.put(acc, system_id, kills)

        _ ->
          acc
      end
    end)
  end
end
