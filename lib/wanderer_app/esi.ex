defmodule WandererApp.Esi do
  @moduledoc group: :esi

  defdelegate get_server_status, to: WandererApp.Esi.ApiClient
  defdelegate get_group_info(group_id, opts \\ []), to: WandererApp.Esi.ApiClient
  defdelegate get_type_info(type_id, opts \\ []), to: WandererApp.Esi.ApiClient
  defdelegate get_alliance_info(eve_id, opts \\ []), to: WandererApp.Esi.ApiClient
  defdelegate get_corporation_info(eve_id, opts \\ []), to: WandererApp.Esi.ApiClient
  defdelegate get_character_info(eve_id, opts \\ []), to: WandererApp.Esi.ApiClient

  defdelegate post_characters_affiliation(character_eve_ids, opts \\ []),
    to: WandererApp.Esi.ApiClient

  defdelegate get_character_wallet(character_eve_id, opts \\ []), to: WandererApp.Esi.ApiClient
  defdelegate get_corporation_wallets(corporation_id, opts \\ []), to: WandererApp.Esi.ApiClient

  defdelegate get_corporation_wallet_journal(corporation_id, division, opts \\ []),
    to: WandererApp.Esi.ApiClient

  defdelegate get_corporation_wallet_transactions(corporation_id, division, opts \\ []),
    to: WandererApp.Esi.ApiClient

  defdelegate get_character_location(character_eve_id, opts \\ []), to: WandererApp.Esi.ApiClient
  defdelegate get_character_online(character_eve_id, opts \\ []), to: WandererApp.Esi.ApiClient
  defdelegate get_character_ship(character_eve_id, opts \\ []), to: WandererApp.Esi.ApiClient
  defdelegate get_routes_custom(hubs, origin, params), to: WandererApp.Esi.ApiClient
  defdelegate get_routes_eve(hubs, origin, params, opts), to: WandererApp.Esi.ApiClient
  defdelegate search(character_eve_id, opts \\ []), to: WandererApp.Esi.ApiClient

  defdelegate get_killmail(killmail_id, killmail_hash, opts \\ []), to: WandererApp.Esi.ApiClient

  defdelegate set_autopilot_waypoint(
                add_to_beginning,
                clear_other_waypoints,
                destination_id,
                opts \\ []
              ),
              to: WandererApp.Esi.ApiClient
end
