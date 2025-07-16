defmodule Mix.Tasks.Quality.ProgressiveCheck do
  @moduledoc """
  Enforces progressive quality improvement targets.

  ## Usage

      mix quality.progressive_check
      mix quality.progressive_check --enforce-targets
      mix quality.progressive_check --update-baselines

  ## Options

    * `--enforce-targets` - Fail if quality targets are not met
    * `--update-baselines` - Update baseline metrics after successful run
    * `--strict` - Use strict quality targets
  """

  use Mix.Task

  @shortdoc "Enforce progressive quality improvement"

  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          enforce_targets: :boolean,
          update_baselines: :boolean,
          strict: :boolean
        ]
      )

    enforce_targets = Keyword.get(opts, :enforce_targets, false)
    update_baselines = Keyword.get(opts, :update_baselines, false)
    strict = Keyword.get(opts, :strict, false)

    Mix.shell().info("🎯 Running progressive quality check...")

    # Load current baselines
    baselines = load_baselines()

    # Get current quality metrics
    current_metrics = get_current_metrics()

    # Define progressive targets
    targets = define_progressive_targets(baselines, strict)

    # Check against targets
    results = check_progressive_targets(current_metrics, targets)

    # Display results
    display_results(results, targets)

    # Update baselines if requested and all targets pass
    if update_baselines and results.all_passed do
      update_baseline_metrics(current_metrics)
    end

    # Exit with appropriate code if enforcing targets
    if enforce_targets and not results.all_passed do
      Mix.shell().error("❌ Progressive quality targets not met!")
      exit({:shutdown, 1})
    else
      Mix.shell().info("✅ Progressive quality check completed")
    end
  end

  defp load_baselines do
    baseline_file = "quality_baseline.json"

    if File.exists?(baseline_file) do
      case File.read(baseline_file) |> Jason.decode() do
        {:ok, baselines} -> baselines
        _ -> %{}
      end
    else
      %{}
    end
  end

  defp get_current_metrics do
    # Run a simplified quality report to get current metrics
    {output, _} =
      System.cmd("mix", ["quality_report", "--format", "json"],
        stderr_to_stdout: true,
        env: [{"MIX_ENV", "test"}]
      )

    case Jason.decode(output) do
      {:ok, metrics} -> metrics
      _ -> %{}
    end
  end

  defp define_progressive_targets(baselines, strict) do
    base_targets = %{
      overall_score: %{
        minimum: 70,
        target: 85,
        excellent: 95
      },
      compilation_warnings: %{
        maximum: if(strict, do: 0, else: 5),
        target: 0
      },
      credo_issues: %{
        maximum: if(strict, do: 10, else: 50),
        target: 5
      },
      test_coverage: %{
        minimum: if(strict, do: 85, else: 70),
        target: 90,
        excellent: 95
      },
      test_failures: %{
        maximum: 0,
        target: 0
      }
    }

    # Adjust targets based on baseline improvements
    if Map.has_key?(baselines, "overall_score") do
      baseline_score = baselines["overall_score"]
      improvement_target = min(baseline_score + 2, 100)

      put_in(base_targets, [:overall_score, :progressive], improvement_target)
    else
      base_targets
    end
  end

  defp check_progressive_targets(metrics, targets) do
    checks = [
      check_overall_score(metrics, targets),
      check_compilation_warnings(metrics, targets),
      check_credo_issues(metrics, targets),
      check_test_coverage(metrics, targets),
      check_test_failures(metrics, targets)
    ]

    all_passed = Enum.all?(checks, & &1.passed)

    %{
      checks: checks,
      all_passed: all_passed,
      passed_count: Enum.count(checks, & &1.passed),
      total_count: length(checks)
    }
  end

  defp check_overall_score(metrics, targets) do
    current = metrics["overall_score"] || 0
    target = targets.overall_score

    %{
      name: "Overall Score",
      current: current,
      target: target.target,
      minimum: target.minimum,
      passed: current >= target.minimum,
      status:
        cond do
          current >= target.excellent -> :excellent
          current >= target.target -> :good
          current >= target.minimum -> :acceptable
          true -> :failing
        end
    }
  end

  defp check_compilation_warnings(metrics, targets) do
    current = get_in(metrics, ["compilation", "warnings"]) || 0
    target = targets.compilation_warnings

    %{
      name: "Compilation Warnings",
      current: current,
      target: target.target,
      maximum: target.maximum,
      passed: current <= target.maximum,
      status:
        if(current <= target.target,
          do: :excellent,
          else: if(current <= target.maximum, do: :acceptable, else: :failing)
        )
    }
  end

  defp check_credo_issues(metrics, targets) do
    current = get_in(metrics, ["code_quality", "credo", "total_issues"]) || 0
    target = targets.credo_issues

    %{
      name: "Credo Issues",
      current: current,
      target: target.target,
      maximum: target.maximum,
      passed: current <= target.maximum,
      status:
        if(current <= target.target,
          do: :excellent,
          else: if(current <= target.maximum, do: :acceptable, else: :failing)
        )
    }
  end

  defp check_test_coverage(metrics, targets) do
    current = get_in(metrics, ["coverage", "percentage"]) || 0
    target = targets.test_coverage

    %{
      name: "Test Coverage",
      current: current,
      target: target.target,
      minimum: target.minimum,
      passed: current >= target.minimum,
      status:
        cond do
          current >= target.excellent -> :excellent
          current >= target.target -> :good
          current >= target.minimum -> :acceptable
          true -> :failing
        end
    }
  end

  defp check_test_failures(metrics, targets) do
    current = get_in(metrics, ["testing", "failed"]) || 0
    target = targets.test_failures

    %{
      name: "Test Failures",
      current: current,
      target: target.target,
      maximum: target.maximum,
      passed: current <= target.maximum,
      status: if(current <= target.target, do: :excellent, else: :failing)
    }
  end

  defp display_results(results, _targets) do
    Mix.shell().info("")
    Mix.shell().info("📊 Progressive Quality Check Results")
    Mix.shell().info("=" |> String.duplicate(50))

    Mix.shell().info("")
    Mix.shell().info("Summary: #{results.passed_count}/#{results.total_count} checks passed")

    for check <- results.checks do
      status_icon =
        case check.status do
          :excellent -> "🌟"
          :good -> "✅"
          :acceptable -> "⚠️ "
          :failing -> "❌"
        end

      target_info =
        cond do
          Map.has_key?(check, :minimum) -> "≥#{check.minimum}"
          Map.has_key?(check, :maximum) -> "≤#{check.maximum}"
          true -> "#{check.target}"
        end

      Mix.shell().info("#{status_icon} #{check.name}: #{check.current} (target: #{target_info})")
    end

    Mix.shell().info("")

    if results.all_passed do
      Mix.shell().info("🎉 All progressive quality targets met!")
    else
      Mix.shell().info("💡 Focus on improving failing checks for next iteration")
    end
  end

  defp update_baseline_metrics(metrics) do
    baseline_file = "quality_baseline.json"

    Mix.shell().info("📊 Updating quality baselines...")

    # Create simplified baseline from current metrics
    baseline = %{
      timestamp: DateTime.utc_now() |> DateTime.to_string(),
      overall_score: metrics["overall_score"],
      compilation: %{
        warnings: get_in(metrics, ["compilation", "warnings"])
      },
      code_quality: %{
        credo_issues: get_in(metrics, ["code_quality", "credo", "total_issues"])
      },
      testing: %{
        total_tests: get_in(metrics, ["testing", "total_tests"]),
        failed: get_in(metrics, ["testing", "failed"])
      },
      coverage: %{
        percentage: get_in(metrics, ["coverage", "percentage"])
      }
    }

    json = Jason.encode!(baseline, pretty: true)
    File.write!(baseline_file, json)

    Mix.shell().info("✅ Baselines updated in #{baseline_file}")
  end
end
