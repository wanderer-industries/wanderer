defmodule WandererAppWeb.MapCharacterIntelSanitizerTest do
  use ExUnit.Case, async: true

  alias WandererAppWeb.MapCharacterIntelSanitizer

  @hide_options %{"hide_character_intel" => "true"}
  @show_options %{"hide_character_intel" => "false"}
  @member_permissions %{manage_map: false, admin_map: false}
  @manager_permissions %{manage_map: true, admin_map: false}

  test "sanitizes another character for non-managers when intel hiding is enabled" do
    character = %{
      eve_id: "1001",
      name: "Scout",
      location: %{solar_system_id: 31_000_001},
      ship: %{ship_type_id: 29_984, ship_name: "Probe"},
      solar_system_id: 31_000_001,
      ship_name: "Probe",
      "station_id" => 60_000_001,
      "ship_type_id" => 29_984
    }

    sanitized =
      MapCharacterIntelSanitizer.sanitize_character(
        character,
        @hide_options,
        @member_permissions,
        ["2002"]
      )

    assert %{
             location: nil,
             ship: nil
           } = sanitized

    refute Map.has_key?(sanitized, :solar_system_id)
    refute Map.has_key?(sanitized, :ship_name)
    refute Map.has_key?(sanitized, "station_id")
    refute Map.has_key?(sanitized, "ship_type_id")
  end

  test "keeps own character intel for non-managers" do
    character = %{
      eve_id: "1001",
      name: "Scout",
      location: %{solar_system_id: 31_000_001},
      ship: %{ship_type_id: 29_984, ship_name: "Probe"}
    }

    assert character ==
             MapCharacterIntelSanitizer.sanitize_character(
               character,
               @hide_options,
               @member_permissions,
               ["1001"]
             )
  end

  test "keeps character intel for managers and when the option is disabled" do
    character = %{
      eve_id: "1001",
      location: %{solar_system_id: 31_000_001},
      ship: %{ship_type_id: 29_984}
    }

    assert character ==
             MapCharacterIntelSanitizer.sanitize_character(
               character,
               @hide_options,
               @manager_permissions,
               []
             )

    assert character ==
             MapCharacterIntelSanitizer.sanitize_character(
               character,
               @show_options,
               @member_permissions,
               []
             )
  end

  test "filters present characters, passages, and activity to own characters for non-managers" do
    own_character = %{eve_id: "1001", name: "Own"}
    other_character = %{eve_id: "2002", name: "Other"}

    assert ["1001"] ==
             MapCharacterIntelSanitizer.sanitize_present_character_eve_ids(
               ["1001", "2002"],
               @hide_options,
               @member_permissions,
               ["1001"]
             )

    assert [%{character: ^own_character}] =
             MapCharacterIntelSanitizer.filter_passages(
               [%{character: own_character}, %{character: other_character}],
               @hide_options,
               @member_permissions,
               ["1001"]
             )

    assert [%{character: ^own_character}] =
             MapCharacterIntelSanitizer.filter_activity(
               [%{character: own_character}, %{character: other_character}],
               @hide_options,
               @member_permissions,
               ["1001"]
             )
  end
end
