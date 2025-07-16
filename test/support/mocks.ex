defmodule WandererApp.Test.Mocks do
  @moduledoc """
  Mock definitions for testing.
  These mocks are defined early in the test boot process to be available
  when the application starts.
  """

  @doc """
  Sets up the basic mocks needed for application startup.
  This function can be called during application startup in test environment.
  """
  def setup_mocks do
    # Ensure Mox is started
    Application.ensure_all_started(:mox)

    # Mocks are already defined in mock_definitions.ex
    # Here we just set up stubs for them

    # Set global mode for the mocks to avoid ownership issues during application startup
    Mox.set_mox_global()

    # Set up default stubs for logger mock (these methods are called during application startup)
    Test.LoggerMock
    |> Mox.stub(:info, fn _message -> :ok end)
    |> Mox.stub(:warning, fn _message -> :ok end)
    |> Mox.stub(:error, fn _message -> :ok end)
    |> Mox.stub(:debug, fn _message -> :ok end)

    # Make mocks available to any spawned process
    :persistent_term.put({Test.LoggerMock, :global_mode}, true)
    :persistent_term.put({Test.DDRTMock, :global_mode}, true)

    # Note: PubSub now uses real Phoenix.PubSub for integration tests

    # Set up default stubs for DDRT mock
    Test.DDRTMock
    |> Mox.stub(:insert, fn _data, _tree_name -> :ok end)
    |> Mox.stub(:update, fn _id, _data, _tree_name -> :ok end)
    |> Mox.stub(:delete, fn _ids, _tree_name -> :ok end)
    |> Mox.stub(:search, fn _query, _tree_name -> [] end)

    # Set up default stubs for CachedInfo mock
    WandererApp.CachedInfo.Mock
    |> Mox.stub(:get_server_status, fn ->
      {:ok,
       %{
         "players" => 12_345,
         "server_version" => "2171975",
         "start_time" => ~U[2025-07-15 11:05:35Z],
         "vip" => false
       }}
    end)
    |> Mox.stub(:get_character_info, fn character_id ->
      {:ok,
       %{
         "character_id" => character_id,
         "name" => "Test Character #{character_id}",
         "corporation_id" => 1_000_001,
         "alliance_id" => 500_001,
         "security_status" => 0.0
       }}
    end)
    |> Mox.stub(:get_character_location, fn _character_id ->
      {:ok,
       %{
         "solar_system_id" => 30_000_142,
         "station_id" => 60_003_760
       }}
    end)
    |> Mox.stub(:get_character_ship, fn _character_id ->
      {:ok,
       %{
         "ship_item_id" => 1_000_000_016_991,
         "ship_name" => "Test Ship",
         "ship_type_id" => 670
       }}
    end)
    |> Mox.stub(:get_ship_type, fn ship_type_id ->
      {:ok,
       %{
         "type_id" => ship_type_id,
         "name" => "Test Ship Type",
         "group_id" => 25
       }}
    end)
    |> Mox.stub(:get_system_static_info, fn
      30_000_142 ->
        {:ok,
         %{
           solar_system_id: 30_000_142,
           region_id: 10_000_002,
           constellation_id: 20_000_020,
           solar_system_name: "Jita",
           solar_system_name_lc: "jita",
           constellation_name: "Kimotoro",
           region_name: "The Forge",
           system_class: 0,
           security: "0.9",
           type_description: "High Security",
           class_title: "High Sec",
           is_shattered: false,
           effect_name: nil,
           effect_power: nil,
           statics: [],
           wandering: [],
           triglavian_invasion_status: nil,
           sun_type_id: 45041
         }}

      30_000_144 ->
        {:ok,
         %{
           solar_system_id: 30_000_144,
           region_id: 10_000_043,
           constellation_id: 20_000_304,
           solar_system_name: "Amarr",
           solar_system_name_lc: "amarr",
           constellation_name: "Throne Worlds",
           region_name: "Domain",
           system_class: 0,
           security: "0.9",
           type_description: "High Security",
           class_title: "High Sec",
           is_shattered: false,
           effect_name: nil,
           effect_power: nil,
           statics: [],
           wandering: [],
           triglavian_invasion_status: nil,
           sun_type_id: 45041
         }}

      _ ->
        {:error, :not_found}
    end)

    :ok
  end

  @doc """
  Sets up additional mock expectations for specific tests.
  Call this in your test setup if you need to override the default stubs.
  """
  def setup_additional_expectations do
    # Reset to global mode in case tests changed it
    Mox.set_mox_global()
    :ok
  end
end
