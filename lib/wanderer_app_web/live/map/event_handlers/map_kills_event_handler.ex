defmodule WandererAppWeb.MapKillsEventHandler do
  @moduledoc """
  Handles kills-related UI/server events.
  Uses cache data populated by the WandererKills WebSocket service.
  """

  use WandererAppWeb, :live_component
  require Logger

  alias WandererAppWeb.{MapEventHandler, MapCoreEventHandler}
  alias WandererApp.Kills.CacheKeys

  def handle_server_event(
        %{event: :init_kills},
        %{assigns: %{map_id: map_id}} = socket
      ) do
    # Get kill counts from cache
    case WandererApp.Map.get_map(map_id) do
      {:ok, %{systems: systems}} ->
        kill_counts =
          systems
          |> Enum.into(%{}, fn {solar_system_id, _system} ->
            # Use explicit cache lookup with validation
            kills_count = case Cachex.get(:api_cache, CacheKeys.system_kill_count(solar_system_id)) do
              {:ok, count} when is_integer(count) and count >= 0 -> count
              {:ok, _invalid_data} ->
                Logger.warning("[#{__MODULE__}] Invalid kill count data for system #{solar_system_id}")
                0
              {:error, :not_found} -> 0
              {:error, reason} ->
                Logger.warning("[#{__MODULE__}] Cache lookup failed for system #{solar_system_id}: #{inspect(reason)}")
                0
            end
            {solar_system_id, kills_count}
          end)
          |> Enum.filter(fn {_system_id, count} -> count > 0 end)
          |> Enum.into(%{})

        socket
        |> MapEventHandler.push_map_event(
          "map_updated",
          %{
            kills:
              kill_counts
              |> Enum.map(fn {system_id, kills} ->
                %{solar_system_id: system_id, kills: kills}
              end)
          }
        )

      _ ->
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
         {:ok, _since_hours} <- parse_id(sh) do

      cache_key = CacheKeys.map_detailed_kills(socket.assigns.map_id)

      # Get from WandererApp.Cache (not Cachex)
      kills_data = case WandererApp.Cache.get(cache_key) do
        cached_map when is_map(cached_map) ->
          # Validate cache structure and extract system kills
          case Map.get(cached_map, system_id) do
            kills when is_list(kills) -> kills
            _ -> []
          end

        nil ->
          []

        invalid_data ->
          Logger.warning("[#{__MODULE__}] Invalid cache data structure for key: #{cache_key}, got: #{inspect(invalid_data)}")
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
    with {:ok, _since_hours} <- parse_id(sh),
         {:ok, parsed_ids} <- parse_system_ids(sids) do
      Logger.debug(fn ->
        "[#{__MODULE__}] get_systems_kills => system_ids=#{inspect(parsed_ids)}"
      end)

      cache_key = CacheKeys.map_detailed_kills(socket.assigns.map_id)

      # Get from WandererApp.Cache (not Cachex)
      filtered_data = case WandererApp.Cache.get(cache_key) do
        cached_map when is_map(cached_map) ->
          # Validate and filter cached data
          parsed_ids
          |> Enum.reduce(%{}, fn system_id, acc ->
            case Map.get(cached_map, system_id) do
              kills when is_list(kills) -> Map.put(acc, system_id, kills)
              _ -> acc
            end
          end)

        nil ->
          %{}

        invalid_data ->
          Logger.warning("[#{__MODULE__}] Invalid cache data structure for key: #{cache_key}, got: #{inspect(invalid_data)}")
          # Clear invalid cache entry
          WandererApp.Cache.delete(cache_key)
          %{}
      end

      # filtered_data is already the final result, not wrapped in a tuple
      systems_data = filtered_data

      reply_payload = %{"systems_kills" => systems_data}

      Logger.debug(fn ->
        "[#{__MODULE__}] get_systems_kills => returning #{map_size(systems_data)} systems from cache"
      end)

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
end
