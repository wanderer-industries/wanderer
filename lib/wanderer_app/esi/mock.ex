defmodule WandererApp.Esi.Mock do
  @moduledoc """
  Mock implementation of EVE ESI API for testing.

  This module provides fake data for EVE Online entities (characters, corporations, alliances)
  to allow tests to run without making real API calls.
  """

  @behaviour WandererApp.Esi.CharacterBehavior
  @behaviour WandererApp.Esi.CorporationBehavior
  @behaviour WandererApp.Esi.AllianceBehavior

  # Character API implementations

  @impl WandererApp.Esi.CharacterBehavior
  def get_character_info(character_id, _opts \\ []) do
    # Convert to string for pattern matching, handle both integer and string inputs
    character_id_str = to_string(character_id)

    # Return mock character data based on ID patterns
    case character_id_str do
      "95" <> _ ->
        # Special case for common test IDs
        {:ok,
         %{
           "name" => "Test Character #{character_id}",
           "corporation_id" => "98" <> String.slice(character_id_str, 2..10),
           "alliance_id" => "99" <> String.slice(character_id_str, 2..10),
           "birthday" => "2013-01-01T00:00:00Z",
           "bloodline_id" => 1,
           "description" => "Test character for unit tests",
           "gender" => "male",
           "race_id" => 1,
           "security_status" => 5.0
         }}

      _ ->
        # Default mock data
        {:ok,
         %{
           "name" => "Character #{character_id}",
           "corporation_id" => "98000001",
           "alliance_id" => nil,
           "birthday" => "2015-06-15T00:00:00Z",
           "bloodline_id" => 1,
           "description" => "",
           "gender" => "female",
           "race_id" => 1,
           "security_status" => 0.0
         }}
    end
  end

  @impl WandererApp.Esi.CharacterBehavior
  def get_character_location(_character_id, _opts \\ []) do
    {:ok,
     %{
       # Jita
       "solar_system_id" => 30_000_142,
       # Jita 4-4
       "station_id" => 60_003_760,
       "structure_id" => nil
     }}
  end

  @impl WandererApp.Esi.CharacterBehavior
  def get_character_online(_character_id, _opts \\ []) do
    {:ok,
     %{
       "online" => true,
       "last_login" => DateTime.to_iso8601(DateTime.utc_now()),
       "last_logout" => nil,
       "logins" => 42
     }}
  end

  @impl WandererApp.Esi.CharacterBehavior
  def get_character_ship(_character_id, _opts \\ []) do
    {:ok,
     %{
       # Rifter
       "ship_type_id" => 587,
       "ship_name" => "Test Ship",
       "ship_item_id" => 1_000_000_000_000
     }}
  end

  @impl WandererApp.Esi.CharacterBehavior
  def get_character_wallet(_character_id, _opts \\ []) do
    {:ok, 1_234_567.89}
  end

  @impl WandererApp.Esi.CharacterBehavior
  def post_characters_affiliation(character_ids, _opts \\ []) do
    # Return mock affiliation data for each character
    affiliations =
      Enum.map(character_ids, fn char_id ->
        case char_id do
          "95" <> _ ->
            %{
              "character_id" => String.to_integer(char_id),
              "corporation_id" => 98_000_000 + rem(String.to_integer(char_id), 1000),
              "alliance_id" => 99_000_000 + rem(String.to_integer(char_id), 100),
              "faction_id" => nil
            }

          _ ->
            %{
              "character_id" => String.to_integer(char_id),
              "corporation_id" => 98_000_001,
              "alliance_id" => nil,
              "faction_id" => nil
            }
        end
      end)

    {:ok, affiliations}
  end

  # Corporation API implementations

  @impl WandererApp.Esi.CorporationBehavior
  def get_corporation_info(corporation_id, _opts \\ []) do
    # Convert to string for pattern matching, handle both integer and string inputs
    corporation_id_str = to_string(corporation_id)

    case corporation_id_str do
      "98" <> _ ->
        {:ok,
         %{
           "name" => "Test Corporation #{corporation_id}",
           "ticker" => "TST" <> String.slice(corporation_id_str, -3..-1),
           "member_count" => 100,
           "ceo_id" => 95_000_001,
           "alliance_id" => "99" <> String.slice(corporation_id_str, 2..10),
           "description" => "Test corporation for unit tests",
           "tax_rate" => 0.1,
           "date_founded" => "2010-01-01T00:00:00Z",
           "home_station_id" => 60_003_760
         }}

      _ ->
        {:ok,
         %{
           "name" => "Corporation #{corporation_id}",
           "ticker" => "CORP",
           "member_count" => 1,
           "ceo_id" => 1,
           "alliance_id" => nil,
           "description" => "",
           "tax_rate" => 0.0,
           "date_founded" => "2020-01-01T00:00:00Z",
           "home_station_id" => nil
         }}
    end
  end

  @impl WandererApp.Esi.CorporationBehavior
  def get_corporation_wallets(_corporation_id, _opts \\ []) do
    {:ok,
     [
       %{"balance" => 10_000_000_000.0, "division" => 1},
       %{"balance" => 5_000_000_000.0, "division" => 2},
       %{"balance" => 1_000_000_000.0, "division" => 3},
       %{"balance" => 500_000_000.0, "division" => 4},
       %{"balance" => 100_000_000.0, "division" => 5},
       %{"balance" => 50_000_000.0, "division" => 6},
       %{"balance" => 10_000_000.0, "division" => 7}
     ]}
  end

  @impl WandererApp.Esi.CorporationBehavior
  def get_corporation_wallet_journal(_corporation_id, _division, _opts \\ []) do
    {:ok,
     [
       %{
         "id" => 1,
         "date" => DateTime.to_iso8601(DateTime.utc_now()),
         "ref_type" => "player_donation",
         "amount" => 1_000_000.0,
         "balance" => 10_000_000.0,
         "description" => "Test journal entry"
       }
     ]}
  end

  @impl WandererApp.Esi.CorporationBehavior
  def get_corporation_wallet_transactions(_corporation_id, _division, _opts \\ []) do
    {:ok,
     [
       %{
         "transaction_id" => 1,
         "date" => DateTime.to_iso8601(DateTime.utc_now()),
         # Tritanium
         "type_id" => 34,
         "quantity" => 1000,
         "unit_price" => 5.0,
         "is_buy" => false,
         "location_id" => 60_003_760
       }
     ]}
  end

  # Alliance API implementations

  @impl WandererApp.Esi.AllianceBehavior
  def get_alliance_info(alliance_id, _opts \\ []) do
    case alliance_id do
      "99" <> _ ->
        {:ok,
         %{
           "name" => "Test Alliance #{alliance_id}",
           "ticker" => "TEST" <> String.slice(alliance_id, -2..-1),
           "creator_id" => 95_000_001,
           "creator_corporation_id" => 98_000_001,
           "executor_corporation_id" => 98_000_001,
           "date_founded" => "2009-01-01T00:00:00Z",
           "faction_id" => nil
         }}

      _ ->
        {:ok,
         %{
           "name" => "Alliance #{alliance_id}",
           "ticker" => "ALLY",
           "creator_id" => 1,
           "creator_corporation_id" => 1,
           "executor_corporation_id" => 1,
           "date_founded" => "2020-01-01T00:00:00Z",
           "faction_id" => nil
         }}
    end
  end

  # Additional mock methods that might be needed

  def get_server_status(_opts \\ []) do
    {:ok,
     %{
       "players" => 25000,
       "server_version" => "123456",
       "start_time" => "2025-06-14T00:00:00Z"
     }}
  end

  def get_killmail(killmail_id, _killmail_hash, _opts \\ []) do
    {:ok,
     %{
       "killmail_id" => killmail_id,
       "killmail_time" => DateTime.to_iso8601(DateTime.utc_now()),
       "solar_system_id" => 30_000_142,
       "victim" => %{
         "ship_type_id" => 587,
         "character_id" => 95_000_001,
         "corporation_id" => 98_000_001,
         "alliance_id" => 99_000_001
       },
       "attackers" => []
     }}
  end

  def find_routes(_map_id, origin, hubs, _routes_settings, _opts \\ []) do
    # Return a simple mock route
    {:ok,
     [
       %{
         "route" => [origin | hubs],
         "security_status" => "high",
         "jumps" => length(hubs)
       }
     ]}
  end

  def search(_character_eve_id, opts \\ []) do
    _search_string = Keyword.get(opts, :search, "")
    categories = Keyword.get(opts, :categories, ["character"])

    # Return mock search results
    results = %{}

    results =
      if "character" in categories do
        Map.put(results, "character", [95_000_001, 95_000_002])
      else
        results
      end

    results =
      if "corporation" in categories do
        Map.put(results, "corporation", [98_000_001, 98_000_002])
      else
        results
      end

    results =
      if "alliance" in categories do
        Map.put(results, "alliance", [99_000_001, 99_000_002])
      else
        results
      end

    {:ok, results}
  end

  def set_autopilot_waypoint(_add_to_beginning, _clear_other_waypoints, _destination_id, _opts \\ []) do
    :ok
  end
end
