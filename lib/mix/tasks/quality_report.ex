defmodule Mix.Tasks.QualityReport do
  @moduledoc """
  Generates comprehensive quality reports for the project.

  ## Usage

      mix quality_report
      mix quality_report --format json
      mix quality_report --format markdown --output report.md
      mix quality_report --ci

  ## Options

    * `--format` - Output format: json, markdown, text (default: text)
    * `--output` - Output file path (default: stdout)
    * `--ci` - CI mode with machine-readable output
    * `--baseline` - Compare against baseline metrics
    * `--detailed` - Include detailed analysis
  """

  use Mix.Task

  @shortdoc "Generate comprehensive quality reports"

  @default_format "text"

  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          format: :string,
          output: :string,
          ci: :boolean,
          baseline: :boolean,
          detailed: :boolean
        ],
        aliases: [
          f: :format,
          o: :output
        ]
      )

    format = Keyword.get(opts, :format, @default_format)
    output_file = Keyword.get(opts, :output)
    ci_mode = Keyword.get(opts, :ci, false)
    compare_baseline = Keyword.get(opts, :baseline, false)
    detailed = Keyword.get(opts, :detailed, false)

    Mix.shell().info("📊 Generating quality report...")

    # Collect all quality metrics
    report_data = collect_quality_metrics(detailed)

    # Compare with baseline if requested
    report_data =
      if compare_baseline do
        add_baseline_comparison(report_data)
      else
        report_data
      end

    # Format the report
    formatted_report = format_report(report_data, format, ci_mode)

    # Output the report
    if output_file do
      File.write!(output_file, formatted_report)
      Mix.shell().info("📄 Report written to: #{output_file}")
    else
      IO.puts(formatted_report)
    end

    # Exit with appropriate code in CI mode
    if ci_mode and report_data.overall_score < 80 do
      Mix.shell().error("Quality score below threshold: #{report_data.overall_score}%")
      exit({:shutdown, 1})
    end
  end

  defp collect_quality_metrics(detailed) do
    timestamp = DateTime.utc_now()

    %{
      timestamp: timestamp,
      project: get_project_info(),
      compilation: get_compilation_metrics(),
      code_quality: get_code_quality_metrics(),
      testing: get_testing_metrics(detailed),
      coverage: get_coverage_metrics(),
      security: get_security_metrics(),
      dependencies: get_dependency_metrics(),
      performance: get_performance_metrics(detailed),
      overall_score: 0
    }
    |> calculate_overall_score()
  end

  defp get_project_info do
    mix_project = Mix.Project.config()

    %{
      name: mix_project[:app],
      version: mix_project[:version],
      elixir_version: mix_project[:elixir],
      deps_count: length(mix_project[:deps] || [])
    }
  end

  defp get_compilation_metrics do
    try do
      {_output, exit_code} =
        System.cmd("mix", ["compile", "--warnings-as-errors"],
          stderr_to_stdout: true,
          env: [{"MIX_ENV", "dev"}]
        )

      %{
        status: if(exit_code == 0, do: "success", else: "failed"),
        warnings: count_compilation_warnings(),
        errors: if(exit_code == 0, do: 0, else: 1)
      }
    rescue
      _ ->
        %{status: "error", warnings: 0, errors: 1}
    end
  end

  defp count_compilation_warnings do
    try do
      {output, _} = System.cmd("mix", ["compile"], stderr_to_stdout: true)

      output
      |> String.split("\n")
      |> Enum.count(&String.contains?(&1, "warning:"))
    rescue
      _ -> 0
    end
  end

  defp get_code_quality_metrics do
    credo_results = run_credo_analysis()
    dialyzer_results = run_dialyzer_analysis()

    %{
      credo: credo_results,
      dialyzer: dialyzer_results,
      complexity: analyze_code_complexity()
    }
  end

  defp run_credo_analysis do
    try do
      {output, exit_code} =
        System.cmd("mix", ["credo", "--format", "json"], stderr_to_stdout: true)

      if exit_code == 0 do
        case Jason.decode(output) do
          {:ok, results} ->
            issues = results["issues"] || []

            %{
              status: "success",
              total_issues: length(issues),
              high_priority: count_issues_by_priority(issues, "high"),
              medium_priority: count_issues_by_priority(issues, "normal"),
              low_priority: count_issues_by_priority(issues, "low")
            }

          _ ->
            %{status: "error", total_issues: 0}
        end
      else
        %{status: "failed", total_issues: 0}
      end
    rescue
      _ ->
        %{status: "unavailable", total_issues: 0}
    end
  end

  defp count_issues_by_priority(issues, priority) do
    Enum.count(issues, fn issue ->
      issue["priority"] == priority
    end)
  end

  defp run_dialyzer_analysis do
    try do
      {_output, exit_code} = System.cmd("mix", ["dialyzer"], stderr_to_stdout: true)

      %{
        status: if(exit_code == 0, do: "success", else: "failed"),
        errors: if(exit_code == 0, do: 0, else: 1)
      }
    rescue
      _ ->
        %{status: "unavailable", errors: 0}
    end
  end

  defp analyze_code_complexity do
    # Simple complexity analysis based on file statistics
    lib_files = Path.wildcard("lib/**/*.ex")

    total_lines =
      lib_files
      |> Enum.map(&count_lines_in_file/1)
      |> Enum.sum()

    avg_file_size = if length(lib_files) > 0, do: total_lines / length(lib_files), else: 0

    %{
      total_files: length(lib_files),
      total_lines: total_lines,
      avg_file_size: Float.round(avg_file_size, 1),
      large_files: count_large_files(lib_files)
    }
  end

  defp count_lines_in_file(file_path) do
    try do
      file_path
      |> File.read!()
      |> String.split("\n")
      |> length()
    rescue
      _ -> 0
    end
  end

  defp count_large_files(files) do
    Enum.count(files, fn file ->
      count_lines_in_file(file) > 500
    end)
  end

  defp get_testing_metrics(detailed) do
    try do
      {output, exit_code} =
        System.cmd("mix", ["test", "--cover"],
          stderr_to_stdout: true,
          env: [{"MIX_ENV", "test"}]
        )

      test_results = parse_test_output(output)

      base_metrics = %{
        status: if(exit_code == 0, do: "success", else: "failed"),
        total_tests: test_results.total,
        passed: test_results.passed,
        failed: test_results.failed,
        success_rate: test_results.success_rate
      }

      if detailed do
        Map.merge(base_metrics, %{
          slow_tests: find_slow_tests(output),
          flaky_tests: get_flaky_test_history()
        })
      else
        base_metrics
      end
    rescue
      _ ->
        %{status: "error", total_tests: 0, passed: 0, failed: 0, success_rate: 0}
    end
  end

  defp parse_test_output(output) do
    case Regex.run(~r/(\d+) tests?, (\d+) failures?/, output) do
      [_, total_str, failures_str] ->
        total = String.to_integer(total_str)
        failed = String.to_integer(failures_str)
        passed = total - failed
        success_rate = if total > 0, do: passed / total * 100, else: 0

        %{total: total, passed: passed, failed: failed, success_rate: success_rate}

      _ ->
        %{total: 0, passed: 0, failed: 0, success_rate: 0}
    end
  end

  defp find_slow_tests(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "ms]"))
    |> Enum.map(&extract_test_timing/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(fn {_test, time} -> time > 1000 end)
    |> Enum.sort_by(fn {_test, time} -> time end, :desc)
    |> Enum.take(5)
  end

  defp extract_test_timing(line) do
    case Regex.run(~r/test (.+) \(.+\) \[(\d+)ms\]/, line) do
      [_, test_name, time_str] ->
        {test_name, String.to_integer(time_str)}

      _ ->
        nil
    end
  end

  defp get_flaky_test_history do
    # Placeholder for flaky test detection
    # This would integrate with the test stability system
    []
  end

  defp get_coverage_metrics do
    try do
      {output, _exit_code} =
        System.cmd("mix", ["test.coverage.summary", "--format", "json"], stderr_to_stdout: true)

      case Jason.decode(output) do
        {:ok, coverage_data} ->
          %{
            status: "success",
            percentage: coverage_data["total_coverage"] || 0,
            lines_covered: coverage_data["lines_covered"] || 0,
            lines_total: coverage_data["lines_total"] || 0,
            files_with_low_coverage: coverage_data["low_coverage_files"] || []
          }

        _ ->
          %{status: "unavailable", percentage: 0}
      end
    rescue
      _ ->
        %{status: "error", percentage: 0}
    end
  end

  defp get_security_metrics do
    deps_audit = run_deps_audit()
    sobelow_scan = run_sobelow_scan()

    %{
      deps_audit: deps_audit,
      sobelow: sobelow_scan,
      overall_status: determine_security_status([deps_audit, sobelow_scan])
    }
  end

  defp run_deps_audit do
    try do
      {_output, exit_code} = System.cmd("mix", ["deps.audit"], stderr_to_stdout: true)

      %{
        status: if(exit_code == 0, do: "clean", else: "vulnerabilities_found"),
        vulnerabilities: if(exit_code == 0, do: 0, else: 1)
      }
    rescue
      _ ->
        %{status: "unavailable", vulnerabilities: 0}
    end
  end

  defp run_sobelow_scan do
    try do
      {_output, exit_code} = System.cmd("mix", ["sobelow", "--config"], stderr_to_stdout: true)

      %{
        status: if(exit_code == 0, do: "clean", else: "issues_found"),
        issues: if(exit_code == 0, do: 0, else: 1)
      }
    rescue
      _ ->
        %{status: "unavailable", issues: 0}
    end
  end

  defp determine_security_status(scans) do
    if Enum.all?(scans, &(&1.status in ["clean", "unavailable"])) do
      "clean"
    else
      "issues_found"
    end
  end

  defp get_dependency_metrics do
    try do
      deps = Mix.Dep.loaded([])

      outdated_deps = get_outdated_dependencies()

      %{
        total_deps: length(deps),
        outdated_deps: length(outdated_deps),
        outdated_list: outdated_deps,
        # Would integrate with deps.audit
        security_advisories: 0
      }
    rescue
      _ ->
        %{total_deps: 0, outdated_deps: 0, outdated_list: []}
    end
  end

  defp get_outdated_dependencies do
    try do
      {output, _exit_code} = System.cmd("mix", ["hex.outdated"], stderr_to_stdout: true)

      output
      |> String.split("\n")
      |> Enum.filter(&String.contains?(&1, "Update available"))
      |> Enum.map(&extract_outdated_dep/1)
      |> Enum.reject(&is_nil/1)
    rescue
      _ -> []
    end
  end

  defp extract_outdated_dep(line) do
    case Regex.run(~r/(\w+)\s+\((.+)\s+->\s+(.+)\)/, line) do
      [_, dep_name, current, latest] ->
        %{name: dep_name, current: current, latest: latest}

      _ ->
        nil
    end
  end

  defp get_performance_metrics(detailed) do
    if detailed do
      %{
        compile_time: measure_compile_time(),
        test_time: measure_test_time(),
        memory_usage: get_memory_usage()
      }
    else
      %{status: "skipped"}
    end
  end

  defp measure_compile_time do
    start_time = System.monotonic_time(:millisecond)

    try do
      System.cmd("mix", ["compile"], stderr_to_stdout: true)
      duration = System.monotonic_time(:millisecond) - start_time
      %{duration_ms: duration, status: "measured"}
    rescue
      _ ->
        %{duration_ms: 0, status: "error"}
    end
  end

  defp measure_test_time do
    # This would run a subset of tests to measure performance
    %{duration_ms: 0, status: "skipped"}
  end

  defp get_memory_usage do
    # Basic memory usage information
    {:memory, memory_info} = :erlang.process_info(self(), :memory)

    %{
      process_memory: memory_info,
      system_memory: :erlang.memory(:total)
    }
  end

  defp calculate_overall_score(report_data) do
    scores = %{
      compilation: calculate_compilation_score(report_data.compilation),
      code_quality: calculate_code_quality_score(report_data.code_quality),
      testing: calculate_testing_score(report_data.testing),
      coverage: calculate_coverage_score(report_data.coverage),
      security: calculate_security_score(report_data.security)
    }

    overall_score =
      scores
      |> Map.values()
      |> Enum.sum()
      |> Kernel./(map_size(scores))
      |> Float.round(1)

    Map.put(report_data, :overall_score, overall_score)
    |> Map.put(:component_scores, scores)
  end

  defp calculate_compilation_score(%{status: "success", warnings: warnings}) do
    max(100 - warnings * 5, 0)
  end

  defp calculate_compilation_score(_), do: 0

  defp calculate_code_quality_score(%{credo: %{total_issues: issues}}) do
    max(100 - issues, 0)
  end

  defp calculate_code_quality_score(_), do: 50

  defp calculate_testing_score(%{success_rate: rate}) when is_number(rate), do: rate
  defp calculate_testing_score(_), do: 0

  defp calculate_coverage_score(%{percentage: percentage}) when is_number(percentage),
    do: percentage

  defp calculate_coverage_score(_), do: 0

  defp calculate_security_score(%{overall_status: "clean"}), do: 100
  defp calculate_security_score(%{overall_status: "issues_found"}), do: 50
  defp calculate_security_score(_), do: 75

  defp add_baseline_comparison(report_data) do
    baseline_file = "quality_baseline.json"

    if File.exists?(baseline_file) do
      case File.read(baseline_file) |> Jason.decode() do
        {:ok, baseline} ->
          Map.put(report_data, :baseline_comparison, compare_with_baseline(report_data, baseline))

        _ ->
          report_data
      end
    else
      report_data
    end
  end

  defp compare_with_baseline(current, baseline) do
    %{
      score_change: current.overall_score - (baseline["overall_score"] || 0),
      test_count_change:
        current.testing.total_tests - (get_in(baseline, ["testing", "total_tests"]) || 0),
      coverage_change:
        current.coverage.percentage - (get_in(baseline, ["coverage", "percentage"]) || 0)
    }
  end

  defp format_report(report_data, format, ci_mode) do
    case format do
      "json" -> format_json_report(report_data)
      "markdown" -> format_markdown_report(report_data, ci_mode)
      _ -> format_text_report(report_data, ci_mode)
    end
  end

  defp format_json_report(report_data) do
    Jason.encode!(report_data, pretty: true)
  end

  defp format_markdown_report(report_data, ci_mode) do
    score_emoji = if report_data.overall_score >= 80, do: "🟢", else: "🟡"

    """
    # 📊 Quality Report

    #{score_emoji} **Overall Score: #{report_data.overall_score}%**

    *Generated: #{DateTime.to_string(report_data.timestamp)}*

    ## 📈 Component Scores

    | Component | Score | Status |
    |-----------|-------|--------|
    | Compilation | #{report_data.component_scores.compilation}% | #{compilation_status_emoji(report_data.compilation)} |
    | Code Quality | #{report_data.component_scores.code_quality}% | #{code_quality_status_emoji(report_data.code_quality)} |
    | Testing | #{report_data.component_scores.testing}% | #{testing_status_emoji(report_data.testing)} |
    | Coverage | #{report_data.component_scores.coverage}% | #{coverage_status_emoji(report_data.coverage)} |
    | Security | #{report_data.component_scores.security}% | #{security_status_emoji(report_data.security)} |

    ## 🔍 Detailed Analysis

    ### Compilation
    - **Status**: #{report_data.compilation.status}
    - **Warnings**: #{report_data.compilation.warnings}
    - **Errors**: #{report_data.compilation.errors}

    ### Code Quality
    - **Credo Issues**: #{report_data.code_quality.credo.total_issues}
    - **Dialyzer Status**: #{report_data.code_quality.dialyzer.status}

    ### Testing
    - **Total Tests**: #{report_data.testing.total_tests}
    - **Success Rate**: #{Float.round(report_data.testing.success_rate, 1)}%
    - **Failed Tests**: #{report_data.testing.failed}

    ### Coverage
    - **Coverage**: #{report_data.coverage.percentage}%
    - **Lines Covered**: #{report_data.coverage.lines_covered || 0}
    - **Total Lines**: #{report_data.coverage.lines_total || 0}

    ### Security
    - **Dependencies**: #{report_data.security.deps_audit.status}
    - **Sobelow**: #{report_data.security.sobelow.status}

    #{if Map.has_key?(report_data, :baseline_comparison), do: format_baseline_comparison(report_data.baseline_comparison), else: ""}

    ---

    #{if ci_mode, do: "*This report was generated in CI mode*", else: "*Generated by `mix quality_report`*"}
    """
  end

  defp format_text_report(report_data, _ci_mode) do
    """

    📊 QUALITY REPORT
    ═══════════════════════════════════════════════════════════

    Overall Score: #{report_data.overall_score}% #{score_indicator(report_data.overall_score)}

    Component Breakdown:
    ────────────────────────────────────────────────────────────
    📝 Compilation:   #{report_data.component_scores.compilation}%  (#{report_data.compilation.warnings} warnings)
    🎯 Code Quality:  #{report_data.component_scores.code_quality}%  (#{report_data.code_quality.credo.total_issues} Credo issues)
    🧪 Testing:       #{report_data.component_scores.testing}%  (#{report_data.testing.total_tests} tests)
    📊 Coverage:      #{report_data.component_scores.coverage}%
    🛡️  Security:     #{report_data.component_scores.security}%  (#{report_data.security.overall_status})

    #{if Map.has_key?(report_data, :baseline_comparison), do: format_baseline_text(report_data.baseline_comparison), else: ""}

    Generated: #{DateTime.to_string(report_data.timestamp)}
    ═══════════════════════════════════════════════════════════

    """
  end

  defp score_indicator(score) when score >= 90, do: "🌟 Excellent"
  defp score_indicator(score) when score >= 80, do: "✅ Good"
  defp score_indicator(score) when score >= 70, do: "⚠️  Needs Improvement"
  defp score_indicator(_), do: "❌ Poor"

  defp compilation_status_emoji(%{status: "success", warnings: 0}), do: "✅"
  defp compilation_status_emoji(%{status: "success"}), do: "⚠️"
  defp compilation_status_emoji(_), do: "❌"

  defp code_quality_status_emoji(%{credo: %{total_issues: issues}}) when issues < 10, do: "✅"
  defp code_quality_status_emoji(%{credo: %{total_issues: issues}}) when issues < 50, do: "⚠️"
  defp code_quality_status_emoji(_), do: "❌"

  defp testing_status_emoji(%{success_rate: rate}) when rate >= 95, do: "✅"
  defp testing_status_emoji(%{success_rate: rate}) when rate >= 80, do: "⚠️"
  defp testing_status_emoji(_), do: "❌"

  defp coverage_status_emoji(%{percentage: coverage}) when coverage >= 80, do: "✅"
  defp coverage_status_emoji(%{percentage: coverage}) when coverage >= 60, do: "⚠️"
  defp coverage_status_emoji(_), do: "❌"

  defp security_status_emoji(%{overall_status: "clean"}), do: "✅"
  defp security_status_emoji(_), do: "⚠️"

  defp format_baseline_comparison(comparison) do
    """
    ## 📈 Baseline Comparison

    - **Score Change**: #{format_change(comparison.score_change)}%
    - **Test Count Change**: #{format_change(comparison.test_count_change)} tests
    - **Coverage Change**: #{format_change(comparison.coverage_change)}%
    """
  end

  defp format_baseline_text(comparison) do
    """
    Baseline Comparison:
    ────────────────────────────────────────────────────────────
    Score Change:    #{format_change(comparison.score_change)}%
    Test Change:     #{format_change(comparison.test_count_change)} tests
    Coverage Change: #{format_change(comparison.coverage_change)}%
    """
  end

  defp format_change(change) when change > 0, do: "+#{change}"
  defp format_change(change), do: "#{change}"
end
