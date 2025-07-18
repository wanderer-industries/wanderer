defmodule WandererApp.TestPerformanceMonitorTest do
  use ExUnit.Case, async: true

  alias WandererApp.TestPerformanceMonitor

  describe "TestPerformanceMonitor" do
    setup do
      # Clear any existing performance data
      TestPerformanceMonitor.clear_performance_data()
      :ok
    end

    test "monitors test execution time" do
      test_name = "sample_test"

      result =
        TestPerformanceMonitor.monitor_test(test_name, fn ->
          # Simulate some work
          Process.sleep(10)
          "test_result"
        end)

      assert result == "test_result"
    end

    test "records test performance data" do
      test_name = "recorded_test"
      duration_ms = 150

      test_data = TestPerformanceMonitor.record_test_time(test_name, duration_ms)

      assert test_data.name == test_name
      assert test_data.duration_ms == duration_ms
      # Under 5000ms threshold
      assert test_data.threshold_exceeded == false
      assert %DateTime{} = test_data.timestamp
    end

    test "identifies slow tests that exceed threshold" do
      test_name = "slow_test"
      # Over 5000ms threshold
      duration_ms = 6000

      test_data = TestPerformanceMonitor.record_test_time(test_name, duration_ms)

      assert test_data.threshold_exceeded == true
    end

    test "tracks multiple test performance data" do
      # Record multiple tests
      TestPerformanceMonitor.record_test_time("test1", 100)
      TestPerformanceMonitor.record_test_time("test2", 200)
      TestPerformanceMonitor.record_test_time("test3", 300)

      data = TestPerformanceMonitor.get_performance_data()

      assert length(data) == 3
      assert Enum.any?(data, &(&1.name == "test1"))
      assert Enum.any?(data, &(&1.name == "test2"))
      assert Enum.any?(data, &(&1.name == "test3"))
    end

    test "generates performance report" do
      # Record some test data
      TestPerformanceMonitor.record_test_time("fast_test", 100)
      TestPerformanceMonitor.record_test_time("slow_test", 6000)
      TestPerformanceMonitor.record_test_time("medium_test", 1000)

      report = TestPerformanceMonitor.generate_performance_report()

      assert is_binary(report)
      assert report =~ "Test Performance Report"
      assert report =~ "Total Tests: 3"
      assert report =~ "slow_test"
      # Should warn about slow test
      assert report =~ "Performance Warning"
    end

    test "clears performance data" do
      TestPerformanceMonitor.record_test_time("test", 100)
      assert length(TestPerformanceMonitor.get_performance_data()) == 1

      TestPerformanceMonitor.clear_performance_data()
      assert TestPerformanceMonitor.get_performance_data() == []
    end

    test "suite monitoring tracks total execution time" do
      start_ref = TestPerformanceMonitor.start_suite_monitoring()
      assert is_integer(start_ref)

      # Simulate some work
      Process.sleep(50)

      duration = TestPerformanceMonitor.stop_suite_monitoring()
      assert duration >= 50
    end

    test "checks if suite is within time limits" do
      # Test fast suite (within limits)
      assert TestPerformanceMonitor.suite_within_limits?(30_000) == true

      # Test slow suite (exceeds 5 minute limit)
      assert TestPerformanceMonitor.suite_within_limits?(400_000) == false
    end

    test "provides threshold constants" do
      assert TestPerformanceMonitor.performance_threshold_ms() == 5000
      assert TestPerformanceMonitor.suite_threshold_ms() == 300_000
    end

    test "handles errors in monitored tests" do
      test_name = "failing_test"

      assert_raise RuntimeError, "test error", fn ->
        TestPerformanceMonitor.monitor_test(test_name, fn ->
          raise "test error"
        end)
      end
    end

    test "empty performance data generates appropriate report" do
      TestPerformanceMonitor.clear_performance_data()

      report = TestPerformanceMonitor.generate_performance_report()

      assert report == "No performance data available"
    end
  end
end
