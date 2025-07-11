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
    test_name = ExUnit.current_context()[:test] || :unknown_test
    counter = System.unique_integer([:positive])
    "#{test_name}_#{counter}"
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
end
