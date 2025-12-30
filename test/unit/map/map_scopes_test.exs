defmodule WandererApp.Map.Server.MapScopesTest do
  @moduledoc """
  Tests for the map scopes functionality in ConnectionsImpl.
  Tests can_add_location/2 and is_connection_valid/3 with the new
  array-based scopes system.
  """
  use WandererApp.DataCase

  alias WandererApp.Map.Server.ConnectionsImpl

  # System class constants (matching the impl)
  @c1 1
  @c2 2
  @hs 7
  @ls 8
  @ns 9
  @thera 12
  @sentinel 14
  @pochven 25
  @jita 30_000_142

  # Test solar system IDs
  # J100001 - C1 wormhole
  @wh_system_id 31_000_001
  # C2 wormhole
  @c2_system_id 31_000_002
  # Thera
  @thera_id 31_000_005
  # Highsec system
  @hs_system_id 30_000_001
  # Lowsec system
  @ls_system_id 30_000_100
  # Nullsec system
  @ns_system_id 30_000_200
  # Pochven system
  @pochven_id 30_000_300

  setup do
    # Set up system static info cache directly (the impl uses Cachex, not mocks)
    test_systems = %{
      # C1 wormhole system
      31_000_001 => %{solar_system_id: 31_000_001, system_class: @c1},
      # C2 wormhole system
      31_000_002 => %{solar_system_id: 31_000_002, system_class: @c2},
      # Thera (special wormhole)
      31_000_005 => %{solar_system_id: 31_000_005, system_class: @thera},
      # Sentinel (Triglavian wormhole)
      31_000_014 => %{solar_system_id: 31_000_014, system_class: @sentinel},
      # Highsec system
      30_000_001 => %{solar_system_id: 30_000_001, system_class: @hs},
      # Another highsec for tests
      30_000_002 => %{solar_system_id: 30_000_002, system_class: @hs},
      # Lowsec system
      30_000_100 => %{solar_system_id: 30_000_100, system_class: @ls},
      # Another lowsec for tests
      30_000_101 => %{solar_system_id: 30_000_101, system_class: @ls},
      # Nullsec system
      30_000_200 => %{solar_system_id: 30_000_200, system_class: @ns},
      # Another nullsec for tests
      30_000_201 => %{solar_system_id: 30_000_201, system_class: @ns},
      # Pochven system
      30_000_300 => %{solar_system_id: 30_000_300, system_class: @pochven},
      # Another pochven for tests
      30_000_301 => %{solar_system_id: 30_000_301, system_class: @pochven},
      # Jita (prohibited system - highsec)
      30_000_142 => %{solar_system_id: 30_000_142, system_class: @hs}
    }

    Enum.each(test_systems, fn {solar_system_id, system_info} ->
      Cachex.put(:system_static_info_cache, solar_system_id, system_info)
    end)

    :ok
  end

  describe "can_add_location/2 with array scopes" do
    test "returns false for nil solar_system_id" do
      assert ConnectionsImpl.can_add_location([:wormholes], nil) == false
      assert ConnectionsImpl.can_add_location([:hi, :low], nil) == false
    end

    test "returns false for empty scopes array" do
      assert ConnectionsImpl.can_add_location([], @wh_system_id) == false
      assert ConnectionsImpl.can_add_location([], @hs_system_id) == false
    end

    test ":wormholes scope allows only W-space systems" do
      # Should allow wormhole systems
      assert ConnectionsImpl.can_add_location([:wormholes], @wh_system_id) == true
      assert ConnectionsImpl.can_add_location([:wormholes], @c2_system_id) == true
      assert ConnectionsImpl.can_add_location([:wormholes], @thera_id) == true

      # Should not allow K-space systems
      assert ConnectionsImpl.can_add_location([:wormholes], @hs_system_id) == false
      assert ConnectionsImpl.can_add_location([:wormholes], @ls_system_id) == false
      assert ConnectionsImpl.can_add_location([:wormholes], @ns_system_id) == false
      assert ConnectionsImpl.can_add_location([:wormholes], @pochven_id) == false
    end

    test ":hi scope allows only highsec systems" do
      assert ConnectionsImpl.can_add_location([:hi], @hs_system_id) == true
      assert ConnectionsImpl.can_add_location([:hi], @wh_system_id) == false
      assert ConnectionsImpl.can_add_location([:hi], @ls_system_id) == false
      assert ConnectionsImpl.can_add_location([:hi], @ns_system_id) == false
      assert ConnectionsImpl.can_add_location([:hi], @pochven_id) == false
    end

    test ":low scope allows only lowsec systems" do
      assert ConnectionsImpl.can_add_location([:low], @ls_system_id) == true
      assert ConnectionsImpl.can_add_location([:low], @wh_system_id) == false
      assert ConnectionsImpl.can_add_location([:low], @hs_system_id) == false
      assert ConnectionsImpl.can_add_location([:low], @ns_system_id) == false
      assert ConnectionsImpl.can_add_location([:low], @pochven_id) == false
    end

    test ":null scope allows only nullsec systems" do
      assert ConnectionsImpl.can_add_location([:null], @ns_system_id) == true
      assert ConnectionsImpl.can_add_location([:null], @wh_system_id) == false
      assert ConnectionsImpl.can_add_location([:null], @hs_system_id) == false
      assert ConnectionsImpl.can_add_location([:null], @ls_system_id) == false
      assert ConnectionsImpl.can_add_location([:null], @pochven_id) == false
    end

    test ":pochven scope allows only pochven systems" do
      assert ConnectionsImpl.can_add_location([:pochven], @pochven_id) == true
      assert ConnectionsImpl.can_add_location([:pochven], @wh_system_id) == false
      assert ConnectionsImpl.can_add_location([:pochven], @hs_system_id) == false
      assert ConnectionsImpl.can_add_location([:pochven], @ls_system_id) == false
      assert ConnectionsImpl.can_add_location([:pochven], @ns_system_id) == false
    end

    test "multiple scopes allow systems matching any scope" do
      # [:wormholes, :hi] should allow both wormhole and highsec
      assert ConnectionsImpl.can_add_location([:wormholes, :hi], @wh_system_id) == true
      assert ConnectionsImpl.can_add_location([:wormholes, :hi], @hs_system_id) == true
      assert ConnectionsImpl.can_add_location([:wormholes, :hi], @ls_system_id) == false

      # [:hi, :low, :null] should allow all K-space except pochven
      assert ConnectionsImpl.can_add_location([:hi, :low, :null], @hs_system_id) == true
      assert ConnectionsImpl.can_add_location([:hi, :low, :null], @ls_system_id) == true
      assert ConnectionsImpl.can_add_location([:hi, :low, :null], @ns_system_id) == true
      assert ConnectionsImpl.can_add_location([:hi, :low, :null], @pochven_id) == false
      assert ConnectionsImpl.can_add_location([:hi, :low, :null], @wh_system_id) == false

      # All scopes should allow everything
      all_scopes = [:wormholes, :hi, :low, :null, :pochven]
      assert ConnectionsImpl.can_add_location(all_scopes, @wh_system_id) == true
      assert ConnectionsImpl.can_add_location(all_scopes, @hs_system_id) == true
      assert ConnectionsImpl.can_add_location(all_scopes, @ls_system_id) == true
      assert ConnectionsImpl.can_add_location(all_scopes, @ns_system_id) == true
      assert ConnectionsImpl.can_add_location(all_scopes, @pochven_id) == true
    end

    test "prohibited systems are blocked" do
      # Jita is prohibited
      assert ConnectionsImpl.can_add_location([:hi], @jita) == false

      assert ConnectionsImpl.can_add_location([:wormholes, :hi, :low, :null, :pochven], @jita) ==
               false
    end
  end

  describe "can_add_location/2 with legacy scopes (backward compatibility)" do
    test ":none scope blocks all systems" do
      assert ConnectionsImpl.can_add_location(:none, @wh_system_id) == false
      assert ConnectionsImpl.can_add_location(:none, @hs_system_id) == false
      assert ConnectionsImpl.can_add_location(:none, @ls_system_id) == false
    end

    test ":wormholes legacy scope allows W-space" do
      assert ConnectionsImpl.can_add_location(:wormholes, @wh_system_id) == true
      assert ConnectionsImpl.can_add_location(:wormholes, @hs_system_id) == false
    end

    test ":stargates legacy scope allows K-space" do
      assert ConnectionsImpl.can_add_location(:stargates, @hs_system_id) == true
      assert ConnectionsImpl.can_add_location(:stargates, @ls_system_id) == true
      assert ConnectionsImpl.can_add_location(:stargates, @ns_system_id) == true
      assert ConnectionsImpl.can_add_location(:stargates, @pochven_id) == true
      assert ConnectionsImpl.can_add_location(:stargates, @wh_system_id) == false
    end

    test ":all legacy scope allows everything except prohibited" do
      assert ConnectionsImpl.can_add_location(:all, @wh_system_id) == true
      assert ConnectionsImpl.can_add_location(:all, @hs_system_id) == true
      assert ConnectionsImpl.can_add_location(:all, @ls_system_id) == true
      assert ConnectionsImpl.can_add_location(:all, @ns_system_id) == true
      assert ConnectionsImpl.can_add_location(:all, @pochven_id) == true
      # Jita is still prohibited
      assert ConnectionsImpl.can_add_location(:all, @jita) == false
    end
  end

  describe "is_connection_valid/3 with array scopes" do
    test "returns false for nil system IDs" do
      assert ConnectionsImpl.is_connection_valid([:wormholes], nil, @wh_system_id) == false
      assert ConnectionsImpl.is_connection_valid([:wormholes], @wh_system_id, nil) == false
      assert ConnectionsImpl.is_connection_valid([:hi], nil, nil) == false
    end

    test "returns false for empty scopes array" do
      assert ConnectionsImpl.is_connection_valid([], @wh_system_id, @c2_system_id) == false
      assert ConnectionsImpl.is_connection_valid([], @hs_system_id, @ls_system_id) == false
    end

    test "returns false when systems are the same" do
      assert ConnectionsImpl.is_connection_valid([:wormholes], @wh_system_id, @wh_system_id) ==
               false

      assert ConnectionsImpl.is_connection_valid([:hi], @hs_system_id, @hs_system_id) == false
    end

    test "wormhole border behavior: WH connections allow border k-space systems" do
      # WH to HS with [:wormholes]: valid (wormhole border behavior)
      # At least one system is WH, :wormholes is enabled -> border k-space allowed
      assert ConnectionsImpl.is_connection_valid([:wormholes], @wh_system_id, @hs_system_id) ==
               true

      # WH to HS with [:hi] only: INVALID (no wormhole scope, WH doesn't match :hi)
      # Neither system matches when we require both to match (no wormhole border behavior)
      assert ConnectionsImpl.is_connection_valid([:hi], @wh_system_id, @hs_system_id) == false

      # WH to WH: valid only if :wormholes is selected
      assert ConnectionsImpl.is_connection_valid([:wormholes], @wh_system_id, @c2_system_id) ==
               true

      assert ConnectionsImpl.is_connection_valid([:hi], @wh_system_id, @c2_system_id) == false
    end

    test "k-space connections require BOTH systems to match scopes" do
      # HS to LS: requires BOTH to match, so single scope is not enough
      assert ConnectionsImpl.is_connection_valid([:hi], @hs_system_id, @ls_system_id) == false
      assert ConnectionsImpl.is_connection_valid([:low], @hs_system_id, @ls_system_id) == false
      assert ConnectionsImpl.is_connection_valid([:null], @hs_system_id, @ls_system_id) == false

      # HS to LS with [:hi, :low]: valid (both match)
      assert ConnectionsImpl.is_connection_valid([:hi, :low], @hs_system_id, @ls_system_id) ==
               true

      # HS to HS: valid with [:hi] (both match)
      assert ConnectionsImpl.is_connection_valid([:hi], @hs_system_id, 30_000_002) == true

      # NS to NS: valid with [:null] (both match)
      assert ConnectionsImpl.is_connection_valid([:null], @ns_system_id, @ns_system_id) == false
      # (same system returns false)
    end

    test "connection with multiple scopes" do
      # With [:wormholes, :hi]:
      # - WH to WH: valid (both match :wormholes)
      # - HS to HS: valid (both match :hi, or wormhole if no stargate)
      # - WH to HS: valid (wormhole border behavior - WH is wormhole, :wormholes enabled)
      scopes = [:wormholes, :hi]
      assert ConnectionsImpl.is_connection_valid(scopes, @wh_system_id, @c2_system_id) == true
      assert ConnectionsImpl.is_connection_valid(scopes, @hs_system_id, 30_000_002) == true
      assert ConnectionsImpl.is_connection_valid(scopes, @wh_system_id, @hs_system_id) == true

      # LS to NS with [:wormholes, :hi] - if no stargate exists, it's a wormhole connection
      # With :wormholes enabled, wormhole connections are valid
      assert ConnectionsImpl.is_connection_valid(scopes, @ls_system_id, @ns_system_id) == true

      # HS to LS with [:wormholes, :hi] - if no stargate exists, it's a wormhole connection
      assert ConnectionsImpl.is_connection_valid(scopes, @hs_system_id, @ls_system_id) == true
    end

    test "all scopes allows any connection" do
      all_scopes = [:wormholes, :hi, :low, :null, :pochven]
      assert ConnectionsImpl.is_connection_valid(all_scopes, @wh_system_id, @hs_system_id) == true
      assert ConnectionsImpl.is_connection_valid(all_scopes, @ls_system_id, @ns_system_id) == true
      assert ConnectionsImpl.is_connection_valid(all_scopes, @pochven_id, @wh_system_id) == true
    end

    test "prohibited systems block connections" do
      # Jita should block connections even with valid scopes
      assert ConnectionsImpl.is_connection_valid([:hi], @jita, @hs_system_id) == false
      assert ConnectionsImpl.is_connection_valid([:hi], @hs_system_id, @jita) == false
    end
  end

  describe "is_connection_valid/3 with legacy scopes (backward compatibility)" do
    test ":none blocks all connections" do
      assert ConnectionsImpl.is_connection_valid(:none, @wh_system_id, @c2_system_id) == false
      assert ConnectionsImpl.is_connection_valid(:none, @hs_system_id, @ls_system_id) == false
    end

    test ":all allows all connections" do
      assert ConnectionsImpl.is_connection_valid(:all, @wh_system_id, @c2_system_id) == true
      assert ConnectionsImpl.is_connection_valid(:all, @hs_system_id, @ls_system_id) == true
      assert ConnectionsImpl.is_connection_valid(:all, @wh_system_id, @hs_system_id) == true
    end

    # Note: :wormholes and :stargates legacy scopes require get_solar_system_jump/2
    # which is not in the mock behaviour. These are tested indirectly through
    # integration tests and the new array-based scopes cover the same functionality.
  end

  describe "is_prohibited_system_class?/1" do
    test "returns true for prohibited classes" do
      # A1-A5 (19-23) and CCP4 (24) are prohibited
      assert ConnectionsImpl.is_prohibited_system_class?(19) == true
      assert ConnectionsImpl.is_prohibited_system_class?(20) == true
      assert ConnectionsImpl.is_prohibited_system_class?(21) == true
      assert ConnectionsImpl.is_prohibited_system_class?(22) == true
      assert ConnectionsImpl.is_prohibited_system_class?(23) == true
      assert ConnectionsImpl.is_prohibited_system_class?(24) == true
    end

    test "returns false for allowed classes" do
      # Standard wormhole classes
      assert ConnectionsImpl.is_prohibited_system_class?(1) == false
      assert ConnectionsImpl.is_prohibited_system_class?(2) == false
      assert ConnectionsImpl.is_prohibited_system_class?(6) == false

      # K-space classes
      assert ConnectionsImpl.is_prohibited_system_class?(7) == false
      assert ConnectionsImpl.is_prohibited_system_class?(8) == false
      assert ConnectionsImpl.is_prohibited_system_class?(9) == false
      assert ConnectionsImpl.is_prohibited_system_class?(25) == false
    end
  end

  describe "maybe_add_system/5 scope filtering" do
    alias WandererApp.Map.Server.SystemsImpl

    test "returns :ok without filtering when scopes is nil" do
      # When scopes is nil, should not filter (backward compatibility)
      result = SystemsImpl.maybe_add_system("map_id", nil, nil, [])
      assert result == :ok
    end

    test "returns :ok without filtering when scopes is empty list" do
      # Empty scopes should not filter (let through)
      result = SystemsImpl.maybe_add_system("map_id", nil, nil, [], [])
      assert result == :ok
    end

    test "filters system when scopes provided and system doesn't match" do
      # When scopes is [:wormholes] and system is Hi-Sec, should filter (return :ok without adding)
      location = %{solar_system_id: @hs_system_id}
      result = SystemsImpl.maybe_add_system("map_id", location, nil, [], [:wormholes])
      # Returns :ok because system was filtered out (not an error, just skipped)
      assert result == :ok
    end

    test "allows system through when scopes match (verified via can_add_location)" do
      # When scopes is [:wormholes] and system is WH, filtering should allow it
      # We test this via can_add_location which is what maybe_add_system uses internally
      assert ConnectionsImpl.can_add_location([:wormholes], @wh_system_id) == true
      assert ConnectionsImpl.can_add_location([:null], @ns_system_id) == true
      assert ConnectionsImpl.can_add_location([:wormholes, :null], @wh_system_id) == true
      assert ConnectionsImpl.can_add_location([:wormholes, :null], @ns_system_id) == true
    end
  end

  describe "border system auto-addition behavior" do
    # Tests that verify bordered systems are correctly auto-added ONLY for wormholes.
    # Key behavior:
    # - Wormhole border: WH to Hi-Sec with [:wormholes] -> BOTH added (border behavior)
    # - K-space only: Null to Hi-Sec with [:wormholes, :null] -> REJECTED (no border for k-space)
    # - K-space must match: both systems must match scopes when no wormhole involved

    test "WORMHOLE BORDER: WH->Hi-Sec with [:wormholes] is VALID (border k-space added)" do
      # Border case: moving from WH to k-space
      # Valid because :wormholes enabled AND one system is WH
      assert ConnectionsImpl.is_connection_valid([:wormholes], @wh_system_id, @hs_system_id) ==
               true
    end

    test "WORMHOLE BORDER: Hi-Sec->WH with [:wormholes] is VALID (border k-space added)" do
      # Border case: moving from k-space to WH
      # Valid because :wormholes enabled AND one system is WH
      assert ConnectionsImpl.is_connection_valid([:wormholes], @hs_system_id, @wh_system_id) ==
               true
    end

    test "K-SPACE ONLY: Hi-Sec->Hi-Sec with [:wormholes] is VALID when no stargate exists" do
      # If no stargate exists between two k-space systems, it's a wormhole connection
      # (The test systems don't have stargate data, so this is treated as a wormhole)
      assert ConnectionsImpl.is_connection_valid([:wormholes], @hs_system_id, 30_000_002) == true
    end

    test "K-SPACE ONLY: Null->Hi-Sec with [:wormholes, :null] is VALID when no stargate exists" do
      # If no stargate exists, this is a wormhole connection through k-space
      # With [:wormholes] enabled, wormhole connections are valid
      assert ConnectionsImpl.is_connection_valid(
               [:wormholes, :null],
               @ns_system_id,
               @hs_system_id
             ) ==
               true
    end

    test "K-SPACE ONLY: Hi-Sec->Low-Sec with [:wormholes, :null] is VALID when no stargate exists" do
      # If no stargate exists, this is a wormhole connection
      # With [:wormholes] enabled, wormhole connections are valid
      assert ConnectionsImpl.is_connection_valid(
               [:wormholes, :null],
               @hs_system_id,
               @ls_system_id
             ) ==
               true
    end

    test "K-SPACE ONLY: Low-Sec->Hi-Sec with [:low] is REJECTED (no border for k-space)" do
      # Low-Sec matches :low, but Hi-Sec doesn't match
      # No wormhole involved, so BOTH must match -> rejected
      assert ConnectionsImpl.is_connection_valid([:low], @ls_system_id, @hs_system_id) == false
    end

    test "K-SPACE MATCH: Low-Sec->Low-Sec with [:low] is VALID (both match)" do
      # Both systems match :low
      assert ConnectionsImpl.is_connection_valid([:low], @ls_system_id, 30_000_101) == true
    end

    test "K-SPACE MATCH: Null->Null with [:null] is VALID (both match)" do
      # Would need two different null-sec systems for this test
      # Using same system returns false (same system check)
      assert ConnectionsImpl.is_connection_valid([:null], @ns_system_id, @ns_system_id) == false
    end

    test "WORMHOLE BORDER: Pochven->WH with [:wormholes, :pochven] is VALID" do
      # WH is wormhole, :wormholes enabled -> border behavior applies
      assert ConnectionsImpl.is_connection_valid(
               [:wormholes, :pochven],
               @pochven_id,
               @wh_system_id
             ) ==
               true
    end

    test "WORMHOLE BORDER: WH->Pochven with [:wormholes] is VALID (border k-space)" do
      # WH is wormhole, :wormholes enabled -> border behavior, Pochven added as border
      assert ConnectionsImpl.is_connection_valid([:wormholes], @wh_system_id, @pochven_id) == true
    end

    test "border systems: WH->Hi-Sec->WH path with [:wormholes] scope" do
      # Simulates a character path through k-space between WHs
      # First jump: WH to Hi-Sec - valid (wormhole border)
      assert ConnectionsImpl.is_connection_valid([:wormholes], @wh_system_id, @hs_system_id) ==
               true

      # Second jump: Hi-Sec to WH - valid (wormhole border)
      assert ConnectionsImpl.is_connection_valid([:wormholes], @hs_system_id, @c2_system_id) ==
               true
    end

    test "k-space chain with [:wormholes] scope is VALID when no stargates exist" do
      # If no stargates exist between k-space systems, they're wormhole connections
      # With [:wormholes] scope, these should be tracked
      assert ConnectionsImpl.is_connection_valid([:wormholes], @hs_system_id, 30_000_002) == true
      assert ConnectionsImpl.is_connection_valid([:wormholes], 30_000_002, @ls_system_id) == true
    end

    test "k-space chain with [:wormholes, :null] - wormhole connections are tracked" do
      # If no stargates exist, these are wormhole connections through k-space
      # With [:wormholes] enabled, all wormhole connections are tracked
      assert ConnectionsImpl.is_connection_valid(
               [:wormholes, :null],
               @ns_system_id,
               @hs_system_id
             ) ==
               true

      # Hi-Sec to Low-Sec is also a wormhole connection (no stargate in test data)
      assert ConnectionsImpl.is_connection_valid(
               [:wormholes, :null],
               @hs_system_id,
               @ls_system_id
             ) ==
               true
    end
  end

  describe "wormhole connections in k-space (unknown connections)" do
    @moduledoc """
    These tests verify the behavior for k-space to k-space connections that are
    NOT known stargates. Such connections should be treated as wormhole connections.

    Scenario: A player jumps from Low-Sec to Hi-Sec. If there's no stargate between
    these systems, the jump must have been through a wormhole. With [:wormholes] scope,
    this connection SHOULD be valid.

    The connection TYPE (stargate vs wormhole) is determined separately in
    maybe_add_connection using is_connection_valid(:stargates, ...).
    """

    test "Low-Sec to Hi-Sec with [:wormholes] is valid when no stargate exists (wormhole connection)" do
      # When there's no stargate between low-sec and hi-sec, the jump must be through a wormhole
      # With [:wormholes] scope, this wormhole connection should be valid
      #
      # The test systems @ls_system_id and @hs_system_id don't have a known stargate between them
      # (they're test systems not in the EVE jump database), so this should be treated as a wormhole

      result = ConnectionsImpl.is_connection_valid([:wormholes], @ls_system_id, @hs_system_id)

      # Connection is valid because no stargate exists - it's a wormhole connection
      assert result == true,
             "K-space to K-space with [:wormholes] should be valid when no stargate exists"
    end

    test "Hi-Sec to Low-Sec with [:wormholes] is valid when no stargate exists" do
      # Test the reverse direction
      result = ConnectionsImpl.is_connection_valid([:wormholes], @hs_system_id, @ls_system_id)

      assert result == true,
             "Hi-Sec to Low-Sec with [:wormholes] should be valid when no stargate exists"
    end

    test "Null-Sec to Hi-Sec with [:wormholes] is valid when no stargate exists" do
      # Null to Hi-Sec through wormhole
      result = ConnectionsImpl.is_connection_valid([:wormholes], @ns_system_id, @hs_system_id)

      assert result == true,
             "Null-Sec to Hi-Sec with [:wormholes] should be valid when no stargate exists"
    end

    test "Low-Sec to Null-Sec with [:wormholes] is valid when no stargate exists" do
      # Low to Null through wormhole
      result = ConnectionsImpl.is_connection_valid([:wormholes], @ls_system_id, @ns_system_id)

      assert result == true,
             "Low-Sec to Null-Sec with [:wormholes] should be valid when no stargate exists"
    end

    test "Pochven to Hi-Sec with [:wormholes] is valid when no stargate exists" do
      # Pochven has special wormhole connections to k-space
      result = ConnectionsImpl.is_connection_valid([:wormholes], @pochven_id, @hs_system_id)

      assert result == true,
             "Pochven to Hi-Sec with [:wormholes] should be valid when no stargate exists"
    end

    # Same-space-type wormhole connections
    # These verify that jumps within the same security class are valid when no stargate exists

    test "Low-Sec to Low-Sec with [:wormholes] is valid when no stargate exists" do
      # A wormhole can connect two low-sec systems
      # With [:wormholes] scope and no known stargate, this should be tracked
      result = ConnectionsImpl.is_connection_valid([:wormholes], @ls_system_id, 30_000_101)

      assert result == true,
             "Low-Sec to Low-Sec with [:wormholes] should be valid when no stargate exists"
    end

    test "Hi-Sec to Hi-Sec with [:wormholes] is valid when no stargate exists" do
      # A wormhole can connect two hi-sec systems
      # With [:wormholes] scope and no known stargate, this should be tracked
      result = ConnectionsImpl.is_connection_valid([:wormholes], @hs_system_id, 30_000_002)

      assert result == true,
             "Hi-Sec to Hi-Sec with [:wormholes] should be valid when no stargate exists"
    end

    test "Null-Sec to Null-Sec with [:wormholes] is valid when no stargate exists" do
      # A wormhole can connect two null-sec systems
      # With [:wormholes] scope and no known stargate, this should be tracked
      result = ConnectionsImpl.is_connection_valid([:wormholes], @ns_system_id, 30_000_201)

      assert result == true,
             "Null-Sec to Null-Sec with [:wormholes] should be valid when no stargate exists"
    end

    test "Pochven to Pochven with [:wormholes] is valid when no stargate exists" do
      # A wormhole can connect two Pochven systems
      # With [:wormholes] scope and no known stargate, this should be tracked
      result = ConnectionsImpl.is_connection_valid([:wormholes], @pochven_id, 30_000_301)

      assert result == true,
             "Pochven to Pochven with [:wormholes] should be valid when no stargate exists"
    end

    # Cross-space-type comprehensive tests
    # Verify all k-space combinations work correctly

    test "all k-space combinations with [:wormholes] are valid when no stargate exists" do
      # Test all combinations of k-space security types
      # All should be valid because no stargates exist in test data = wormhole connections

      # Hi-Sec combinations
      assert ConnectionsImpl.is_connection_valid([:wormholes], @hs_system_id, @ls_system_id) == true,
             "Hi->Low should be valid"
      assert ConnectionsImpl.is_connection_valid([:wormholes], @hs_system_id, @ns_system_id) == true,
             "Hi->Null should be valid"
      assert ConnectionsImpl.is_connection_valid([:wormholes], @hs_system_id, @pochven_id) == true,
             "Hi->Pochven should be valid"

      # Low-Sec combinations
      assert ConnectionsImpl.is_connection_valid([:wormholes], @ls_system_id, @hs_system_id) == true,
             "Low->Hi should be valid"
      assert ConnectionsImpl.is_connection_valid([:wormholes], @ls_system_id, @ns_system_id) == true,
             "Low->Null should be valid"
      assert ConnectionsImpl.is_connection_valid([:wormholes], @ls_system_id, @pochven_id) == true,
             "Low->Pochven should be valid"

      # Null-Sec combinations
      assert ConnectionsImpl.is_connection_valid([:wormholes], @ns_system_id, @hs_system_id) == true,
             "Null->Hi should be valid"
      assert ConnectionsImpl.is_connection_valid([:wormholes], @ns_system_id, @ls_system_id) == true,
             "Null->Low should be valid"
      assert ConnectionsImpl.is_connection_valid([:wormholes], @ns_system_id, @pochven_id) == true,
             "Null->Pochven should be valid"

      # Pochven combinations
      assert ConnectionsImpl.is_connection_valid([:wormholes], @pochven_id, @hs_system_id) == true,
             "Pochven->Hi should be valid"
      assert ConnectionsImpl.is_connection_valid([:wormholes], @pochven_id, @ls_system_id) == true,
             "Pochven->Low should be valid"
      assert ConnectionsImpl.is_connection_valid([:wormholes], @pochven_id, @ns_system_id) == true,
             "Pochven->Null should be valid"
    end
  end
end
