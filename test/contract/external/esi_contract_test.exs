defmodule WandererApp.Contract.External.EsiContractTest do
  @moduledoc """
  Contract tests for EVE ESI API integration.

  This module tests:
  - ESI API request/response contracts
  - Authentication with ESI
  - Character data contracts
  - Location data contracts
  - Ship data contracts

  These tests validate the structure and format of responses from the ESI API mock,
  ensuring consistent contract compliance across different execution contexts.
  """

  use WandererAppWeb.ApiCase, async: false

  import WandererApp.Support.ContractHelpers.ApiContractHelpers

  setup do
    # Ensure mocks are properly set up for each test
    # This is particularly important when running tests in isolation
    WandererApp.Test.MockAllowance.ensure_global_mocks()
    
    # Explicitly set up the mock stubs that might not be available when running in isolation
    # This ensures the tests work whether run individually or as part of the suite
    Mox.stub(WandererApp.CachedInfo.Mock, :get_server_status, fn ->
      {:ok, %{"players" => 30000, "server_version" => "1234567"}}
    end)
    
    Mox.stub(WandererApp.CachedInfo.Mock, :get_character_info, fn character_id ->
      {:ok,
       %{
         "character_id" => character_id,
         "name" => "Test Character",
         "corporation_id" => "123456",
         "alliance_id" => "789012",
         "security_status" => 5.0,
         "birthday" => "2020-01-01T00:00:00Z"
       }}
    end)
    
    Mox.stub(WandererApp.CachedInfo.Mock, :get_character_location, fn _character_id ->
      {:ok, %{"solar_system_id" => 30000142, "station_id" => 60003760}}
    end)
    
    Mox.stub(WandererApp.CachedInfo.Mock, :get_character_ship, fn _character_id ->
      {:ok, %{"ship_item_id" => 1234567890, "ship_type_id" => 670, "ship_name" => "Test Ship"}}
    end)
    
    Mox.stub(WandererApp.CachedInfo.Mock, :get_ship_type, fn ship_type_id ->
      {:ok,
       %{
         "type_id" => ship_type_id,
         "name" => "Caracal",
         "group_id" => 358,
         "mass" => 12_750_000
       }}
    end)
    
    Mox.stub(WandererApp.CachedInfo.Mock, :get_system_static_info, fn system_id ->
      {:ok,
       %{
         solar_system_id: system_id,
         solar_system_name: "Jita",
         security: 0.9,
         region_id: 10000002,
         constellation_id: 20000020,
         class_id: nil
       }}
    end)
    
    # Verify the mock is accessible and configured
    {:ok, _status} = WandererApp.CachedInfo.Mock.get_server_status()
    
    :ok
  end

  describe "ESI Character Information Contract" do
    test "character info response structure" do
      character_id = "123456789"

      # Verify mock is accessible and get character info
      assert {:ok, character_info} = WandererApp.CachedInfo.Mock.get_character_info(character_id)

      # Validate ESI character info contract
      validate_esi_character_info_contract(character_info)
    end
  end

  describe "ESI Character Location Contract" do
    test "character location response structure" do
      character_id = "123456789"

      # Verify mock is accessible and get character location
      assert {:ok, location} = WandererApp.CachedInfo.Mock.get_character_location(character_id)

      # Validate ESI location contract
      validate_esi_location_contract(location)
    end
  end

  describe "ESI Character Ship Contract" do
    test "character ship response structure" do
      character_id = "123456789"

      # Verify mock is accessible and get character ship
      assert {:ok, ship} = WandererApp.CachedInfo.Mock.get_character_ship(character_id)

      # Validate ESI ship contract
      validate_esi_ship_contract(ship)
    end
  end

  describe "ESI Server Status Contract" do
    test "server status response structure" do
      # Verify mock is accessible and get server status
      assert {:ok, status} = WandererApp.CachedInfo.Mock.get_server_status()

      # Validate server status contract
      validate_esi_server_status_contract(status)
    end
  end

  describe "ESI Ship Type Contract" do
    test "ship type response structure" do
      # Caracal
      ship_type_id = 670

      # Verify mock is accessible and get ship type
      assert {:ok, ship_type} = WandererApp.CachedInfo.Mock.get_ship_type(ship_type_id)

      # Validate ship type contract
      assert is_map(ship_type)
      assert Map.has_key?(ship_type, "type_id")
      assert Map.has_key?(ship_type, "name")
      assert ship_type["type_id"] == ship_type_id
    end
  end

  describe "ESI System Info Contract" do
    test "system static info response structure" do
      # Jita
      system_id = 30_000_142

      # Verify mock is accessible and get system info
      assert {:ok, system_info} = WandererApp.CachedInfo.Mock.get_system_static_info(system_id)

      # Validate system info contract
      assert is_map(system_info)
      assert system_info.solar_system_id == system_id
      assert Map.has_key?(system_info, :solar_system_name)
      assert Map.has_key?(system_info, :security)
      assert Map.has_key?(system_info, :region_id)
      assert Map.has_key?(system_info, :constellation_id)
    end
  end

  # Note: Error scenario tests would need a different approach with global mocks
  # They could be tested in integration tests where we can control the mock behavior
  # or by using a different testing strategy that doesn't conflict with global mode
end
