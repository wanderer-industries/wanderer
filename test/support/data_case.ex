defmodule WandererApp.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use WandererApp.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias WandererApp.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import WandererApp.DataCase

      # Import Ash test helpers
      import WandererAppWeb.Factory

      # Import test utilities
      import WandererApp.TestHelpers
    end
  end

  setup tags do
    WandererApp.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(WandererApp.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  @doc """
  Truncates all tables in the test database.
  Use with caution - this will delete all test data.
  """
  def truncate_all_tables do
    Ecto.Adapters.SQL.query!(
      WandererApp.Repo,
      "TRUNCATE #{tables_to_truncate()} RESTART IDENTITY CASCADE",
      []
    )
  end

  @doc """
  Resets the database to a clean state.
  """
  def reset_database do
    Ecto.Adapters.SQL.Sandbox.restart(WandererApp.Repo)
  end

  @doc """
  Waits for async operations to complete using polling.
  Useful when testing async processes.
  """
  # Backward compatibility - accepts just timeout
  def wait_for_async(timeout) when is_integer(timeout) do
    :timer.sleep(timeout)
  end

  def wait_for_async(condition_fn) when is_function(condition_fn) do
    wait_for_async(condition_fn, 1000)
  end

  def wait_for_async(condition_fn, timeout) when is_function(condition_fn) do
    wait_for_async_poll(condition_fn, timeout, 50)
  end

  defp wait_for_async_poll(condition_fn, timeout, interval) when timeout > 0 do
    if condition_fn.() do
      :ok
    else
      :timer.sleep(interval)
      wait_for_async_poll(condition_fn, timeout - interval, interval)
    end
  end

  defp wait_for_async_poll(_condition_fn, _timeout, _interval) do
    raise "Timeout waiting for async condition"
  end

  @doc """
  Asserts that an Ash action succeeds and returns the result.
  """
  def assert_ash_success({:ok, result}), do: result

  def assert_ash_success({:error, error}) do
    flunk("Expected Ash action to succeed, but got error: #{inspect(error)}")
  end

  @doc """
  Asserts that an Ash action fails with expected error.
  """
  def assert_ash_error({:error, _error} = result), do: result

  def assert_ash_error({:ok, result}) do
    flunk("Expected Ash action to fail, but got success: #{inspect(result)}")
  end

  @doc """
  Asserts that an Ash action fails with a specific error message.
  """
  def assert_ash_error({:error, error}, expected_message) when is_binary(expected_message) do
    error_string = inspect(error)

    assert error_string =~ expected_message,
           "Expected error to contain '#{expected_message}', but got: #{error_string}"

    {:error, error}
  end

  # Private helpers

  defp tables_to_truncate do
    "users, characters, maps, map_systems, map_connections, access_lists, access_list_members"
  end
end
