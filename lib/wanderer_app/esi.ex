defmodule WandererApp.Esi do
  @moduledoc group: :esi

  @esi_client Application.compile_env(:wanderer_app, :esi_client, WandererApp.Esi.ApiClient)

  defdelegate get_server_status, to: @esi_client
  defdelegate get_alliance_info(eve_id, opts \\ []), to: @esi_client
  defdelegate get_corporation_info(eve_id, opts \\ []), to: @esi_client
  defdelegate get_character_info(eve_id, opts \\ []), to: @esi_client

  defdelegate post_characters_affiliation(character_eve_ids, opts \\ []),
    to: @esi_client

  defdelegate get_character_wallet(character_eve_id, opts \\ []), to: @esi_client
  defdelegate get_corporation_wallets(corporation_id, opts \\ []), to: @esi_client

  defdelegate get_corporation_wallet_journal(corporation_id, division, opts \\ []),
    to: @esi_client

  defdelegate get_corporation_wallet_transactions(corporation_id, division, opts \\ []),
    to: @esi_client

  defdelegate get_character_location(character_eve_id, opts \\ []), to: @esi_client
  defdelegate get_character_online(character_eve_id, opts \\ []), to: @esi_client
  defdelegate get_character_ship(character_eve_id, opts \\ []), to: @esi_client
  defdelegate find_routes(map_id, origin, hubs, routes_settings), to: @esi_client
  defdelegate search(character_eve_id, opts \\ []), to: @esi_client

  defdelegate get_killmail(killmail_id, killmail_hash, opts \\ []), to: @esi_client

  defdelegate set_autopilot_waypoint(
                add_to_beginning,
                clear_other_waypoints,
                destination_id,
                opts \\ []
              ),
              to: @esi_client
end
