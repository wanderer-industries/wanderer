defmodule WandererAppWeb.MapKillsEventHandler do
  @moduledoc """
  Handles kills-related UI and server events.
  """

  use WandererAppWeb, :live_component
  require Logger

  alias WandererAppWeb.{MapEventHandler, MapCoreEventHandler}
  alias WandererApp.Zkb.Provider.{Cache, Fetcher}

  # — Server events —

  def handle_server_event(%{event: :init_kills}, %{assigns: %{map_id: map_id}} = socket) do
    case Cache.get_map_kill_counts(map_id) do
      {:ok, kills_map} ->
        kills_map
        |> filter_positive_kills()
        |> Enum.map(&map_ui_kill/1)
        |> then(fn kills ->
          socket |> MapEventHandler.push_map_event("map_updated", %{kills: kills})
        end)
      {:error, reason} ->
        Logger.error("[MapKillsEventHandler] Failed to get kill counts: #{inspect(reason)}")
        socket
    end
  end

  def handle_server_event(%{event: :update_kills}, %{assigns: %{map_id: map_id}} = socket) do
    case Cache.get_map_kill_counts(map_id) do
      {:ok, kills_map} ->
        socket
        |> assign(kills_map: kills_map)
        |> MapEventHandler.push_map_event("kills_updated", kills_map)
      {:error, reason} ->
        Logger.error("[MapKillsEventHandler] Failed to get kill counts: #{inspect(reason)}")
        socket
    end
  end

  def handle_server_event(%{event: :kills_updated, payload: payload}, socket) do
    MapEventHandler.push_map_event(socket, "kills_updated", payload)
  end

  def handle_server_event(
        %{event: :detailed_kills_updated, payload: payload},
        %{assigns: %{map_id: map_id}} = socket
      ) do
    case WandererApp.Map.is_subscription_active?(map_id) do
      {:ok, true} ->
        socket
        |> MapEventHandler.push_map_event("detailed_kills_updated", payload)

      _ ->
        socket
    end
  end

  def handle_server_event(%{event: event, payload: payload}, socket)
      when event in [
             :fetch_system_kills_error,
             :systems_kills_error,
             :system_kills_error
           ] do
    log_error(event, payload)
    socket
  end

  def handle_server_event(event, socket),
    do: MapCoreEventHandler.handle_server_event(event, socket)

  # — UI events —

  def handle_ui_event("get_system_kills", %{"system_id" => sid, "since_hours" => sh} = payload, socket) do
    with {:ok, system_id}   <- parse_id(sid),
         {:ok, since_hours} <- parse_id(sh) do

      cached_kills = case Cache.get_killmails_for_system(system_id) do
        {:ok, kills} ->
          kills
        {:error, _reason} ->
          []
      end

      reply = %{kills: cached_kills}

      case Task.Supervisor.start_child(WandererApp.TaskSupervisor, fn ->
        case Fetcher.fetch_killmails_for_system(system_id, since_hours: since_hours) do
          {:ok, fresh} ->
            {:detailed_kills_updated, %{system_id => fresh}}

          {:error, reason} ->
            Logger.warning(fn ->
              "[MapKillsEventHandler] fetch_kills_for_system => error=#{inspect(reason)}"
            end)

            {:system_kills_error, {system_id, reason}}
        end
      end) do
        {:ok, _task} ->
          {:reply, reply, socket}
        {:error, reason} ->
          Logger.error("[MapKillsEventHandler] Failed to start task: #{inspect(reason)}")
          {:reply, %{kills: []}, socket}
      end
    else
      _ ->
        Logger.warning(fn ->
          "[MapKillsEventHandler] Invalid get_system_kills payload: #{inspect(payload)}"
        end)

        {:reply, %{kills: []}, socket}
    end
  end

  def handle_ui_event("get_systems_kills", %{"system_ids" => system_ids, "since_hours" => since_hours}, socket) do
    with {:ok, parsed_ids} <- parse_system_ids(system_ids),
         {:ok, hours} <- parse_id(since_hours) do
      systems_kills = parsed_ids
        |> Enum.map(fn id -> {id, Fetcher.fetch_killmails_for_system(id, since_hours: hours)} end)
        |> Enum.map(fn
          {id, {:ok, kills}} when is_list(kills) ->
            # Ensure kills are serializable by converting any structs to maps
            serializable_kills = Enum.map(kills, fn kill ->
              case kill do
                %{ship_type_info: ship_info} = k when is_struct(ship_info) ->
                  # Convert ship_type_info struct to a simple map with only needed fields
                  ship_info_map = %{
                    "type_id" => ship_info.type_id,
                    "name" => ship_info.name,
                    "group_name" => ship_info.group_name
                  }
                  Map.put(k, :ship_type_info, ship_info_map)
                k -> k
              end
            end)
            {id, serializable_kills}
          {id, {:error, reason}} ->
            Logger.error("[MapKillsEventHandler] Failed to fetch kills for system #{id}: #{inspect(reason)}")
            {id, []}
        end)
        |> Map.new()

      {:noreply, push_event(socket, "systems_kills_updated", systems_kills)}
    else
      _ ->
        Logger.error("[MapKillsEventHandler] Invalid get_systems_kills payload: system_ids=#{inspect(system_ids)}, since_hours=#{inspect(since_hours)}")
        {:noreply, push_event(socket, "systems_kills_updated", %{})}
    end
  end

  def handle_ui_event(event, payload, socket),
    do: MapCoreEventHandler.handle_ui_event(event, payload, socket)

  # — Private helpers —

  defp filter_positive_kills(%{} = km),
    do: Enum.filter(km, fn {_id, count} -> count > 0 end)

  defp log_error(:fetch_system_kills_error, {sid, reason}) do
    Logger.warning(
      "[#{__MODULE__}] fetch_kills_for_system failed for sid=#{sid}: #{inspect(reason)}"
    )
  end
  defp log_error(:systems_kills_error, {sids, reason}) do
    Logger.warning(
      "[#{__MODULE__}] fetch_kills_for_systems => error=#{inspect(reason)}, systems=#{inspect(sids)}"
    )
  end
  defp log_error(:system_kills_error, {sid, reason}) do
    Logger.warning(
      "[#{__MODULE__}] fetch_kills_for_system => error=#{inspect(reason)} for system=#{sid}"
    )
  end

  defp parse_id(val) when is_binary(val) do
    case Integer.parse(val) do
      {i, ""} -> {:ok, i}
      _       -> :error
    end
  end
  defp parse_id(val) when is_integer(val), do: {:ok, val}
  defp parse_id(_),                      do: :error

  # Rewritten to avoid a guard with an &-fun
  defp parse_system_ids(ids) when is_list(ids) do
    parsed = Enum.map(ids, &parse_id/1)

    if Enum.all?(parsed, fn
         {:ok, _} -> true
         _        -> false
       end) do
      {:ok, Enum.map(parsed, fn {:ok, i} -> i end)}
    else
      :error
    end
  end
  defp parse_system_ids(_), do: :error

  defp map_ui_kill({sid, kills}) when is_integer(sid) and is_integer(kills) do
    %{solar_system_id: sid, kills: kills}
  end
  defp map_ui_kill(_), do: %{}
end
