defmodule WandererApp.Support.FlakyTestDetector do
  @moduledoc """
  Detects and tracks flaky tests in the test suite.

  This module provides:
  - Test result tracking and analysis
  - Flaky test identification based on failure patterns
  - Quarantine system for flaky tests
  - Historical trend analysis
  """

  use GenServer
  require Logger

  # 1% failure rate
  @failure_threshold 0.01
  # Minimum runs before considering a test flaky
  @min_runs 10
  @history_file "test/support/flaky_test_history.json"

  defstruct [
    :test_results,
    :flaky_tests,
    :quarantined_tests,
    :total_runs
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    state = %__MODULE__{
      test_results: %{},
      flaky_tests: MapSet.new(),
      quarantined_tests: MapSet.new(),
      total_runs: 0
    }

    # Load historical data if it exists
    loaded_state = load_historical_data(state)

    {:ok, loaded_state}
  end

  @doc """
  Records a test result for flaky test detection.
  """
  def record_test_result(test_name, result, duration_ms \\ nil) do
    if GenServer.whereis(__MODULE__) do
      GenServer.cast(
        __MODULE__,
        {:record_test_result, test_name, result, duration_ms, DateTime.utc_now()}
      )
    end
  end

  @doc """
  Checks if a test is currently quarantined.
  """
  def is_quarantined?(test_name) do
    if GenServer.whereis(__MODULE__) do
      GenServer.call(__MODULE__, {:is_quarantined, test_name})
    else
      false
    end
  end

  @doc """
  Gets the current list of flaky tests.
  """
  def get_flaky_tests do
    if GenServer.whereis(__MODULE__) do
      GenServer.call(__MODULE__, :get_flaky_tests)
    else
      []
    end
  end

  @doc """
  Quarantines a test manually.
  """
  def quarantine_test(test_name, reason \\ "manually quarantined") do
    if GenServer.whereis(__MODULE__) do
      GenServer.cast(__MODULE__, {:quarantine_test, test_name, reason})
    end
  end

  @doc """
  Removes a test from quarantine.
  """
  def unquarantine_test(test_name) do
    if GenServer.whereis(__MODULE__) do
      GenServer.cast(__MODULE__, {:unquarantine_test, test_name})
    end
  end

  @doc """
  Generates a report of flaky tests and their statistics.
  """
  def generate_report do
    if GenServer.whereis(__MODULE__) do
      GenServer.call(__MODULE__, :generate_report)
    else
      %{error: "Flaky test detector not running"}
    end
  end

  @doc """
  Saves current state to persistent storage.
  """
  def save_state do
    if GenServer.whereis(__MODULE__) do
      GenServer.cast(__MODULE__, :save_state)
    end
  end

  # GenServer callbacks

  def handle_cast({:record_test_result, test_name, result, duration_ms, timestamp}, state) do
    # Record the test result
    test_results =
      Map.update(state.test_results, test_name, [], fn existing ->
        new_result = %{
          result: result,
          duration_ms: duration_ms,
          timestamp: timestamp
        }

        # Keep only the last 100 results per test
        [new_result | existing] |> Enum.take(100)
      end)

    new_state = %{state | test_results: test_results, total_runs: state.total_runs + 1}

    # Analyze for flaky patterns
    new_state = analyze_flaky_patterns(new_state, test_name)

    {:noreply, new_state}
  end

  def handle_cast({:quarantine_test, test_name, reason}, state) do
    Logger.warn("Quarantining flaky test: #{test_name} (#{reason})")

    quarantined_tests = MapSet.put(state.quarantined_tests, test_name)
    new_state = %{state | quarantined_tests: quarantined_tests}

    {:noreply, new_state}
  end

  def handle_cast({:unquarantine_test, test_name}, state) do
    Logger.info("Removing test from quarantine: #{test_name}")

    quarantined_tests = MapSet.delete(state.quarantined_tests, test_name)
    new_state = %{state | quarantined_tests: quarantined_tests}

    {:noreply, new_state}
  end

  def handle_cast(:save_state, state) do
    persist_state(state)
    {:noreply, state}
  end

  def handle_call({:is_quarantined, test_name}, _from, state) do
    result = MapSet.member?(state.quarantined_tests, test_name)
    {:reply, result, state}
  end

  def handle_call(:get_flaky_tests, _from, state) do
    flaky_list = MapSet.to_list(state.flaky_tests)
    {:reply, flaky_list, state}
  end

  def handle_call(:generate_report, _from, state) do
    report = generate_detailed_report(state)
    {:reply, report, state}
  end

  # Private helper functions

  defp analyze_flaky_patterns(state, test_name) do
    case Map.get(state.test_results, test_name, []) do
      results when length(results) >= @min_runs ->
        failure_rate = calculate_failure_rate(results)

        cond do
          failure_rate > @failure_threshold ->
            # Test is flaky
            flaky_tests = MapSet.put(state.flaky_tests, test_name)

            # Auto-quarantine if failure rate is very high
            # 10% failure rate
            quarantined_tests =
              if failure_rate > 0.1 do
                Logger.warn(
                  "Auto-quarantining highly flaky test: #{test_name} (failure rate: #{Float.round(failure_rate * 100, 2)}%)"
                )

                MapSet.put(state.quarantined_tests, test_name)
              else
                state.quarantined_tests
              end

            %{state | flaky_tests: flaky_tests, quarantined_tests: quarantined_tests}

          failure_rate < @failure_threshold / 2 ->
            # Test is stable again, remove from flaky list
            flaky_tests = MapSet.delete(state.flaky_tests, test_name)
            %{state | flaky_tests: flaky_tests}

          true ->
            # Test is borderline, keep current status
            state
        end

      _ ->
        # Not enough data yet
        state
    end
  end

  defp calculate_failure_rate(results) do
    total = length(results)
    failures = Enum.count(results, fn %{result: result} -> result in [:failed, :error] end)
    failures / total
  end

  defp generate_detailed_report(state) do
    flaky_tests_with_stats =
      Enum.map(state.flaky_tests, fn test_name ->
        results = Map.get(state.test_results, test_name, [])
        failure_rate = calculate_failure_rate(results)
        avg_duration = calculate_average_duration(results)
        last_failure = get_last_failure(results)

        %{
          test_name: test_name,
          failure_rate: Float.round(failure_rate * 100, 2),
          total_runs: length(results),
          avg_duration_ms: avg_duration,
          last_failure: last_failure,
          quarantined: MapSet.member?(state.quarantined_tests, test_name)
        }
      end)
      |> Enum.sort_by(& &1.failure_rate, :desc)

    %{
      flaky_tests: flaky_tests_with_stats,
      quarantined_tests: MapSet.to_list(state.quarantined_tests),
      total_tests_analyzed: map_size(state.test_results),
      total_runs: state.total_runs,
      report_generated_at: DateTime.utc_now()
    }
  end

  defp calculate_average_duration(results) do
    durations = Enum.map(results, & &1.duration_ms) |> Enum.reject(&is_nil/1)

    if length(durations) > 0 do
      (Enum.sum(durations) / length(durations)) |> Float.round(2)
    else
      nil
    end
  end

  defp get_last_failure(results) do
    Enum.find(results, fn %{result: result} -> result in [:failed, :error] end)
    |> case do
      %{timestamp: timestamp} -> timestamp
      nil -> nil
    end
  end

  defp load_historical_data(state) do
    case File.read(@history_file) do
      {:ok, content} ->
        try do
          data = Jason.decode!(content, keys: :atoms)

          %{
            state
            | test_results: data.test_results || %{},
              flaky_tests: MapSet.new(data.flaky_tests || []),
              quarantined_tests: MapSet.new(data.quarantined_tests || []),
              total_runs: data.total_runs || 0
          }
        rescue
          _ -> state
        end

      {:error, :enoent} ->
        state

      {:error, _} ->
        state
    end
  end

  defp persist_state(state) do
    data = %{
      test_results: state.test_results,
      flaky_tests: MapSet.to_list(state.flaky_tests),
      quarantined_tests: MapSet.to_list(state.quarantined_tests),
      total_runs: state.total_runs,
      last_updated: DateTime.utc_now()
    }

    # Ensure directory exists
    @history_file |> Path.dirname() |> File.mkdir_p()

    case Jason.encode(data, pretty: true) do
      {:ok, json} -> File.write(@history_file, json)
      {:error, _} -> :error
    end
  end
end
