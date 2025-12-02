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
  Waits for a condition to become true, with configurable timeout and interval.
  More efficient than fixed sleeps - uses small polling intervals.

  ## Options
    * `:timeout` - Maximum time to wait in milliseconds (default: 5000)
    * `:interval` - Polling interval in milliseconds (default: 10)

  ## Examples
      wait_until(fn -> Process.whereis(:my_server) != nil end)
      wait_until(fn -> cache_has_value?() end, timeout: 2000, interval: 5)
  """
  def wait_until(condition_fn, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)
    interval = Keyword.get(opts, :interval, 10)
    deadline = System.monotonic_time(:millisecond) + timeout

    do_wait_until(condition_fn, deadline, interval)
  end

  defp do_wait_until(condition_fn, deadline, interval) do
    if condition_fn.() do
      :ok
    else
      if System.monotonic_time(:millisecond) < deadline do
        Process.sleep(interval)
        do_wait_until(condition_fn, deadline, interval)
      else
        {:error, :timeout}
      end
    end
  end

  @doc """
  Ensures a map server is started for testing.
  This function has been simplified to use the standard map startup flow.
  For integration tests, use WandererApp.MapTestHelpers.ensure_map_started/1 instead.
  """
  def ensure_map_server_started(map_id) do
    # Use the standard map startup flow through Map.Manager
    :ok = WandererApp.Map.Manager.start_map(map_id)

    # Wait for the map to be in started_maps cache with efficient polling
    wait_until(
      fn ->
        case WandererApp.Cache.lookup("map_#{map_id}:started") do
          {:ok, true} -> true
          _ -> false
        end
      end,
      timeout: 5000,
      interval: 20
    )

    :ok
  end

  @doc """
  Ensures map server is started and has proper mock/database access.
  Use this in tests that need to interact with map servers.

  Note: Map servers started through MapPoolSupervisor automatically get
  database and mock access via the DataCase setup. This function is here
  for compatibility and will ensure the server is started.
  """
  def ensure_map_server_with_access(map_id, _owner_pid \\ self()) do
    # Start the server - it will automatically get access through MapPoolSupervisor
    ensure_map_server_started(map_id)
    :ok
  end
end
