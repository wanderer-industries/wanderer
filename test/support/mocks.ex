defmodule WandererApp.Test.Mocks do
  @moduledoc """
  Mock definitions for testing.
  These mocks are defined early in the test boot process to be available
  when the application starts.
  """

  # Ensure Mox is started
  Application.ensure_all_started(:mox)

  # Define mocks for external dependencies
  Mox.defmock(Test.PubSubMock, for: WandererApp.Test.PubSub)
  Mox.defmock(Test.LoggerMock, for: WandererApp.Test.Logger)
  Mox.defmock(Test.DDRTMock, for: WandererApp.Test.DDRT)

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
  :persistent_term.put({Test.PubSubMock, :global_mode}, true)
  :persistent_term.put({Test.DDRTMock, :global_mode}, true)

  # Set up default stubs for PubSub mock
  Test.PubSubMock
  |> Mox.stub(:broadcast, fn _server, _topic, _message -> :ok end)
  |> Mox.stub(:broadcast!, fn _server, _topic, _message -> :ok end)
  |> Mox.stub(:subscribe, fn _topic -> :ok end)
  |> Mox.stub(:subscribe, fn _module, _topic -> :ok end)
  |> Mox.stub(:unsubscribe, fn _topic -> :ok end)

  # Set up default stubs for DDRT mock
  Test.DDRTMock
  |> Mox.stub(:insert, fn _data, _tree_name -> :ok end)
  |> Mox.stub(:update, fn _id, _data, _tree_name -> :ok end)
  |> Mox.stub(:delete, fn _ids, _tree_name -> :ok end)

  @doc """
  Sets up the basic mocks needed for application startup.
  This function can be called during application startup in test environment.
  """
  def setup_mocks do
    # Ensure Mox is started
    Application.ensure_all_started(:mox)

    # Define mocks for external dependencies
    Mox.defmock(Test.PubSubMock, for: WandererApp.Test.PubSub)
    Mox.defmock(Test.LoggerMock, for: WandererApp.Test.Logger)
    Mox.defmock(Test.DDRTMock, for: WandererApp.Test.DDRT)

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
    :persistent_term.put({Test.PubSubMock, :global_mode}, true)
    :persistent_term.put({Test.DDRTMock, :global_mode}, true)

    # Set up default stubs for PubSub mock
    Test.PubSubMock
    |> Mox.stub(:broadcast, fn _server, _topic, _message -> :ok end)
    |> Mox.stub(:broadcast!, fn _server, _topic, _message -> :ok end)
    |> Mox.stub(:subscribe, fn _topic -> :ok end)
    |> Mox.stub(:subscribe, fn _module, _topic -> :ok end)
    |> Mox.stub(:unsubscribe, fn _topic -> :ok end)

    # Set up default stubs for DDRT mock
    Test.DDRTMock
    |> Mox.stub(:insert, fn _data, _tree_name -> :ok end)
    |> Mox.stub(:update, fn _id, _data, _tree_name -> :ok end)
    |> Mox.stub(:delete, fn _ids, _tree_name -> :ok end)

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
