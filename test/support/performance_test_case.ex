defmodule WandererApp.PerformanceTestCase do
  @moduledoc """
  Test case template that includes automatic performance monitoring.

  Use this instead of the standard test cases when you want to monitor
  test performance automatically.

  ## Usage

      defmodule MyTest do
        use WandererApp.PerformanceTestCase, async: true
        
        test "my test" do
          # Test code here
          # Performance will be automatically monitored
        end
      end
  """

  use ExUnit.CaseTemplate
  alias WandererApp.TestPerformanceMonitor

  using(opts) do
    quote do
      # Import the base case template (DataCase or ConnCase)
      case unquote(opts[:case_type] || :data) do
        :data -> use WandererApp.DataCase, unquote(opts)
        :conn -> use WandererAppWeb.ConnCase, unquote(opts)
        :api -> use WandererAppWeb.ApiCase, unquote(opts)
      end

      # Import performance monitoring functions
      import WandererApp.TestPerformanceMonitor, only: [monitor_test: 2]

      # Setup performance monitoring for each test
      setup do
        test_name = "#{inspect(__MODULE__)}"
        TestPerformanceMonitor.clear_performance_data()

        on_exit(fn ->
          # Generate performance report if running in verbose mode
          if System.get_env("VERBOSE_TESTS") do
            report = TestPerformanceMonitor.generate_performance_report()
            IO.puts(report)
          end
        end)

        %{test_name: test_name}
      end
    end
  end

  @doc """
  Macro to wrap test definitions with automatic performance monitoring.
  """
  defmacro performance_test(name, context \\ quote(do: _), do: block) do
    quote do
      test unquote(name), unquote(context) do
        test_name = "#{unquote(name)}"

        WandererApp.TestPerformanceMonitor.monitor_test(test_name, fn ->
          unquote(block)
        end)
      end
    end
  end

  @doc """
  Macro for testing with a specific performance threshold.
  """
  defmacro performance_test_with_threshold(name, threshold_ms, context \\ quote(do: _), do: block) do
    quote do
      test unquote(name), unquote(context) do
        test_name = "#{unquote(name)}"
        start_time = System.monotonic_time(:millisecond)

        result = unquote(block)

        duration_ms = System.monotonic_time(:millisecond) - start_time

        if duration_ms > unquote(threshold_ms) do
          flunk(
            "Test '#{test_name}' took #{duration_ms}ms, exceeding threshold of #{unquote(threshold_ms)}ms"
          )
        end

        WandererApp.TestPerformanceMonitor.record_test_time(test_name, duration_ms)
        result
      end
    end
  end
end
