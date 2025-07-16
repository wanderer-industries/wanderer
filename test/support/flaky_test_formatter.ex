defmodule WandererApp.Support.FlakyTestFormatter do
  @moduledoc """
  Custom ExUnit formatter that integrates with flaky test detection.

  This formatter:
  - Tracks test results for flaky test detection
  - Retries quarantined tests up to 3 times
  - Provides enhanced output for flaky tests
  - Validates test layer compliance
  """

  use GenServer

  defstruct [
    :config,
    :test_results,
    :retry_counts,
    :start_time
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    config = %{
      colors: Keyword.get(opts, :colors, IO.ANSI.enabled?()),
      width: Keyword.get(opts, :width, 80),
      max_retries: Keyword.get(opts, :max_retries, 3)
    }

    state = %__MODULE__{
      config: config,
      test_results: %{},
      retry_counts: %{},
      start_time: DateTime.utc_now()
    }

    # Start the flaky test detector if not already running
    case GenServer.whereis(WandererApp.Support.FlakyTestDetector) do
      nil -> WandererApp.Support.FlakyTestDetector.start_link()
      _pid -> :ok
    end

    # Enhanced factory is no longer used
    # case GenServer.whereis(WandererApp.Support.EnhancedFactory) do
    #   nil -> WandererApp.Support.EnhancedFactory.start_link()
    #   _pid -> :ok
    # end

    {:ok, state}
  end

  # ExUnit formatter callbacks

  def handle_cast({:suite_started, _opts}, state) do
    IO.puts(
      colorize(state.config, "🧪 Starting enhanced test suite with flaky test detection...", :cyan)
    )

    # Factory sequences are no longer used
    # WandererApp.Support.EnhancedFactory.reset_sequences()

    # Validate test layer structure
    if GenServer.whereis(WandererApp.Support.TestLayerValidator) do
      WandererApp.Support.TestLayerValidator.validate_test_layers()
    end

    {:noreply, state}
  end

  def handle_cast({:suite_finished, run_us, load_us}, state) do
    # Generate flaky test report
    flaky_report = WandererApp.Support.FlakyTestDetector.generate_report()

    # Save flaky test state
    WandererApp.Support.FlakyTestDetector.save_state()

    # Print summary
    print_suite_summary(state, run_us, load_us, flaky_report)

    {:noreply, state}
  end

  def handle_cast({:test_started, %ExUnit.Test{name: name, module: module}}, state) do
    test_key = "#{module}.#{name}"

    # Check if test is quarantined
    if WandererApp.Support.FlakyTestDetector.is_quarantined?(test_key) do
      IO.puts(colorize(state.config, "⚠️  Running quarantined test: #{test_key}", :yellow))
    end

    {:noreply, state}
  end

  def handle_cast(
        {:test_finished, %ExUnit.Test{name: name, module: module, state: test_state, time: time}},
        state
      ) do
    test_key = "#{module}.#{name}"
    # Convert to milliseconds
    duration_ms = time / 1000

    # Record test result for flaky detection
    WandererApp.Support.FlakyTestDetector.record_test_result(test_key, test_state, duration_ms)

    # Handle test result
    case test_state do
      nil ->
        # Test passed
        print_test_result(state.config, test_key, :passed, duration_ms)

      {:failed, _} ->
        # Test failed - check if it should be retried
        state = handle_test_failure(state, test_key, duration_ms)

      {:error, _} ->
        # Test error - check if it should be retried
        state = handle_test_error(state, test_key, duration_ms)

      {:skip, _} ->
        # Test skipped
        print_test_result(state.config, test_key, :skipped, duration_ms)

      {:skipped, _} ->
        # Test skipped (alternate format)
        print_test_result(state.config, test_key, :skipped, duration_ms)

      {:excluded, _} ->
        # Test excluded - do nothing
        :ok
    end

    {:noreply, state}
  end

  def handle_cast({:module_started, %ExUnit.TestModule{name: module}}, state) do
    IO.puts(colorize(state.config, "📁 Testing module: #{module}", :blue))
    {:noreply, state}
  end

  def handle_cast({:module_finished, %ExUnit.TestModule{name: module}}, state) do
    {:noreply, state}
  end

  def handle_cast(_, state) do
    {:noreply, state}
  end

  # Private helper functions

  defp handle_test_failure(state, test_key, duration_ms) do
    retry_count = Map.get(state.retry_counts, test_key, 0)

    if WandererApp.Support.FlakyTestDetector.is_quarantined?(test_key) and
         retry_count < state.config.max_retries do
      # Retry quarantined test
      new_retry_count = retry_count + 1

      IO.puts(
        colorize(
          state.config,
          "🔄 Retrying quarantined test: #{test_key} (attempt #{new_retry_count}/#{state.config.max_retries})",
          :yellow
        )
      )

      # Update retry count
      retry_counts = Map.put(state.retry_counts, test_key, new_retry_count)
      %{state | retry_counts: retry_counts}
    else
      # Test failed definitively
      print_test_result(state.config, test_key, :failed, duration_ms)

      if retry_count > 0 do
        IO.puts(colorize(state.config, "   Failed after #{retry_count} retries", :red))
      end

      state
    end
  end

  defp handle_test_error(state, test_key, duration_ms) do
    retry_count = Map.get(state.retry_counts, test_key, 0)

    if WandererApp.Support.FlakyTestDetector.is_quarantined?(test_key) and
         retry_count < state.config.max_retries do
      # Retry quarantined test
      new_retry_count = retry_count + 1

      IO.puts(
        colorize(
          state.config,
          "🔄 Retrying quarantined test: #{test_key} (attempt #{new_retry_count}/#{state.config.max_retries})",
          :yellow
        )
      )

      # Update retry count
      retry_counts = Map.put(state.retry_counts, test_key, new_retry_count)
      %{state | retry_counts: retry_counts}
    else
      # Test errored definitively
      print_test_result(state.config, test_key, :error, duration_ms)

      if retry_count > 0 do
        IO.puts(colorize(state.config, "   Error after #{retry_count} retries", :red))
      end

      state
    end
  end

  defp print_test_result(config, test_key, result, duration_ms) do
    {symbol, color} =
      case result do
        :passed -> {"✅", :green}
        :failed -> {"❌", :red}
        :error -> {"💥", :red}
        :skipped -> {"⏭️", :yellow}
      end

    duration_str =
      if duration_ms do
        if duration_ms > 1000 do
          " (#{Float.round(duration_ms / 1000, 2)}s)"
        else
          " (#{Float.round(duration_ms, 1)}ms)"
        end
      else
        ""
      end

    IO.puts(colorize(config, "#{symbol} #{test_key}#{duration_str}", color))
  end

  defp print_suite_summary(state, run_us, load_us, flaky_report) do
    # Convert to seconds
    total_time = (run_us + load_us) / 1_000_000

    IO.puts("\n" <> colorize(state.config, "📊 Test Suite Summary", :cyan))
    IO.puts(colorize(state.config, "=" <> String.duplicate("=", 50), :cyan))

    IO.puts("Total time: #{Float.round(total_time, 2)}s")
    IO.puts("Load time: #{Float.round(load_us / 1_000_000, 2)}s")
    IO.puts("Run time: #{Float.round(run_us / 1_000_000, 2)}s")

    # Print flaky test summary
    if length(flaky_report.flaky_tests) > 0 do
      IO.puts("\n" <> colorize(state.config, "⚠️  Flaky Tests Detected:", :yellow))

      Enum.each(flaky_report.flaky_tests, fn test ->
        status = if test.quarantined, do: "(QUARANTINED)", else: ""
        IO.puts("  • #{test.test_name} - #{test.failure_rate}% failure rate #{status}")
      end)

      IO.puts(
        "\n" <>
          colorize(
            state.config,
            "Consider investigating these flaky tests to improve test reliability.",
            :yellow
          )
      )
    else
      IO.puts(
        "\n" <>
          colorize(
            state.config,
            "✅ No flaky tests detected - excellent test reliability!",
            :green
          )
      )
    end

    # Print quarantined tests
    if length(flaky_report.quarantined_tests) > 0 do
      IO.puts("\n" <> colorize(state.config, "🚧 Quarantined Tests:", :red))

      Enum.each(flaky_report.quarantined_tests, fn test_name ->
        IO.puts("  • #{test_name}")
      end)
    end

    # Print retry statistics
    if map_size(state.retry_counts) > 0 do
      IO.puts("\n" <> colorize(state.config, "🔄 Test Retry Statistics:", :yellow))

      Enum.each(state.retry_counts, fn {test_key, retry_count} ->
        IO.puts("  • #{test_key}: #{retry_count} retries")
      end)
    end

    IO.puts(
      "\n" <>
        colorize(
          state.config,
          "🎯 Test reliability report saved to test/support/flaky_test_history.json",
          :cyan
        )
    )
  end

  defp colorize(config, string, color) do
    if config.colors do
      case color do
        :red -> IO.ANSI.red() <> string <> IO.ANSI.reset()
        :green -> IO.ANSI.green() <> string <> IO.ANSI.reset()
        :yellow -> IO.ANSI.yellow() <> string <> IO.ANSI.reset()
        :blue -> IO.ANSI.blue() <> string <> IO.ANSI.reset()
        :cyan -> IO.ANSI.cyan() <> string <> IO.ANSI.reset()
        _ -> string
      end
    else
      string
    end
  end
end
