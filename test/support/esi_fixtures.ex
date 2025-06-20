defmodule WandererApp.Test.EsiFixtures do
  @moduledoc """
  Test fixtures for EVE ESI API responses.

  Provides realistic test data for characters, corporations, and alliances
  that can be used in tests to simulate EVE Online entities.
  """

  def character_fixture(attrs \\ %{}) do
    base = %{
      "name" => "Test Pilot",
      "corporation_id" => 98_000_125,
      "alliance_id" => 99_000_050,
      "birthday" => "2013-01-01T00:00:00Z",
      "bloodline_id" => 5,
      "description" => "Test character for Wanderer",
      "gender" => "male",
      "race_id" => 1,
      "security_status" => 5.0,
      "title" => nil,
      "faction_id" => nil
    }

    Map.merge(base, attrs)
  end

  def corporation_fixture(attrs \\ %{}) do
    base = %{
      "name" => "Test Corporation",
      "ticker" => "TEST",
      "member_count" => 150,
      "ceo_id" => 95_000_001,
      "alliance_id" => 99_000_050,
      "description" => "A test corporation",
      "tax_rate" => 0.1,
      "date_founded" => "2010-01-01T00:00:00Z",
      "creator_id" => 90_000_001,
      "url" => "http://test.example.com",
      "faction_id" => nil,
      "home_station_id" => 60_003_760,
      "shares" => 1000,
      "war_eligible" => true
    }

    Map.merge(base, attrs)
  end

  def alliance_fixture(attrs \\ %{}) do
    base = %{
      "name" => "Test Alliance",
      "ticker" => "TEST",
      "creator_id" => 95_000_001,
      "creator_corporation_id" => 98_000_001,
      "executor_corporation_id" => 98_000_001,
      "date_founded" => "2009-01-01T00:00:00Z",
      "faction_id" => nil
    }

    Map.merge(base, attrs)
  end

  def character_location_fixture(attrs \\ %{}) do
    base = %{
      # Jita
      "solar_system_id" => 30_000_142,
      # Jita 4-4
      "station_id" => 60_003_760,
      "structure_id" => nil
    }

    Map.merge(base, attrs)
  end

  def character_online_fixture(attrs \\ %{}) do
    base = %{
      "online" => true,
      "last_login" => DateTime.to_iso8601(DateTime.utc_now()),
      "last_logout" => DateTime.to_iso8601(DateTime.add(DateTime.utc_now(), -3600)),
      "logins" => 42
    }

    Map.merge(base, attrs)
  end

  def character_ship_fixture(attrs \\ %{}) do
    base = %{
      # Rifter
      "ship_type_id" => 587,
      "ship_name" => "Test Ship",
      "ship_item_id" => 1_000_000_000_000
    }

    Map.merge(base, attrs)
  end

  def character_affiliation_fixture(character_id, attrs \\ %{}) do
    base = %{
      "character_id" => String.to_integer(character_id),
      "corporation_id" => 98_000_125,
      "alliance_id" => 99_000_050,
      "faction_id" => nil
    }

    Map.merge(base, attrs)
  end

  # Common EVE Online test entities

  def test_entities do
    %{
      characters: %{
        "95465499" =>
          character_fixture(%{
            "name" => "CCP Bartender",
            "corporation_id" => "109299958",
            "alliance_id" => nil
          }),
        "95000001" =>
          character_fixture(%{
            "name" => "Test FC",
            "corporation_id" => "98000001",
            "alliance_id" => "99000001"
          }),
        "95000002" =>
          character_fixture(%{
            "name" => "Test Member",
            "corporation_id" => "98000001",
            "alliance_id" => "99000001"
          })
      },
      corporations: %{
        "109299958" =>
          corporation_fixture(%{
            "name" => "C C P",
            "ticker" => "CCP",
            "alliance_id" => nil,
            "member_count" => 500
          }),
        "98000001" =>
          corporation_fixture(%{
            "name" => "Test Corp Alpha",
            "ticker" => "TCA",
            "alliance_id" => "99000001",
            "member_count" => 250
          }),
        "98000002" =>
          corporation_fixture(%{
            "name" => "Test Corp Bravo",
            "ticker" => "TCB",
            "alliance_id" => "99000001",
            "member_count" => 100
          })
      },
      alliances: %{
        "99000001" =>
          alliance_fixture(%{
            "name" => "Test Alliance Please Ignore",
            "ticker" => "TEST",
            "executor_corporation_id" => "98000001"
          }),
        "99000050" =>
          alliance_fixture(%{
            "name" => "Goonswarm Federation",
            "ticker" => "CONDI",
            "executor_corporation_id" => "98000125"
          })
      }
    }
  end

  def error_response(status \\ 404, message \\ "Not found") do
    {:error,
     %{
       "error" => message,
       "status" => status
     }}
  end

  def timeout_error do
    {:error, :timeout}
  end

  def rate_limited_error do
    {:error,
     %{
       "error" => "Rate limited",
       "status" => 420,
       "timeout" => 60
     }}
  end
end
