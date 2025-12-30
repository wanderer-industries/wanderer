defmodule WandererApp.Map.MapScopeFilteringTest do
  @moduledoc """
  Integration tests for map scope filtering during character location tracking.

  These tests verify that systems are correctly filtered based on map scope settings
  when characters move between systems. The key scenarios tested:

  1. Characters moving between systems with [:wormholes, :null] scopes:
     - Wormhole systems should be added
     - Null-sec systems should be added
     - High-sec systems should NOT be added (filtered out)
     - Low-sec systems should NOT be added (filtered out)

  2. Wormhole border behavior:
     - When a character jumps from wormhole to k-space, the wormhole should be added
     - K-space border systems should only be added if they match the scopes

  3. K-space only movement:
     - Characters moving within k-space should only track systems matching scopes
     - No "border system" behavior for k-space to k-space movement

  Reference bug: Characters with [:wormholes, :null] scopes were getting
  high-sec (0.6) and low-sec (0.4) systems added to the map when traveling.
  """

  use WandererApp.DataCase

  # System class constants (matching ConnectionsImpl)
  @c1 1
  @c2 2
  @hs 7
  @ls 8
  @ns 9

  # Test solar system IDs
  # C1 wormhole
  @wh_system_j100001 31_000_001
  # C2 wormhole
  @wh_system_j100002 31_000_002
  # High-sec system (0.6)
  @hs_system_halenan 30_000_001
  # High-sec system (0.6)
  @hs_system_mili 30_000_002
  # Low-sec system (0.4)
  @ls_system_halmah 30_000_100
  # Null-sec system
  @ns_system_geminate 30_000_200

  setup do
    # Setup system static info cache with both wormhole and k-space systems
    setup_scope_test_systems()
    # Setup known stargates between adjacent k-space systems
    setup_kspace_stargates()
    :ok
  end

  # Setup system static info for scope testing
  defp setup_scope_test_systems do
    test_systems = %{
      # C1 Wormhole
      @wh_system_j100001 => %{
        solar_system_id: @wh_system_j100001,
        solar_system_name: "J100001",
        solar_system_name_lc: "j100001",
        region_id: 11_000_001,
        constellation_id: 21_000_001,
        region_name: "A-R00001",
        constellation_name: "A-C00001",
        system_class: @c1,
        security: "-1.0",
        type_description: "Class 1",
        class_title: "C1",
        is_shattered: false,
        effect_name: nil,
        effect_power: nil,
        statics: ["H121"],
        wandering: [],
        triglavian_invasion_status: nil,
        sun_type_id: 45041
      },
      # C2 Wormhole
      @wh_system_j100002 => %{
        solar_system_id: @wh_system_j100002,
        solar_system_name: "J100002",
        solar_system_name_lc: "j100002",
        region_id: 11_000_001,
        constellation_id: 21_000_001,
        region_name: "A-R00001",
        constellation_name: "A-C00001",
        system_class: @c2,
        security: "-1.0",
        type_description: "Class 2",
        class_title: "C2",
        is_shattered: false,
        effect_name: nil,
        effect_power: nil,
        statics: ["D382", "L005"],
        wandering: [],
        triglavian_invasion_status: nil,
        sun_type_id: 45041
      },
      # High-sec system (Halenan 0.6)
      @hs_system_halenan => %{
        solar_system_id: @hs_system_halenan,
        solar_system_name: "Halenan",
        solar_system_name_lc: "halenan",
        region_id: 10_000_067,
        constellation_id: 20_000_901,
        region_name: "Devoid",
        constellation_name: "Devoid",
        system_class: @hs,
        security: "0.6",
        type_description: "High Security",
        class_title: "High Sec",
        is_shattered: false,
        effect_name: nil,
        effect_power: nil,
        statics: [],
        wandering: [],
        triglavian_invasion_status: nil,
        sun_type_id: 45041
      },
      # High-sec system (Mili 0.6)
      @hs_system_mili => %{
        solar_system_id: @hs_system_mili,
        solar_system_name: "Mili",
        solar_system_name_lc: "mili",
        region_id: 10_000_067,
        constellation_id: 20_000_901,
        region_name: "Devoid",
        constellation_name: "Devoid",
        system_class: @hs,
        security: "0.6",
        type_description: "High Security",
        class_title: "High Sec",
        is_shattered: false,
        effect_name: nil,
        effect_power: nil,
        statics: [],
        wandering: [],
        triglavian_invasion_status: nil,
        sun_type_id: 45041
      },
      # Low-sec system (Halmah 0.4)
      @ls_system_halmah => %{
        solar_system_id: @ls_system_halmah,
        solar_system_name: "Halmah",
        solar_system_name_lc: "halmah",
        region_id: 10_000_067,
        constellation_id: 20_000_901,
        region_name: "Devoid",
        constellation_name: "Devoid",
        system_class: @ls,
        security: "0.4",
        type_description: "Low Security",
        class_title: "Low Sec",
        is_shattered: false,
        effect_name: nil,
        effect_power: nil,
        statics: [],
        wandering: [],
        triglavian_invasion_status: nil,
        sun_type_id: 45041
      },
      # Null-sec system
      @ns_system_geminate => %{
        solar_system_id: @ns_system_geminate,
        solar_system_name: "Geminate",
        solar_system_name_lc: "geminate",
        region_id: 10_000_029,
        constellation_id: 20_000_400,
        region_name: "Geminate",
        constellation_name: "Geminate",
        system_class: @ns,
        security: "-0.5",
        type_description: "Null Security",
        class_title: "Null Sec",
        is_shattered: false,
        effect_name: nil,
        effect_power: nil,
        statics: [],
        wandering: [],
        triglavian_invasion_status: nil,
        sun_type_id: 45041
      }
    }

    Enum.each(test_systems, fn {solar_system_id, system_info} ->
      Cachex.put(:system_static_info_cache, solar_system_id, system_info)
    end)

    :ok
  end

  # Setup known stargates between adjacent k-space systems
  # This ensures that k-space to k-space connections WITH stargates are properly filtered
  # (connections WITHOUT stargates are treated as wormhole connections)
  defp setup_kspace_stargates do
    # Stargate between Halenan (HS) and Mili (HS) - adjacent high-sec systems
    # Cache key format: "jump_#{smaller_id}_#{larger_id}"
    halenan_mili_key = "jump_#{@hs_system_halenan}_#{@hs_system_mili}"

    WandererApp.Cache.insert(halenan_mili_key, %{
      from_solar_system_id: @hs_system_halenan,
      to_solar_system_id: @hs_system_mili
    })

    # Stargate between Halenan (HS) and Halmah (LS) - adjacent high-sec to low-sec
    halenan_halmah_key = "jump_#{@hs_system_halenan}_#{@ls_system_halmah}"

    WandererApp.Cache.insert(halenan_halmah_key, %{
      from_solar_system_id: @hs_system_halenan,
      to_solar_system_id: @ls_system_halmah
    })

    :ok
  end

  describe "Scope filtering logic tests" do
    # These tests verify the filtering logic without full integration
    # The actual filtering is tested more comprehensively in map_scopes_test.exs

    alias WandererApp.Map.Server.ConnectionsImpl
    alias WandererApp.Map.Server.SystemsImpl

    test "can_add_location correctly filters high-sec with [:wormholes, :null] scopes" do
      # High-sec should NOT be allowed with [:wormholes, :null]
      refute ConnectionsImpl.can_add_location([:wormholes, :null], @hs_system_halenan),
             "High-sec should be filtered out with [:wormholes, :null] scopes"

      refute ConnectionsImpl.can_add_location([:wormholes, :null], @hs_system_mili),
             "High-sec should be filtered out with [:wormholes, :null] scopes"
    end

    test "can_add_location correctly filters low-sec with [:wormholes, :null] scopes" do
      # Low-sec should NOT be allowed with [:wormholes, :null]
      refute ConnectionsImpl.can_add_location([:wormholes, :null], @ls_system_halmah),
             "Low-sec should be filtered out with [:wormholes, :null] scopes"
    end

    test "can_add_location correctly allows wormholes with [:wormholes, :null] scopes" do
      # Wormholes should be allowed
      assert ConnectionsImpl.can_add_location([:wormholes, :null], @wh_system_j100001),
             "Wormhole should be allowed with [:wormholes, :null] scopes"

      assert ConnectionsImpl.can_add_location([:wormholes, :null], @wh_system_j100002),
             "Wormhole should be allowed with [:wormholes, :null] scopes"
    end

    test "can_add_location correctly allows null-sec with [:wormholes, :null] scopes" do
      # Null-sec should be allowed
      assert ConnectionsImpl.can_add_location([:wormholes, :null], @ns_system_geminate),
             "Null-sec should be allowed with [:wormholes, :null] scopes"
    end

    test "maybe_add_system filters out high-sec when not jumping from wormhole" do
      # When scopes is [:wormholes, :null] and NOT jumping from wormhole,
      # high-sec systems should be filtered
      location = %{solar_system_id: @hs_system_halenan}
      # old_location is nil (no previous system)
      result = SystemsImpl.maybe_add_system("map_id", location, nil, [], [:wormholes, :null])
      assert result == :ok

      # old_location is also high-sec (k-space to k-space)
      old_location = %{solar_system_id: @hs_system_mili}

      result =
        SystemsImpl.maybe_add_system("map_id", location, old_location, [], [:wormholes, :null])

      assert result == :ok
    end

    test "maybe_add_system filters out low-sec when not jumping from wormhole" do
      location = %{solar_system_id: @ls_system_halmah}
      # old_location is high-sec (k-space to k-space)
      old_location = %{solar_system_id: @hs_system_halenan}

      result =
        SystemsImpl.maybe_add_system("map_id", location, old_location, [], [:wormholes, :null])

      assert result == :ok
    end

    test "maybe_add_system allows border high-sec when jumping FROM wormhole" do
      # When jumping FROM a wormhole TO high-sec with :wormholes scope,
      # the high-sec should be added as a border system
      location = %{solar_system_id: @hs_system_halenan}
      old_location = %{solar_system_id: @wh_system_j100001}

      # This should attempt to add the system (not filter it out)
      # The result will be an error because the map doesn't exist,
      # but that proves the filtering logic allowed it through
      result = SystemsImpl.maybe_add_system("map_id", location, old_location, [], [:wormholes])

      # The function attempts to add (returns error because map doesn't exist)
      # This proves border behavior is working - system was NOT filtered out
      assert match?({:error, _}, result),
             "Border system should attempt to be added (error because map doesn't exist)"
    end

    test "is_connection_valid allows WH to HS with [:wormholes, :null] (border behavior)" do
      # The connection is valid for border behavior - but individual systems are filtered
      assert ConnectionsImpl.is_connection_valid(
               [:wormholes, :null],
               @wh_system_j100001,
               @hs_system_halenan
             ),
             "WH to HS connection should be valid (border behavior)"
    end

    test "is_connection_valid rejects HS to LS with [:wormholes, :null] (no border)" do
      # HS to LS should be rejected - neither system matches scopes and no wormhole involved
      refute ConnectionsImpl.is_connection_valid(
               [:wormholes, :null],
               @hs_system_halenan,
               @ls_system_halmah
             ),
             "HS to LS connection should be rejected with [:wormholes, :null]"
    end

    test "is_connection_valid rejects HS to HS with [:wormholes, :null]" do
      # HS to HS should be rejected
      refute ConnectionsImpl.is_connection_valid(
               [:wormholes, :null],
               @hs_system_halenan,
               @hs_system_mili
             ),
             "HS to HS connection should be rejected with [:wormholes, :null]"
    end
  end

  describe "get_effective_scopes behavior" do
    alias WandererApp.Map.Server.CharactersImpl

    test "get_effective_scopes returns scopes array when present" do
      # Create a map struct with scopes array
      map = %{scopes: [:wormholes, :null]}
      scopes = CharactersImpl.get_effective_scopes(map)
      assert scopes == [:wormholes, :null]
    end

    test "get_effective_scopes converts legacy :all scope" do
      map = %{scope: :all}
      scopes = CharactersImpl.get_effective_scopes(map)
      assert scopes == [:wormholes, :hi, :low, :null, :pochven]
    end

    test "get_effective_scopes converts legacy :wormholes scope" do
      map = %{scope: :wormholes}
      scopes = CharactersImpl.get_effective_scopes(map)
      assert scopes == [:wormholes]
    end

    test "get_effective_scopes converts legacy :stargates scope" do
      map = %{scope: :stargates}
      scopes = CharactersImpl.get_effective_scopes(map)
      assert scopes == [:hi, :low, :null, :pochven]
    end

    test "get_effective_scopes converts legacy :none scope" do
      map = %{scope: :none}
      scopes = CharactersImpl.get_effective_scopes(map)
      assert scopes == []
    end

    test "get_effective_scopes defaults to [:wormholes] when no scope" do
      map = %{}
      scopes = CharactersImpl.get_effective_scopes(map)
      assert scopes == [:wormholes]
    end
  end

  describe "WandererApp.Map struct and new/1 function" do
    alias WandererApp.Map.Server.CharactersImpl

    test "Map struct includes scopes field" do
      # Verify the struct has the scopes field
      map_struct = %WandererApp.Map{}
      assert Map.has_key?(map_struct, :scopes)
      assert map_struct.scopes == nil
    end

    test "Map.new/1 extracts scopes from input" do
      # Simulate input from database (Ash resource)
      input = %{
        id: "test-map-id",
        name: "Test Map",
        scope: :wormholes,
        scopes: [:wormholes, :null],
        owner_id: "owner-123",
        acls: [],
        hubs: []
      }

      map = WandererApp.Map.new(input)

      assert map.map_id == "test-map-id"
      assert map.name == "Test Map"
      assert map.scope == :wormholes
      assert map.scopes == [:wormholes, :null]
    end

    test "Map.new/1 handles missing scopes (nil)" do
      # When scopes is not present in input, it should be nil
      input = %{
        id: "test-map-id",
        name: "Test Map",
        scope: :all,
        owner_id: "owner-123",
        acls: [],
        hubs: []
      }

      map = WandererApp.Map.new(input)

      assert map.map_id == "test-map-id"
      assert map.scope == :all
      assert map.scopes == nil
    end

    test "get_effective_scopes uses scopes field from Map struct when present" do
      # Create map struct with both scope and scopes
      input = %{
        id: "test-map-id",
        name: "Test Map",
        scope: :all,
        scopes: [:wormholes, :null],
        owner_id: "owner-123",
        acls: [],
        hubs: []
      }

      map = WandererApp.Map.new(input)

      # get_effective_scopes should prioritize scopes over scope
      effective = CharactersImpl.get_effective_scopes(map)
      assert effective == [:wormholes, :null]
    end

    test "get_effective_scopes falls back to legacy scope when scopes is nil" do
      # Create map struct with only legacy scope
      input = %{
        id: "test-map-id",
        name: "Test Map",
        scope: :all,
        owner_id: "owner-123",
        acls: [],
        hubs: []
      }

      map = WandererApp.Map.new(input)

      # get_effective_scopes should convert legacy :all scope
      effective = CharactersImpl.get_effective_scopes(map)
      assert effective == [:wormholes, :hi, :low, :null, :pochven]
    end

    test "get_effective_scopes falls back to legacy scope when scopes is empty list" do
      # Empty scopes list should fall back to legacy scope
      input = %{
        id: "test-map-id",
        name: "Test Map",
        scope: :stargates,
        scopes: [],
        owner_id: "owner-123",
        acls: [],
        hubs: []
      }

      map = WandererApp.Map.new(input)

      # get_effective_scopes should fall back to legacy scope conversion
      effective = CharactersImpl.get_effective_scopes(map)
      assert effective == [:hi, :low, :null, :pochven]
    end

    test "Map.new/1 extracts all scope variations correctly" do
      # Test various scope combinations
      test_cases = [
        {[:wormholes], [:wormholes]},
        {[:hi, :low], [:hi, :low]},
        {[:wormholes, :hi, :low, :null, :pochven], [:wormholes, :hi, :low, :null, :pochven]},
        {[:null], [:null]}
      ]

      for {input_scopes, expected_scopes} <- test_cases do
        input = %{
          id: "test-map-id",
          name: "Test Map",
          scope: :wormholes,
          scopes: input_scopes,
          owner_id: "owner-123",
          acls: [],
          hubs: []
        }

        map = WandererApp.Map.new(input)
        effective = CharactersImpl.get_effective_scopes(map)

        assert effective == expected_scopes,
               "Expected #{inspect(expected_scopes)}, got #{inspect(effective)} for input #{inspect(input_scopes)}"
      end
    end
  end
end
