defmodule WandererAppWeb.MapKillsEventHandler do
  @moduledoc """
  Handles UI/Server events related to retrieving kills data from the cache.

  Server events:
  - Return a raw `socket` so the caller can do `{:noreply, socket}`.

  UI events:
  - Can return `{:reply, payload, socket}` or a raw `socket`.
  """

  use WandererAppWeb, :live_component
  use Phoenix.Component
  require Logger

  alias WandererAppWeb.MapCoreEventHandler
  alias WandererAppWeb.MapEventHandler
  alias WandererApp.Zkb.KillsProvider

  # ---------------------------------------------------------
  # Handle server event :detailed_kills_updated
  # ---------------------------------------------------------
  def handle_server_event(%{event: :detailed_kills_updated, payload: payload}, socket) do
    socket = MapEventHandler.push_map_event(socket, "detailed_kills_updated", payload)
    socket
  end

  # ---------------------------------------------------------
  # Handle server event :fetch_new_system_kills (single system)
  # ---------------------------------------------------------
  def handle_server_event(%{event: :fetch_new_system_kills, payload: system}, socket) do
    Logger.info("""
    [MapKillsEventHandler] Handling :fetch_system_kills event
      system=#{inspect(system)}
      map_id=#{socket.assigns.map_id}
    """)

    Task.start(fn ->
      sid = system.solar_system_id
      map_id = socket.assigns.map_id

      case KillsProvider.fetch_kills_for_system(sid, 24, %{calls_count: 0}) do
        {:ok, kills, _state} ->
          kills_map = %{sid => kills}
          Phoenix.PubSub.broadcast!(
            WandererApp.PubSub,
            map_id,
            %{event: :detailed_kills_updated, payload: kills_map}
          )

        {:error, reason, _state} ->
          Logger.warning("[MapKillsEventHandler] Failed to fetch kills for system=#{sid}: #{inspect(reason)}")
      end
    end)

    socket
  end

  # ---------------------------------------------------------
  # Handle server event :fetch_new_map_kills (multi-system)
  # ---------------------------------------------------------
  def handle_server_event(%{event: :fetch_new_map_kills, payload: %{map_id: map_id}}, socket) do
    Logger.info("""
    [MapKillsEventHandler] Handling :fetch_new_map_kills event => map_id=#{map_id}
    """)

    Task.start(fn ->
      case WandererApp.MapSystemRepo.get_visible_by_map(map_id) do
        {:ok, map_systems} ->
          # Extract just the integer solar_system_ids
          system_ids = Enum.map(map_systems, & &1.solar_system_id)

          case KillsProvider.fetch_kills_for_systems(system_ids, 24, %{calls_count: 0}) do
            {:ok, systems_map} ->
              Phoenix.PubSub.broadcast!(
                WandererApp.PubSub,
                map_id,
                %{event: :detailed_kills_updated, payload: systems_map}
              )

            {:error, reason} ->
              Logger.warning("[MapKillsEventHandler] Failed to fetch kills for map=#{map_id}, reason=#{inspect(reason)}")
          end

        {:error, reason} ->
          Logger.warning("[MapKillsEventHandler] get_visible_by_map failed => #{inspect(reason)}")
      end
    end)

    socket
  end

  # ---------------------------------------------------------
  # Fallback to MapCoreEventHandler
  # ---------------------------------------------------------
  def handle_server_event(event, socket) do
    updated_socket =
      case MapCoreEventHandler.handle_server_event(event, socket) do
        {:noreply, new_socket} ->
          new_socket

        {:reply, _payload, new_socket} ->
          new_socket

        new_socket when is_map(new_socket) ->
          new_socket
      end

    updated_socket
  end

  # ---------------------------------------------------------
  # UI events: "get_system_kills", "get_systems_kills", etc.
  # ---------------------------------------------------------
  def handle_ui_event("get_system_kills", %{"system_id" => sid, "since_hours" => sh} = payload, socket) do
    with {:ok, system_id}   <- parse_id(sid),
         {:ok, since_hours} <- parse_id(sh) do
      fetch_and_respond(system_id, since_hours, socket)
    else
      :error ->
        Logger.warning("[MapKillsEventHandler] Invalid input: #{inspect(payload)}")
        {:reply, %{"error" => "invalid_input"}, socket}
    end
  end

  def handle_ui_event("get_systems_kills", %{"system_ids" => sids, "since_hours" => sh} = payload, socket) do
    with {:ok, since_hours} <- parse_id(sh),
         {:ok, parsed_ids}  <- parse_system_ids(sids) do
      case KillsProvider.fetch_kills_for_systems(parsed_ids, since_hours, %{calls_count: 0}) do
        {:ok, systems_map} ->
          {:reply, %{"systems_kills" => systems_map}, socket}

        {:error, reason} ->
          Logger.warning("[MapKillsEventHandler] fetch_kills_for_systems => error=#{inspect(reason)}")
          {:reply, %{"error" => inspect(reason)}, socket}
      end
    else
      :error ->
        Logger.warning("[MapKillsEventHandler] Invalid multiple-systems input: #{inspect(payload)}")
        {:reply, %{"error" => "invalid_input"}, socket}
    end
  end

  def handle_ui_event(event, payload, socket) do
    MapCoreEventHandler.handle_ui_event(event, payload, socket)
  end

  # ---------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------
  defp fetch_and_respond(system_id, since_hours, socket) do
    case KillsProvider.fetch_kills_for_system(system_id, since_hours, %{calls_count: 0}) do
      {:ok, kills, _new_state} ->
        {:reply, %{"system_id" => system_id, "kills" => kills}, socket}

      {:error, reason, _new_state} ->
        Logger.warning("[MapKillsEventHandler] fetch_kills_for_system => error=#{inspect(reason)}")
        {:reply, %{"error" => inspect(reason)}, socket}
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
      _ -> {:ok, Enum.reverse(parsed)}
    end
  end

  defp parse_system_ids(_), do: :error
end
