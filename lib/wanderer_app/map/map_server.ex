defmodule WandererApp.Map.Server do
  @moduledoc """
  Holds state for a map and exposes an interface to managing the map instance
  """
  require Logger

  alias WandererApp.Map.Server.Impl

  @logger Application.compile_env(:wanderer_app, :logger)

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

  defdelegate untrack_characters(map_id, character_ids), to: Impl

  defdelegate add_system(map_id, system_info, user_id, character_id, opts \\ []), to: Impl

  defdelegate paste_connections(map_id, connections, user_id, character_id), to: Impl

  defdelegate paste_systems(map_id, systems, user_id, character_id, opts \\ []), to: Impl

  defdelegate add_system_comment(map_id, comment_info, user_id, character_id), to: Impl

  defdelegate remove_system_comment(map_id, comment_id, user_id, character_id), to: Impl

  defdelegate update_system_position(map_id, update), to: Impl

  defdelegate update_system_linked_sig_eve_id(map_id, update), to: Impl

  defdelegate update_system_name(map_id, update), to: Impl

  defdelegate update_system_description(map_id, update), to: Impl

  defdelegate update_system_status(map_id, update), to: Impl

  defdelegate update_system_tag(map_id, update), to: Impl

  defdelegate update_system_temporary_name(map_id, update), to: Impl

  defdelegate update_system_custom_name(map_id, update), to: Impl

  defdelegate update_system_locked(map_id, update), to: Impl

  defdelegate update_system_labels(map_id, update), to: Impl

  defdelegate add_hub(map_id, hub_info), to: Impl

  defdelegate remove_hub(map_id, hub_info), to: Impl

  defdelegate add_ping(map_id, ping_info), to: Impl

  defdelegate cancel_ping(map_id, ping_info), to: Impl

  defdelegate delete_systems(map_id, solar_system_ids, user_id, character_id), to: Impl

  defdelegate add_connection(map_id, connection_info), to: Impl

  defdelegate delete_connection(map_id, connection_info), to: Impl

  defdelegate import_settings(map_id, settings, user_id), to: Impl

  defdelegate update_subscription_settings(map_id, settings), to: Impl

  defdelegate get_connection_info(map_id, connection_info), to: Impl

  defdelegate update_connection_time_status(map_id, connection_info), to: Impl

  defdelegate update_connection_type(map_id, connection_info), to: Impl

  defdelegate update_connection_mass_status(map_id, connection_info), to: Impl

  defdelegate update_connection_ship_size_type(map_id, connection_info), to: Impl

  defdelegate update_connection_locked(map_id, connection_info), to: Impl

  defdelegate update_connection_custom_info(map_id, connection_info), to: Impl

  defdelegate update_signatures(map_id, signatures_update), to: Impl
end
