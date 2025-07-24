defmodule WandererApp.TestHelpers do
  @moduledoc """
  Common test utilities and helpers for the test suite.
  """

  import ExUnit.Assertions

  @doc """
  Converts string keys to atom keys in a map, recursively.
  Useful for comparing API responses with expected data.
  """
  def atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {atomize_key(k), atomize_keys(v)} end)
  end

  def atomize_keys(list) when is_list(list) do
    Enum.map(list, &atomize_keys/1)
  end

  def atomize_keys(value), do: value

  defp atomize_key(key) when is_binary(key), do: String.to_atom(key)
  defp atomize_key(key) when is_atom(key), do: key

  @doc """
  Asserts that a map contains all expected key-value pairs.
  Useful for partial matching of API responses.
  """
  def assert_maps_equal(actual, expected, message \\ nil) do
    missing_keys = Map.keys(expected) -- Map.keys(actual)

    if missing_keys != [] do
      flunk(
        message ||
          "Expected map to contain keys #{inspect(missing_keys)}, but they were missing. Actual: #{inspect(actual)}"
      )
    end

    Enum.each(expected, fn {key, expected_value} ->
      actual_value = Map.get(actual, key)

      assert actual_value == expected_value,
             message ||
               "Expected #{inspect(key)} to be #{inspect(expected_value)}, got #{inspect(actual_value)}"
    end)
  end

  @doc """
  Asserts that a list contains items that match the given criteria.
  """
  def assert_list_contains(list, matcher) when is_function(matcher) do
    found = Enum.any?(list, matcher)

    assert found,
           "Expected list to contain an item matching the criteria, but none found. List: #{inspect(list)}"
  end

  def assert_list_contains(list, expected_item) do
    assert expected_item in list,
           "Expected list to contain #{inspect(expected_item)}, but it was not found. List: #{inspect(list)}"
  end

  @doc """
  Asserts that a value is within a tolerance of an expected value.
  Useful for testing timestamps or floating point values.
  """
  def assert_within_tolerance(actual, expected, tolerance)
      when is_number(actual) and is_number(expected) do
    diff = abs(actual - expected)

    assert diff <= tolerance,
           "Expected #{actual} to be within #{tolerance} of #{expected}, but difference was #{diff}"
  end

  @doc """
  Asserts that a DateTime is recent (within the last few seconds).
  """
  def assert_recent_datetime(datetime, seconds_ago \\ 10)

  def assert_recent_datetime(%DateTime{} = datetime, seconds_ago) do
    now = DateTime.utc_now()
    min_time = DateTime.add(now, -seconds_ago, :second)

    assert DateTime.compare(datetime, min_time) != :lt,
           "Expected #{datetime} to be within the last #{seconds_ago} seconds, but it was too old"
  end

  def assert_recent_datetime(%NaiveDateTime{} = naive_datetime, seconds_ago) do
    datetime = DateTime.from_naive!(naive_datetime, "Etc/UTC")
    assert_recent_datetime(datetime, seconds_ago)
  end

  @doc """
  Retries a function until it succeeds or times out.
  Useful for testing eventual consistency or async operations.
  """
  def eventually(fun, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)
    interval = Keyword.get(opts, :interval, 100)
    end_time = System.monotonic_time(:millisecond) + timeout

    do_eventually(fun, end_time, interval)
  end

  defp do_eventually(fun, end_time, interval) do
    try do
      fun.()
    rescue
      _ ->
        if System.monotonic_time(:millisecond) < end_time do
          :timer.sleep(interval)
          do_eventually(fun, end_time, interval)
        else
          # Let it fail with the actual error
          fun.()
        end
    end
  end

  @doc """
  Creates a unique test identifier using the current test name and a counter.
  """
  def unique_test_id do
    counter = System.unique_integer([:positive])
    "test_#{counter}"
  end

  @doc """
  Generates a random string of the specified length.
  """
  def random_string(length \\ 10) do
    length
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64()
    |> binary_part(0, length)
  end

  @doc """
  Waits for a GenServer to be available and ready.
  """
  def wait_for_genserver(name, timeout \\ 5000) do
    end_time = System.monotonic_time(:millisecond) + timeout

    do_wait_for_genserver(name, end_time)
  end

  defp do_wait_for_genserver(name, end_time) do
    case GenServer.whereis(name) do
      nil ->
        if System.monotonic_time(:millisecond) < end_time do
          :timer.sleep(100)
          do_wait_for_genserver(name, end_time)
        else
          flunk("GenServer #{name} did not start within timeout")
        end

      pid ->
        pid
    end
  end

  @doc """
  Captures and formats Phoenix logs for test assertions.
  """
  def capture_log(fun) do
    ExUnit.CaptureLog.capture_log(fun)
  end

  @doc """
  Asserts that a log message was captured.
  """
  def assert_logged(log_output, expected_message) do
    assert log_output =~ expected_message,
           "Expected log to contain '#{expected_message}', but got: #{log_output}"
  end

  @doc """
  Ensures a map server is started for testing.
  """
  def ensure_map_server_started(map_id) do
    case WandererApp.Map.Server.map_pid(map_id) do
      pid when is_pid(pid) ->
        # Make sure existing server has database access
        WandererApp.DataCase.allow_database_access(pid)
        # Also allow database access for any spawned processes
        allow_map_server_children_database_access(pid)
        # Ensure global Mox mode is maintained
        if Code.ensure_loaded?(Mox), do: Mox.set_mox_global()
        :ok

      nil ->
        # Ensure global Mox mode before starting map server
        if Code.ensure_loaded?(Mox), do: Mox.set_mox_global()
        # Start the map server directly for tests
        {:ok, pid} = start_map_server_directly(map_id)
        # Grant database access to the new map server process
        WandererApp.DataCase.allow_database_access(pid)
        # Allow database access for any spawned processes
        allow_map_server_children_database_access(pid)
        :ok
    end
  end

  defp start_map_server_directly(map_id) do
    # Use the same approach as MapManager.start_map_server/1
    case DynamicSupervisor.start_child(
           {:via, PartitionSupervisor, {WandererApp.Map.DynamicSupervisors, self()}},
           {WandererApp.Map.ServerSupervisor, map_id: map_id}
         ) do
      {:ok, pid} ->
        # Allow database access for the supervisor and its children
        WandererApp.DataCase.allow_genserver_database_access(pid)

        # Allow Mox access for the supervisor process if in test mode
        WandererApp.Test.MockAllowance.setup_genserver_mocks(pid)

        # Also get the actual map server pid and allow access
        case WandererApp.Map.Server.map_pid(map_id) do
          server_pid when is_pid(server_pid) ->
            WandererApp.DataCase.allow_genserver_database_access(server_pid)

            # Allow Mox access for the map server process if in test mode
            WandererApp.Test.MockAllowance.setup_genserver_mocks(server_pid)

          _ ->
            :ok
        end

        {:ok, pid}

      {:error, {:already_started, pid}} ->
        WandererApp.DataCase.allow_database_access(pid)
        {:ok, pid}

      {:error, :max_children} ->
        # If we hit max children, wait a bit and retry
        :timer.sleep(100)
        start_map_server_directly(map_id)

      error ->
        error
    end
  end

  defp allow_map_server_children_database_access(map_server_pid) do
    # Allow database access for all children processes
    # This is important for MapEventRelay and other spawned processes

    # Wait a bit for children to spawn
    :timer.sleep(100)

    # Get all linked processes
    case Process.info(map_server_pid, :links) do
      {:links, linked_pids} ->
        Enum.each(linked_pids, fn linked_pid ->
          if is_pid(linked_pid) and Process.alive?(linked_pid) do
            WandererApp.DataCase.allow_database_access(linked_pid)

            # Also check for their children
            case Process.info(linked_pid, :links) do
              {:links, sub_links} ->
                Enum.each(sub_links, fn sub_pid ->
                  if is_pid(sub_pid) and Process.alive?(sub_pid) and sub_pid != map_server_pid do
                    WandererApp.DataCase.allow_database_access(sub_pid)
                  end
                end)

              _ ->
                :ok
            end
          end
        end)

      _ ->
        :ok
    end
  end
end
