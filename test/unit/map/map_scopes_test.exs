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
      # Pochven system
      30_000_300 => %{solar_system_id: 30_000_300, system_class: @pochven},
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

    test "connection valid when at least one system matches a scope" do
      # WH to HS: valid if either :wormholes or :hi is selected
      assert ConnectionsImpl.is_connection_valid([:wormholes], @wh_system_id, @hs_system_id) ==
               true

      assert ConnectionsImpl.is_connection_valid([:hi], @wh_system_id, @hs_system_id) == true

      # WH to WH: valid only if :wormholes is selected
      assert ConnectionsImpl.is_connection_valid([:wormholes], @wh_system_id, @c2_system_id) ==
               true

      assert ConnectionsImpl.is_connection_valid([:hi], @wh_system_id, @c2_system_id) == false

      # HS to LS: valid if :hi or :low is selected
      assert ConnectionsImpl.is_connection_valid([:hi], @hs_system_id, @ls_system_id) == true
      assert ConnectionsImpl.is_connection_valid([:low], @hs_system_id, @ls_system_id) == true
      assert ConnectionsImpl.is_connection_valid([:null], @hs_system_id, @ls_system_id) == false
    end

    test "connection with multiple scopes allows cross-space movement" do
      # With [:wormholes, :hi], all of these should be valid:
      # - WH to WH (wormholes matches)
      # - HS to HS (hi matches)
      # - WH to HS (either matches)
      scopes = [:wormholes, :hi]
      assert ConnectionsImpl.is_connection_valid(scopes, @wh_system_id, @c2_system_id) == true
      assert ConnectionsImpl.is_connection_valid(scopes, @hs_system_id, 30_000_002) == true
      assert ConnectionsImpl.is_connection_valid(scopes, @wh_system_id, @hs_system_id) == true

      # But LS to NS should not be valid with [:wormholes, :hi]
      assert ConnectionsImpl.is_connection_valid(scopes, @ls_system_id, @ns_system_id) == false
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
end
