defmodule WandererApp.Test.Mocks do
  @moduledoc """
  Mock definitions for testing.
  Uses private mode for async test support.
  Each test must call setup_test_mocks() in their setup block.
  """

  @doc """
  Sets up mocks for the current test process.
  Call this in your test setup block to claim mock ownership and set up default stubs.

  ## Examples

      setup do
        WandererApp.Test.Mocks.setup_test_mocks()
        :ok
      end
  """
  def setup_test_mocks(opts \\ []) do
    # For integration tests that spawn processes (MapPool, etc.),
    # we need global mode so mocks work across process boundaries
    mode = Keyword.get(opts, :mode, :private)

    case mode do
      :global -> Mox.set_mox_global()
      :private -> Mox.set_mox_private()
    end

    # Set up default stubs for this test
    setup_default_stubs()

    :ok
  end

  defp setup_default_stubs do
    # Set up default stubs for logger mock (these methods are called during application startup)
    # Support both 1-arity (message only) and 2-arity (message + metadata) versions
    Mox.stub(Test.LoggerMock, :info, fn _message -> :ok end)
    Mox.stub(Test.LoggerMock, :info, fn _message, _metadata -> :ok end)
    Mox.stub(Test.LoggerMock, :warning, fn _message -> :ok end)
    Mox.stub(Test.LoggerMock, :warning, fn _message, _metadata -> :ok end)
    Mox.stub(Test.LoggerMock, :error, fn _message -> :ok end)
    Mox.stub(Test.LoggerMock, :error, fn _message, _metadata -> :ok end)
    Mox.stub(Test.LoggerMock, :debug, fn _message -> :ok end)
    Mox.stub(Test.LoggerMock, :debug, fn _message, _metadata -> :ok end)

    # Set up default stubs for PubSub mock
    Test.PubSubMock
    |> Mox.stub(:broadcast, fn _server, _topic, _message -> :ok end)
    |> Mox.stub(:broadcast!, fn _server, _topic, _message -> :ok end)
    |> Mox.stub(:subscribe, fn _topic -> :ok end)
    |> Mox.stub(:subscribe, fn _module, _topic -> :ok end)
    |> Mox.stub(:unsubscribe, fn _topic -> :ok end)
    |> Mox.stub(:unsubscribe, fn _server, _topic -> :ok end)

    # Set up default stubs for DDRT mock
    Test.DDRTMock
    |> Mox.stub(:init_tree, fn _tree_name, _opts -> :ok end)
    |> Mox.stub(:insert, fn _data, _tree_name -> {:ok, %{}} end)
    |> Mox.stub(:update, fn _id, _data, _tree_name -> {:ok, %{}} end)
    |> Mox.stub(:delete, fn _ids, _tree_name -> {:ok, %{}} end)
    |> Mox.stub(:query, fn _bbox, _tree_name -> {:ok, []} end)

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
end
