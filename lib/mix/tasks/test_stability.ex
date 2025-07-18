defmodule Mix.Tasks.Test.Stability do
  @moduledoc """
  Runs tests multiple times to detect flaky tests.

  ## Usage

      mix test.stability
      mix test.stability --runs 10
      mix test.stability --runs 5 --file test/specific_test.exs
      mix test.stability --tag flaky
      mix test.stability --detect --threshold 0.95

  ## Options

    * `--runs` - Number of times to run tests (default: 5)
    * `--file` - Specific test file to check
    * `--tag` - Only run tests with specific tag
    * `--detect` - Detection mode, identifies flaky tests
    * `--threshold` - Success rate threshold for detection (default: 0.95)
    * `--parallel` - Run iterations in parallel
    * `--report` - Generate detailed report file
  """

  use Mix.Task

  @shortdoc "Detect flaky tests by running them multiple times"

  @default_runs 5
  @default_threshold 0.95

  def run(args) do
    {opts, test_args, _} =
      OptionParser.parse(args,
        switches: [
          runs: :integer,
          file: :string,
          tag: :string,
          detect: :boolean,
          threshold: :float,
          parallel: :boolean,
          report: :string
        ],
        aliases: [
          r: :runs,
          f: :file,
          t: :tag,
          d: :detect,
          p: :parallel
        ]
      )

    runs = Keyword.get(opts, :runs, @default_runs)
    threshold = Keyword.get(opts, :threshold, @default_threshold)
    detect_mode = Keyword.get(opts, :detect, false)
    parallel = Keyword.get(opts, :parallel, false)
    report_file = Keyword.get(opts, :report)

    Mix.shell().info("🔍 Running test stability check...")
    Mix.shell().info("   Iterations: #{runs}")
    Mix.shell().info("   Threshold: #{Float.round(threshold * 100, 1)}%")
    Mix.shell().info("")

    # Build test command
    test_cmd = build_test_command(opts, test_args)

    # Run tests multiple times
    results =
      if parallel do
        run_tests_parallel(test_cmd, runs)
      else
        run_tests_sequential(test_cmd, runs)
      end

    # Analyze results
    analysis = analyze_results(results, threshold)

    # Display results
    display_results(analysis, detect_mode)

    # Generate report if requested
    if report_file do
      generate_report(analysis, report_file)
    end

    # Exit with appropriate code
    if analysis.flaky_count > 0 and detect_mode do
      Mix.shell().error("\n❌ Found #{analysis.flaky_count} flaky tests!")
      exit({:shutdown, 1})
    else
      Mix.shell().info("\n✅ Test stability check complete")
    end
  end

  defp build_test_command(opts, test_args) do
    cmd_parts = ["test"]

    cmd_parts =
      if file = Keyword.get(opts, :file) do
        cmd_parts ++ [file]
      else
        cmd_parts
      end

    cmd_parts =
      if tag = Keyword.get(opts, :tag) do
        cmd_parts ++ ["--only", tag]
      else
        cmd_parts
      end

    cmd_parts ++ test_args
  end

  defp run_tests_sequential(test_cmd, runs) do
    for i <- 1..runs do
      Mix.shell().info("Running iteration #{i}/#{runs}...")

      start_time = System.monotonic_time(:millisecond)

      # Capture test output
      {output, exit_code} =
        System.cmd("mix", test_cmd,
          stderr_to_stdout: true,
          env: [{"MIX_ENV", "test"}]
        )

      duration = System.monotonic_time(:millisecond) - start_time

      # Parse test results
      test_results = parse_test_output(output)

      %{
        iteration: i,
        exit_code: exit_code,
        duration: duration,
        output: output,
        tests: test_results.tests,
        failures: test_results.failures,
        failed_tests: test_results.failed_tests
      }
    end
  end

  defp run_tests_parallel(test_cmd, runs) do
    Mix.shell().info("Running #{runs} iterations in parallel...")

    tasks =
      for i <- 1..runs do
        Task.async(fn ->
          start_time = System.monotonic_time(:millisecond)

          {output, exit_code} =
            System.cmd("mix", test_cmd,
              stderr_to_stdout: true,
              env: [{"MIX_ENV", "test"}]
            )

          duration = System.monotonic_time(:millisecond) - start_time
          test_results = parse_test_output(output)

          %{
            iteration: i,
            exit_code: exit_code,
            duration: duration,
            output: output,
            tests: test_results.tests,
            failures: test_results.failures,
            failed_tests: test_results.failed_tests
          }
        end)
      end

    Task.await_many(tasks, :infinity)
  end

  defp parse_test_output(output) do
    lines = String.split(output, "\n")

    # Extract test count and failures
    test_summary = Enum.find(lines, &String.contains?(&1, "test"))

    {tests, failures} =
      case Regex.run(~r/(\d+) tests?, (\d+) failures?/, test_summary || "") do
        [_, tests, failures] ->
          {String.to_integer(tests), String.to_integer(failures)}

        _ ->
          {0, 0}
      end

    # Extract failed test names
    failed_tests = extract_failed_tests(output)

    %{
      tests: tests,
      failures: failures,
      failed_tests: failed_tests
    }
  end

  defp extract_failed_tests(output) do
    output
    |> String.split("\n")
    # More precise filtering for actual test failures
    |> Enum.filter(
      &(String.contains?(&1, "test ") and
          (String.contains?(&1, "FAILED") or String.contains?(&1, "ERROR") or
             Regex.match?(~r/^\s*\d+\)\s+test/, &1)))
    )
    |> Enum.map(&extract_test_name/1)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_test_name(line) do
    case Regex.run(~r/test (.+) \((.+)\)/, line) do
      [_, name, module] -> "#{module}: #{name}"
      _ -> nil
    end
  end

  defp analyze_results(results, threshold) do
    total_runs = length(results)

    # Group failures by test name
    all_failures =
      results
      |> Enum.flat_map(& &1.failed_tests)
      |> Enum.frequencies()

    # Identify flaky tests
    flaky_tests =
      all_failures
      |> Enum.filter(fn {_test, fail_count} ->
        success_rate = (total_runs - fail_count) / total_runs
        success_rate < threshold and success_rate > 0
      end)
      |> Enum.map(fn {test, fail_count} ->
        success_rate = (total_runs - fail_count) / total_runs

        %{
          test: test,
          failures: fail_count,
          success_rate: success_rate,
          failure_rate: fail_count / total_runs
        }
      end)
      |> Enum.sort_by(& &1.failure_rate, :desc)

    # Calculate statistics
    total_tests = results |> Enum.map(& &1.tests) |> Enum.max(fn -> 0 end)
    avg_duration = results |> Enum.map(& &1.duration) |> average()
    success_runs = Enum.count(results, &(&1.exit_code == 0))

    %{
      total_runs: total_runs,
      total_tests: total_tests,
      success_runs: success_runs,
      failed_runs: total_runs - success_runs,
      success_rate: success_runs / total_runs,
      avg_duration: avg_duration,
      flaky_tests: flaky_tests,
      flaky_count: length(flaky_tests),
      all_failures: all_failures
    }
  end

  defp average([]), do: 0
  defp average(list), do: Enum.sum(list) / length(list)

  defp display_results(analysis, detect_mode) do
    Mix.shell().info("\n📊 Test Stability Results")
    Mix.shell().info("=" |> String.duplicate(50))

    Mix.shell().info("\nSummary:")
    Mix.shell().info("  Total test runs: #{analysis.total_runs}")
    Mix.shell().info("  Successful runs: #{analysis.success_runs}")
    Mix.shell().info("  Failed runs: #{analysis.failed_runs}")
    Mix.shell().info("  Overall success rate: #{format_percentage(analysis.success_rate)}")
    Mix.shell().info("  Average duration: #{Float.round(analysis.avg_duration / 1000, 2)}s")

    if analysis.flaky_count > 0 do
      Mix.shell().info("\n⚠️  Flaky Tests Detected:")
      Mix.shell().info("-" |> String.duplicate(50))

      for test <- analysis.flaky_tests do
        Mix.shell().info("\n  #{test.test}")
        Mix.shell().info("    Failure rate: #{format_percentage(test.failure_rate)}")
        Mix.shell().info("    Failed #{test.failures} out of #{analysis.total_runs} runs")
      end
    else
      Mix.shell().info("\n✅ No flaky tests detected!")
    end

    if not detect_mode and map_size(analysis.all_failures) > 0 do
      Mix.shell().info("\n📝 All Test Failures:")
      Mix.shell().info("-" |> String.duplicate(50))

      for {test, count} <- analysis.all_failures do
        percentage = count / analysis.total_runs
        Mix.shell().info("  #{test}: #{count} failures (#{format_percentage(percentage)})")
      end
    end
  end

  defp format_percentage(rate) do
    "#{Float.round(rate * 100, 1)}%"
  end

  defp generate_report(analysis, report_file) do
    timestamp = DateTime.utc_now() |> DateTime.to_string()

    report = %{
      timestamp: timestamp,
      summary: %{
        total_runs: analysis.total_runs,
        total_tests: analysis.total_tests,
        success_runs: analysis.success_runs,
        failed_runs: analysis.failed_runs,
        success_rate: analysis.success_rate,
        avg_duration_ms: analysis.avg_duration
      },
      flaky_tests: analysis.flaky_tests,
      all_failures: analysis.all_failures
    }

    json = Jason.encode!(report, pretty: true)
    File.write!(report_file, json)

    Mix.shell().info("\n📄 Report written to: #{report_file}")
  end
end
