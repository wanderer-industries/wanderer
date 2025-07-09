defmodule Mix.Tasks.Quality.Report do
  @moduledoc """
  Generates a comprehensive quality report for the project.

  ## Usage

      mix quality.report
      mix quality.report --format json
      mix quality.report --output report.md

  ## Options

    * `--format` - Output format: text (default), json, or markdown
    * `--output` - Write report to file instead of stdout
    * `--verbose` - Include detailed issue listings
  """

  use Mix.Task

  @shortdoc "Generate project quality report"

  @requirements ["app.start"]

  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [format: :string, output: :string, verbose: :boolean],
        aliases: [f: :format, o: :output, v: :verbose]
      )

    format = Keyword.get(opts, :format, "text")
    output_file = Keyword.get(opts, :output)
    verbose = Keyword.get(opts, :verbose, false)

    report = generate_report(verbose)
    formatted_report = format_report(report, format)

    if output_file do
      File.write!(output_file, formatted_report)
      Mix.shell().info("Quality report written to #{output_file}")
    else
      Mix.shell().info(formatted_report)
    end
  end

  defp generate_report(verbose) do
    Mix.shell().info("🔍 Analyzing project quality...")

    %{
      timestamp: DateTime.utc_now(),
      thresholds: WandererApp.QualityGates.current_thresholds(),
      metrics: %{
        compilation: analyze_compilation(),
        credo: analyze_credo(verbose),
        dialyzer: analyze_dialyzer(),
        coverage: analyze_coverage(),
        tests: analyze_tests(),
        formatting: analyze_formatting(),
        documentation: analyze_documentation(),
        dependencies: analyze_dependencies()
      },
      # Will be calculated after metrics
      summary: nil
    }
    |> add_summary()
  end

  defp analyze_compilation do
    Mix.shell().info("  📦 Checking compilation warnings...")

    output = capture_mix_output("compile --force")
    warnings = count_warnings(output)

    %{
      warnings: warnings,
      threshold: WandererApp.QualityGates.current_thresholds().compilation.max_warnings,
      passes: WandererApp.QualityGates.passes_threshold?(:compilation, :warnings, warnings),
      details: extract_warning_summary(output)
    }
  end

  defp analyze_credo(verbose) do
    Mix.shell().info("  🕵️ Running Credo analysis...")

    credo_output = capture_mix_output("credo --strict --format json")

    case Jason.decode(credo_output) do
      {:ok, %{"issues" => issues}} ->
        issue_count = length(issues)
        high_priority = Enum.count(issues, &(&1["priority"] >= 10))

        %{
          total_issues: issue_count,
          high_priority: high_priority,
          threshold: WandererApp.QualityGates.current_thresholds().credo.max_issues,
          passes: WandererApp.QualityGates.passes_threshold?(:credo, :issues, issue_count),
          by_category: group_credo_issues(issues),
          top_issues: if(verbose, do: Enum.take(issues, 10), else: [])
        }

      _ ->
        # Fallback if JSON parsing fails
        output = capture_mix_output("credo --strict")
        issue_count = count_credo_issues(output)

        %{
          total_issues: issue_count,
          high_priority: 0,
          threshold: WandererApp.QualityGates.current_thresholds().credo.max_issues,
          passes: WandererApp.QualityGates.passes_threshold?(:credo, :issues, issue_count),
          by_category: %{},
          top_issues: []
        }
    end
  end

  defp analyze_dialyzer do
    Mix.shell().info("  🔬 Running Dialyzer analysis...")

    # This might take a while
    output = capture_mix_output("dialyzer")

    errors = count_dialyzer_errors(output)
    warnings = count_dialyzer_warnings(output)

    %{
      errors: errors,
      warnings: warnings,
      threshold: WandererApp.QualityGates.current_thresholds().dialyzer.max_errors,
      passes: WandererApp.QualityGates.passes_threshold?(:dialyzer, :errors, errors),
      details: extract_dialyzer_summary(output)
    }
  end

  defp analyze_coverage do
    Mix.shell().info("  📊 Analyzing test coverage...")

    # Try to get coverage from last test run
    coverage_file = "cover/excoveralls.json"

    if File.exists?(coverage_file) do
      case File.read(coverage_file) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, %{"coverage" => coverage}} ->
              %{
                percentage: coverage,
                threshold: WandererApp.QualityGates.current_thresholds().coverage.minimum,
                passes:
                  WandererApp.QualityGates.passes_threshold?(:coverage, :percentage, coverage),
                # Could parse module-level coverage
                by_module: %{}
              }

            _ ->
              %{percentage: 0, threshold: 70, passes: false, by_module: %{}}
          end

        _ ->
          %{percentage: 0, threshold: 70, passes: false, by_module: %{}}
      end
    else
      # Run tests with coverage
      output = capture_mix_output("test --cover")
      coverage = extract_coverage_percentage(output)

      %{
        percentage: coverage,
        threshold: WandererApp.QualityGates.current_thresholds().coverage.minimum,
        passes: WandererApp.QualityGates.passes_threshold?(:coverage, :percentage, coverage),
        by_module: %{}
      }
    end
  end

  defp analyze_tests do
    Mix.shell().info("  🧪 Analyzing test suite...")

    start_time = System.monotonic_time(:second)
    output = capture_mix_output("test")
    duration = System.monotonic_time(:second) - start_time

    failures = extract_test_failures(output)
    test_count = extract_test_count(output)

    %{
      total_tests: test_count,
      failures: failures,
      duration_seconds: duration,
      failure_threshold: WandererApp.QualityGates.current_thresholds().tests.max_failures,
      duration_threshold:
        WandererApp.QualityGates.current_thresholds().tests.max_duration_seconds,
      passes:
        WandererApp.QualityGates.passes_threshold?(:tests, :failures, failures) &&
          WandererApp.QualityGates.passes_threshold?(:tests, :duration, duration)
    }
  end

  defp analyze_formatting do
    Mix.shell().info("  🎨 Checking code formatting...")

    output = capture_mix_output("format --check-formatted")
    properly_formatted = !String.contains?(output, "not formatted")

    %{
      properly_formatted: properly_formatted,
      passes: properly_formatted,
      files_needing_format: extract_unformatted_files(output)
    }
  end

  defp analyze_documentation do
    Mix.shell().info("  📚 Analyzing documentation coverage...")

    # This is a simplified check - could be enhanced with doc coverage tools
    module_count = count_modules()
    documented_modules = count_documented_modules()

    coverage = if module_count > 0, do: documented_modules / module_count * 100, else: 0

    %{
      module_coverage: coverage,
      total_modules: module_count,
      documented_modules: documented_modules,
      threshold:
        WandererApp.QualityGates.current_thresholds().documentation.min_module_doc_coverage * 100,
      passes:
        coverage >=
          WandererApp.QualityGates.current_thresholds().documentation.min_module_doc_coverage *
            100
    }
  end

  defp analyze_dependencies do
    Mix.shell().info("  📦 Checking dependencies...")

    outdated_output = capture_mix_output("hex.outdated")
    audit_output = capture_mix_output("deps.audit")

    %{
      outdated: count_outdated_deps(outdated_output),
      vulnerabilities: count_vulnerabilities(audit_output),
      passes: count_vulnerabilities(audit_output) == 0
    }
  end

  defp add_summary(report) do
    metrics = report.metrics

    passing =
      Enum.count(metrics, fn {_, m} ->
        Map.get(m, :passes, true)
      end)

    total = map_size(metrics)

    %{
      report
      | summary: %{
          passing: passing,
          total: total,
          health_score: round(passing / total * 100),
          status:
            cond do
              passing == total -> :excellent
              passing >= total * 0.8 -> :good
              passing >= total * 0.6 -> :fair
              true -> :needs_improvement
            end
        }
    }
  end

  defp format_report(report, "json") do
    Jason.encode!(report, pretty: true)
  end

  defp format_report(report, "markdown") do
    WandererApp.QualityGates.quality_report() <>
      "\n\n" <>
      format_metrics_markdown(report)
  end

  defp format_report(report, _) do
    # Default text format
    """
    ================================================================================
    WandererApp Quality Report - #{DateTime.to_string(report.timestamp)}
    ================================================================================

    Overall Health: #{report.summary.health_score}% (#{report.summary.status})
    Passing Checks: #{report.summary.passing}/#{report.summary.total}

    Compilation:
      Warnings: #{report.metrics.compilation.warnings} (threshold: ≤#{report.metrics.compilation.threshold})
      Status: #{if report.metrics.compilation.passes, do: "✅ PASS", else: "❌ FAIL"}

    Code Quality (Credo):
      Issues: #{report.metrics.credo.total_issues} (threshold: ≤#{report.metrics.credo.threshold})
      High Priority: #{report.metrics.credo.high_priority}
      Status: #{if report.metrics.credo.passes, do: "✅ PASS", else: "❌ FAIL"}

    Static Analysis (Dialyzer):
      Errors: #{report.metrics.dialyzer.errors} (threshold: #{report.metrics.dialyzer.threshold})
      Warnings: #{report.metrics.dialyzer.warnings}
      Status: #{if report.metrics.dialyzer.passes, do: "✅ PASS", else: "❌ FAIL"}

    Test Coverage:
      Coverage: #{report.metrics.coverage.percentage}% (threshold: ≥#{report.metrics.coverage.threshold}%)
      Status: #{if report.metrics.coverage.passes, do: "✅ PASS", else: "❌ FAIL"}

    Tests:
      Total: #{report.metrics.tests.total_tests}
      Failures: #{report.metrics.tests.failures}
      Duration: #{report.metrics.tests.duration_seconds}s
      Status: #{if report.metrics.tests.passes, do: "✅ PASS", else: "❌ FAIL"}

    Code Formatting:
      Status: #{if report.metrics.formatting.passes, do: "✅ PASS", else: "❌ FAIL"}

    Documentation:
      Module Coverage: #{Float.round(report.metrics.documentation.module_coverage, 1)}%
      Status: #{if report.metrics.documentation.passes, do: "✅ PASS", else: "❌ FAIL"}

    Dependencies:
      Outdated: #{report.metrics.dependencies.outdated}
      Vulnerabilities: #{report.metrics.dependencies.vulnerabilities}
      Status: #{if report.metrics.dependencies.passes, do: "✅ PASS", else: "❌ FAIL"}

    ================================================================================
    Run 'mix quality.report --verbose' for detailed findings
    ================================================================================
    """
  end

  defp format_metrics_markdown(report) do
    """
    ## Current Metrics

    | Check | Value | Threshold | Status |
    |-------|-------|-----------|--------|
    | Compilation Warnings | #{report.metrics.compilation.warnings} | ≤#{report.metrics.compilation.threshold} | #{if report.metrics.compilation.passes, do: "✅", else: "❌"} |
    | Credo Issues | #{report.metrics.credo.total_issues} | ≤#{report.metrics.credo.threshold} | #{if report.metrics.credo.passes, do: "✅", else: "❌"} |
    | Dialyzer Errors | #{report.metrics.dialyzer.errors} | #{report.metrics.dialyzer.threshold} | #{if report.metrics.dialyzer.passes, do: "✅", else: "❌"} |
    | Test Coverage | #{report.metrics.coverage.percentage}% | ≥#{report.metrics.coverage.threshold}% | #{if report.metrics.coverage.passes, do: "✅", else: "❌"} |
    | Test Failures | #{report.metrics.tests.failures} | ≤#{report.metrics.tests.failure_threshold} | #{if report.metrics.tests.passes, do: "✅", else: "❌"} |
    """
  end

  # Helper functions for parsing outputs

  defp capture_mix_output(task) do
    # Capture both stdout and stderr
    {output, _exit_code} =
      System.cmd("mix", String.split(task),
        stderr_to_stdout: true,
        env: [{"MIX_ENV", "test"}]
      )

    output
  end

  defp count_warnings(output) do
    Regex.scan(~r/warning:/, output) |> length()
  end

  defp count_credo_issues(output) do
    case Regex.run(~r/(\d+) issue/, output) do
      [_, count] -> String.to_integer(count)
      _ -> 0
    end
  end

  defp count_dialyzer_errors(output) do
    if String.contains?(output, "done (passed successfully)") do
      0
    else
      Regex.scan(~r/^[^:]+:\d+:/, output) |> length()
    end
  end

  defp count_dialyzer_warnings(output) do
    Regex.scan(~r/warning:/, output) |> length()
  end

  defp extract_coverage_percentage(output) do
    case Regex.run(~r/(\d+\.\d+)%/, output) do
      [_, percentage] -> String.to_float(percentage)
      _ -> 0.0
    end
  end

  defp extract_test_failures(output) do
    case Regex.run(~r/(\d+) failure/, output) do
      [_, count] -> String.to_integer(count)
      _ -> 0
    end
  end

  defp extract_test_count(output) do
    case Regex.run(~r/(\d+) test/, output) do
      [_, count] -> String.to_integer(count)
      _ -> 0
    end
  end

  defp extract_warning_summary(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "warning:"))
    |> Enum.take(5)
    |> Enum.map(&String.trim/1)
  end

  defp extract_dialyzer_summary(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.match?(&1, ~r/^[^:]+:\d+:/))
    |> Enum.take(5)
  end

  defp extract_unformatted_files(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&(String.ends_with?(&1, ".ex") || String.ends_with?(&1, ".exs")))
    |> Enum.map(&String.trim/1)
  end

  defp group_credo_issues(issues) do
    issues
    |> Enum.group_by(& &1["category"])
    |> Map.new(fn {k, v} -> {k, length(v)} end)
  end

  defp count_modules do
    Path.wildcard("lib/**/*.ex")
    |> Enum.count()
  end

  defp count_documented_modules do
    Path.wildcard("lib/**/*.ex")
    |> Enum.count(fn file ->
      File.read!(file) |> String.contains?("@moduledoc")
    end)
  end

  defp count_outdated_deps(output) do
    output
    |> String.split("\n")
    |> Enum.count(&String.match?(&1, ~r/^\s+\w+\s+\d/))
  end

  defp count_vulnerabilities(output) do
    if String.contains?(output, "No vulnerabilities found") do
      0
    else
      Regex.scan(~r/Vulnerabilities:/, output) |> length()
    end
  end
end
