defmodule WandererApp.TestMonitor do
  @moduledoc """
  Monitors test execution to track flaky tests and performance issues.

  This module integrates with ExUnit to collect metrics about test execution,
  including timing, failure patterns, and flakiness detection.
  """

  use GenServer
  require Logger

  # Test is flaky if it fails more than 5% of the time
  @flaky_threshold 0.95
  # Test is slow if it takes more than 1 second
  @slow_test_threshold 1000
  @history_file "test_history.json"

  defmodule TestResult do
    defstruct [:module, :test, :status, :duration, :timestamp, :failure_reason]
  end

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def record_test(module, test, status, duration, failure_reason \\ nil) do
    GenServer.cast(
      __MODULE__,
      {:record_test,
       %TestResult{
         module: module,
         test: test,
         status: status,
         duration: duration,
         timestamp: DateTime.utc_now(),
         failure_reason: failure_reason
       }}
    )
  end

  def get_flaky_tests do
    GenServer.call(__MODULE__, :get_flaky_tests)
  end

  def get_slow_tests do
    GenServer.call(__MODULE__, :get_slow_tests)
  end

  def generate_report do
    GenServer.call(__MODULE__, :generate_report)
  end

  def save_history do
    GenServer.call(__MODULE__, :save_history)
  end

  ## Server Callbacks

  def init(_opts) do
    # Load historical data
    history = load_history()

    state = %{
      current_run: [],
      history: history,
      flaky_tests: identify_flaky_tests(history),
      slow_tests: identify_slow_tests(history)
    }

    # Schedule periodic saves
    Process.send_after(self(), :save_history, 60_000)

    {:ok, state}
  end

  def handle_cast({:record_test, result}, state) do
    updated_state = %{
      state
      | current_run: [result | state.current_run],
        history: [result | state.history]
    }

    # Update flaky test detection
    if result.status == :failed do
      updated_state = update_flaky_detection(updated_state, result)
    end

    # Update slow test detection
    if result.duration > @slow_test_threshold do
      updated_state = update_slow_detection(updated_state, result)
    end

    {:noreply, updated_state}
  end

  def handle_call(:get_flaky_tests, _from, state) do
    {:reply, state.flaky_tests, state}
  end

  def handle_call(:get_slow_tests, _from, state) do
    {:reply, state.slow_tests, state}
  end

  def handle_call(:generate_report, _from, state) do
    report = build_report(state)
    {:reply, report, state}
  end

  def handle_call(:save_history, _from, state) do
    save_history_to_file(state.history)
    {:reply, :ok, state}
  end

  def handle_info(:save_history, state) do
    save_history_to_file(state.history)
    Process.send_after(self(), :save_history, 60_000)
    {:noreply, state}
  end

  ## Private Functions

  defp load_history do
    case File.read(@history_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} ->
            Enum.map(data, &decode_test_result/1)

          {:error, _} ->
            []
        end

      {:error, _} ->
        []
    end
  end

  defp save_history_to_file(history) do
    # Keep only last 30 days of history
    cutoff = DateTime.add(DateTime.utc_now(), -30, :day)

    recent_history =
      history
      |> Enum.filter(fn result ->
        DateTime.compare(result.timestamp, cutoff) == :gt
      end)

    json_data = Enum.map(recent_history, &encode_test_result/1)
    json = Jason.encode!(json_data, pretty: true)

    File.write!(@history_file, json)
  end

  defp decode_test_result(data) do
    %TestResult{
      module: data["module"],
      test: data["test"],
      status: String.to_atom(data["status"]),
      duration: data["duration"],
      timestamp: elem(DateTime.from_iso8601(data["timestamp"]), 1),
      failure_reason: data["failure_reason"]
    }
  end

  defp encode_test_result(result) do
    %{
      "module" => result.module,
      "test" => result.test,
      "status" => to_string(result.status),
      "duration" => result.duration,
      "timestamp" => DateTime.to_iso8601(result.timestamp),
      "failure_reason" => result.failure_reason
    }
  end

  defp identify_flaky_tests(history) do
    history
    |> Enum.group_by(fn r -> {r.module, r.test} end)
    |> Enum.map(fn {{module, test}, results} ->
      total = length(results)
      failures = Enum.count(results, &(&1.status == :failed))
      success_rate = if total > 0, do: (total - failures) / total, else: 0

      %{
        module: module,
        test: test,
        total_runs: total,
        failures: failures,
        success_rate: success_rate,
        is_flaky: success_rate < @flaky_threshold && success_rate > 0,
        recent_failures: get_recent_failures(results)
      }
    end)
    |> Enum.filter(& &1.is_flaky)
    |> Enum.sort_by(& &1.success_rate)
  end

  defp identify_slow_tests(history) do
    history
    |> Enum.group_by(fn r -> {r.module, r.test} end)
    |> Enum.map(fn {{module, test}, results} ->
      durations = Enum.map(results, & &1.duration)

      %{
        module: module,
        test: test,
        avg_duration: average(durations),
        max_duration: Enum.max(durations),
        min_duration: Enum.min(durations),
        run_count: length(results),
        is_slow: average(durations) > @slow_test_threshold
      }
    end)
    |> Enum.filter(& &1.is_slow)
    |> Enum.sort_by(& &1.avg_duration, :desc)
  end

  defp get_recent_failures(results) do
    results
    |> Enum.filter(&(&1.status == :failed))
    |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
    |> Enum.take(5)
    |> Enum.map(fn r ->
      %{
        timestamp: r.timestamp,
        reason: r.failure_reason
      }
    end)
  end

  defp update_flaky_detection(state, failed_result) do
    test_key = {failed_result.module, failed_result.test}

    # Check recent history for this test
    recent_results =
      state.history
      |> Enum.filter(fn r ->
        {r.module, r.test} == test_key &&
          DateTime.diff(DateTime.utc_now(), r.timestamp, :hour) < 24
      end)

    if length(recent_results) >= 3 do
      failures = Enum.count(recent_results, &(&1.status == :failed))
      success_rate = (length(recent_results) - failures) / length(recent_results)

      if success_rate < @flaky_threshold && success_rate > 0 do
        Logger.warning("Flaky test detected: #{failed_result.module}.#{failed_result.test}")
      end
    end

    %{state | flaky_tests: identify_flaky_tests(state.history)}
  end

  defp update_slow_detection(state, slow_result) do
    Logger.info(
      "Slow test detected: #{slow_result.module}.#{slow_result.test} took #{slow_result.duration}ms"
    )

    %{state | slow_tests: identify_slow_tests(state.history)}
  end

  defp build_report(state) do
    %{
      timestamp: DateTime.utc_now(),
      current_run_stats: build_current_run_stats(state.current_run),
      flaky_tests: state.flaky_tests,
      slow_tests: Enum.take(state.slow_tests, 10),
      historical_stats: build_historical_stats(state.history)
    }
  end

  defp build_current_run_stats(current_run) do
    total = length(current_run)
    failures = Enum.count(current_run, &(&1.status == :failed))

    %{
      total_tests: total,
      passed: total - failures,
      failed: failures,
      success_rate: if(total > 0, do: (total - failures) / total, else: 0),
      avg_duration: average(Enum.map(current_run, & &1.duration)),
      total_duration: Enum.sum(Enum.map(current_run, & &1.duration))
    }
  end

  defp build_historical_stats(history) do
    # Group by day
    by_day =
      history
      |> Enum.group_by(fn r ->
        DateTime.to_date(r.timestamp)
      end)
      |> Enum.map(fn {date, results} ->
        total = length(results)
        failures = Enum.count(results, &(&1.status == :failed))

        %{
          date: date,
          total_tests: total,
          failures: failures,
          success_rate: if(total > 0, do: (total - failures) / total, else: 0)
        }
      end)
      |> Enum.sort_by(& &1.date, {:desc, Date})
      |> Enum.take(7)

    %{
      last_7_days: by_day,
      total_historical_runs: length(history)
    }
  end

  defp average([]), do: 0
  defp average(list), do: Enum.sum(list) / length(list)
end

defmodule WandererApp.TestMonitor.ExUnitFormatter do
  @moduledoc """
  Custom ExUnit formatter that integrates with TestMonitor.
  """

  use GenEvent

  def init(_opts) do
    {:ok, %{}}
  end

  def handle_event({:test_finished, %ExUnit.Test{} = test}, state) do
    duration = System.convert_time_unit(test.time, :native, :millisecond)

    status =
      case test.state do
        nil -> :passed
        {:failed, _} -> :failed
        {:skipped, _} -> :skipped
        {:excluded, _} -> :excluded
        _ -> :unknown
      end

    failure_reason =
      case test.state do
        {:failed, failures} ->
          failures
          |> Enum.map(&format_failure/1)
          |> Enum.join("\n")

        _ ->
          nil
      end

    WandererApp.TestMonitor.record_test(
      inspect(test.module),
      to_string(test.name),
      status,
      duration,
      failure_reason
    )

    {:ok, state}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  defp format_failure({:error, %ExUnit.AssertionError{} = error, _stack}) do
    ExUnit.Formatter.format_assertion_error(error)
  end

  defp format_failure({:error, error, _stack}) do
    inspect(error)
  end

  defp format_failure(other) do
    inspect(other)
  end
end
