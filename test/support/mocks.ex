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

    # Note: We don't call set_mox_global() here because the caller should handle that
    # This allows the function to be called from different contexts without ownership issues

    # Set up default stubs for logger mock (these methods are called during application startup)
    Test.LoggerMock
    |> Mox.stub(:info, fn _message -> :ok end)
    |> Mox.stub(:warning, fn _message -> :ok end)
    |> Mox.stub(:error, fn _message -> :ok end)
    |> Mox.stub(:debug, fn _message -> :ok end)

    # Make mocks available to any spawned process
    :persistent_term.put({Test.LoggerMock, :global_mode}, true)
    :persistent_term.put({Test.PubSubMock, :global_mode}, true)
    :persistent_term.put({Test.SpatialIndexMock, :global_mode}, true)

    # Set up default stubs for PubSub mock
    Test.PubSubMock
    |> Mox.stub(:broadcast, fn _server, _topic, _message -> :ok end)
    |> Mox.stub(:broadcast!, fn _server, _topic, _message -> :ok end)
    |> Mox.stub(:subscribe, fn _topic -> :ok end)
    |> Mox.stub(:subscribe, fn _module, _topic -> :ok end)
    |> Mox.stub(:unsubscribe, fn _topic -> :ok end)

    # Set up default stubs for SpatialIndex mock (matching CacheRTree return values)
    Test.SpatialIndexMock
    |> Mox.stub(:insert, fn _data, _tree_name -> {:ok, %{}} end)
    |> Mox.stub(:update, fn _id, _data, _tree_name -> {:ok, %{}} end)
    |> Mox.stub(:delete, fn _id_or_ids, _tree_name -> {:ok, %{}} end)
    |> Mox.stub(:query, fn _box, _tree_name -> {:ok, []} end)

    # Set up default stubs for CachedInfo mock
    WandererApp.CachedInfo.Mock
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

      30_002_187 ->
        {:ok,
         %{
           solar_system_id: 30_002_187,
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

      30_002_659 ->
        {:ok,
         %{
           solar_system_id: 30_002_659,
           region_id: 10_000_032,
           constellation_id: 20_000_456,
           solar_system_name: "Dodixie",
           solar_system_name_lc: "dodixie",
           constellation_name: "Sinq Laison",
           region_name: "Sinq Laison",
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

      30_002_510 ->
        {:ok,
         %{
           solar_system_id: 30_002_510,
           region_id: 10_000_030,
           constellation_id: 20_000_387,
           solar_system_name: "Rens",
           solar_system_name_lc: "rens",
           constellation_name: "Frarn",
           region_name: "Heimatar",
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
    try do
      Mox.set_mox_global()
    rescue
      # Already in global mode, that's fine
      _ -> :ok
    end

    :ok
  end
end
