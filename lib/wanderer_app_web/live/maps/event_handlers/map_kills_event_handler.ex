defmodule WandererAppWeb.MapKillsEventHandler do
  @moduledoc """
  Handles kills-related UI/server events.
  """

  use WandererAppWeb, :live_component
  require Logger

  alias WandererAppWeb.MapCoreEventHandler
  alias WandererApp.Zkb.KillsProvider
  alias WandererApp.Zkb.KillsProvider.KillsCache


  def handle_server_event(%{event: :detailed_kills_updated, payload: payload}, socket) do
    Phoenix.LiveView.push_event(socket, "detailed_kills_updated", payload)
  end

  def handle_server_event(%{event: :fetch_system_kills_error, payload: {system_id, reason}}, socket) do
    Logger.warning("[#{__MODULE__}] fetch_kills_for_system failed for sid=#{system_id}: #{inspect(reason)}")
    socket
  end

  def handle_server_event(%{event: :fetch_map_kills_error, payload: {map_id, reason}}, socket) do
    Logger.warning("[#{__MODULE__}] fetch_kills_for_map failed for map=#{map_id}: #{inspect(reason)}")
    socket
  end

  def handle_server_event(%{event: :systems_kills_error, payload: {system_ids, reason}}, socket) do
    Logger.warning("[#{__MODULE__}] fetch_kills_for_systems => error=#{inspect(reason)}, systems=#{inspect(system_ids)}")
    socket
  end

  def handle_server_event(%{event: :system_kills_error, payload: {system_id, reason}}, socket) do
    Logger.warning("[#{__MODULE__}] fetch_kills_for_system => error=#{inspect(reason)} for system=#{system_id}")
    socket
  end

  def handle_server_event(%{event: :fetch_new_system_kills, payload: system}, socket) do
    solar_system_id = system.solar_system_id

    Task.async(fn ->
      case KillsProvider.Fetcher.fetch_kills_for_system(solar_system_id, 24, %{calls_count: 0}) do
        {:ok, kills, _state} ->
          {:detailed_kills_updated, %{solar_system_id => kills}}

        {:error, reason, _state} ->
          Logger.warning("[#{__MODULE__}] Failed to fetch kills for system=#{solar_system_id}: #{inspect(reason)}")
          {:fetch_system_kills_error, {solar_system_id, reason}}
      end
    end)

    socket
  end

  def handle_server_event(%{event: :fetch_new_map_kills, payload: %{map_id: map_id}}, socket) do
    Task.async(fn ->
      with {:ok, map_systems} <- WandererApp.MapSystemRepo.get_visible_by_map(map_id),
           system_ids         <- Enum.map(map_systems, & &1.solar_system_id),
           {:ok, systems_map} <- KillsProvider.Fetcher.fetch_kills_for_systems(system_ids, 24, %{calls_count: 0}) do
        {:detailed_kills_updated, systems_map}
      else
        {:error, reason} ->
          Logger.warning("[#{__MODULE__}] Failed to fetch kills for map=#{map_id}, reason=#{inspect(reason)}")
          {:fetch_map_kills_error, {map_id, reason}}
      end
    end)

    socket
  end

  def handle_server_event(event, socket),
    do: MapCoreEventHandler.handle_server_event(event, socket)


  def handle_ui_event("get_system_kills", %{"system_id" => sid, "since_hours" => sh} = payload, socket) do
    with {:ok, system_id}   <- parse_id(sid),
         {:ok, since_hours} <- parse_id(sh) do
      kills_from_cache = KillsCache.fetch_cached_kills(system_id)
      reply_payload = %{"system_id" => system_id, "kills" => kills_from_cache}

      Task.async(fn ->
        case KillsProvider.Fetcher.fetch_kills_for_system(system_id, since_hours, %{calls_count: 0}) do
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

  def handle_ui_event("get_systems_kills", %{"system_ids" => sids, "since_hours" => sh} = payload, socket) do
    with {:ok, since_hours} <- parse_id(sh),
         {:ok, parsed_ids}  <- parse_system_ids(sids) do
      cached_map =
        Enum.reduce(parsed_ids, %{}, fn sid, acc ->
          kills_list = KillsCache.fetch_cached_kills(sid)
          Map.put(acc, sid, kills_list)
        end)

      reply_payload = %{"systems_kills" => cached_map}

      Task.async(fn ->
        case KillsProvider.Fetcher.fetch_kills_for_systems(parsed_ids, since_hours, %{calls_count: 0}) do
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
      _         -> :error
    end
  end

  defp parse_id(value) when is_integer(value), do: {:ok, value}
  defp parse_id(_), do: :error

  defp parse_system_ids(ids) when is_list(ids) do
    parsed =
      Enum.reduce_while(ids, [], fn sid, acc ->
        case parse_id(sid) do
          {:ok, int_id} -> {:cont, [int_id | acc]}
          :error        -> {:halt, :error}
        end
      end)

    case parsed do
      :error -> :error
      list   -> {:ok, Enum.reverse(list)}
    end
  end

  defp parse_system_ids(_), do: :error
end
