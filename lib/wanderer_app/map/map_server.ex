defmodule WandererApp.Map.Server do
  @moduledoc """
  Holds state for a map and exposes an interface to managing the map instance
  """
  use GenServer, restart: :transient, significant: true

  require Logger

  alias WandererApp.Map.Server.Impl

  @logger Application.compile_env(:wanderer_app, :logger)

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(args) when is_list(args) do
    GenServer.start_link(__MODULE__, args, name: _via(args[:map_id]))
  end

  @impl true
  def init(args), do: {:ok, Impl.init(args), {:continue, :load_state}}

  def map_pid(map_id),
    do:
      map_id
      |> _via()
      |> GenServer.whereis()

  def map_pid!(map_id) do
    map_id
    |> map_pid()
    |> case do
      map_id when is_pid(map_id) ->
        map_id

      nil ->
        WandererApp.Cache.insert("map_#{map_id}:started", false)
        throw("Map server not started")
    end
  end

  def get_map(pid) when is_pid(pid),
    do:
      pid
      |> GenServer.call({&Impl.get_map/1, []}, :timer.minutes(5))

  def get_map(map_id) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> get_map()

  def get_export_settings(%{id: map_id, hubs: hubs} = _map) do
    with {:ok, all_systems} <- WandererApp.MapSystemRepo.get_all_by_map(map_id),
         {:ok, connections} <- WandererApp.MapConnectionRepo.get_by_map(map_id) do
      {:ok,
       %{
         systems: all_systems,
         hubs: hubs,
         connections: connections
       }}
    else
      error ->
        @logger.error("Failed to get export settings: #{inspect(error, pretty: true)}")

        {:ok,
         %{
           systems: [],
           hubs: [],
           connections: []
         }}
    end
  end

  def get_characters(map_id) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.call({&Impl.get_characters/1, []}, :timer.minutes(1))

  def add_character(map_id, character, track_character \\ false) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.add_character/3, [character, track_character]})

  def remove_character(map_id, character_id) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.remove_character/2, [character_id]})

  def untrack_characters(map_id, character_ids) when is_binary(map_id) do
    map_id
    |> map_pid()
    |> case do
      pid when is_pid(pid) ->
        GenServer.cast(pid, {&Impl.untrack_characters/2, [character_ids]})

      _ ->
        WandererApp.Cache.insert("map_#{map_id}:started", false)
        :ok
    end
  end

  def add_system(map_id, system_info, user_id, character_id, opts \\ []) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.add_system/5, [system_info, user_id, character_id, opts]})

  def paste_connections(map_id, connections, user_id, character_id) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.paste_connections/4, [connections, user_id, character_id]})

  def paste_systems(map_id, systems, user_id, character_id, opts \\ []) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.paste_systems/5, [systems, user_id, character_id, opts]})

  def add_system_comment(map_id, comment_info, user_id, character_id) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.add_system_comment/4, [comment_info, user_id, character_id]})

  def remove_system_comment(map_id, comment_id, user_id, character_id) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.remove_system_comment/4, [comment_id, user_id, character_id]})

  def update_system_position(map_id, update) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.update_system_position/2, [update]})

  def update_system_linked_sig_eve_id(map_id, update) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.update_system_linked_sig_eve_id/2, [update]})

  def update_system_name(map_id, update) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.update_system_name/2, [update]})

  def update_system_description(map_id, update) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.update_system_description/2, [update]})

  def update_system_status(map_id, update) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.update_system_status/2, [update]})

  def update_system_tag(map_id, update) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.update_system_tag/2, [update]})

  def update_system_temporary_name(map_id, update) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.update_system_temporary_name/2, [update]})

  def update_system_locked(map_id, update) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.update_system_locked/2, [update]})

  def update_system_labels(map_id, update) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.update_system_labels/2, [update]})

  def add_hub(map_id, hub_info) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.add_hub/2, [hub_info]})

  def remove_hub(map_id, hub_info) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.remove_hub/2, [hub_info]})

  def add_ping(map_id, ping_info) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.add_ping/2, [ping_info]})

  def cancel_ping(map_id, ping_info) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.cancel_ping/2, [ping_info]})

  def delete_systems(map_id, solar_system_ids, user_id, character_id) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.delete_systems/4, [solar_system_ids, user_id, character_id]})

  def add_connection(map_id, connection_info) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.add_connection/2, [connection_info]})

  def import_settings(map_id, settings, user_id) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.call({&Impl.import_settings/3, [settings, user_id]}, :timer.minutes(30))

  def update_subscription_settings(map_id, settings) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.update_subscription_settings/2, [settings]})

  def delete_connection(map_id, connection_info) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.delete_connection/2, [connection_info]})

  def get_connection_info(map_id, connection_info) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.call({&Impl.get_connection_info/2, [connection_info]}, :timer.minutes(1))

  def update_connection_time_status(map_id, connection_info) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.update_connection_time_status/2, [connection_info]})

  def update_connection_type(map_id, connection_info) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.update_connection_type/2, [connection_info]})

  def update_connection_mass_status(map_id, connection_info) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.update_connection_mass_status/2, [connection_info]})

  def update_connection_ship_size_type(map_id, connection_info) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.update_connection_ship_size_type/2, [connection_info]})

  def update_connection_locked(map_id, connection_info) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.update_connection_locked/2, [connection_info]})

  def update_connection_custom_info(map_id, connection_info) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.update_connection_custom_info/2, [connection_info]})

  def update_signatures(map_id, signatures_update) when is_binary(map_id),
    do:
      map_id
      |> map_pid!
      |> GenServer.cast({&Impl.update_signatures/2, [signatures_update]})

  @impl true
  def handle_continue(:load_state, state),
    do: {:noreply, state |> Impl.load_state(), {:continue, :start_map}}

  @impl true
  def handle_continue(:start_map, state), do: {:noreply, state |> Impl.start_map()}

  @impl true
  def handle_call(
        {impl_function, args},
        _from,
        state
      )
      when is_function(impl_function),
      do: WandererApp.GenImpl.apply_call(impl_function, state, args)

  @impl true
  def handle_cast(:stop, state), do: {:stop, :normal, state |> Impl.stop_map()}

  @impl true
  def handle_cast({impl_function, args}, state)
      when is_function(impl_function) do
    case WandererApp.GenImpl.apply_call(impl_function, state, args) do
      {:reply, _return, updated_state} ->
        {:noreply, updated_state}

      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(event, state), do: {:noreply, Impl.handle_event(event, state)}

  defp _via(map_id), do: {:via, Registry, {WandererApp.MapRegistry, map_id}}
end
