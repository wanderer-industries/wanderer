defmodule Mix.Tasks.Quality.UpdateBaselines do
  @moduledoc """
  Updates quality baseline metrics for progressive improvement tracking.

  ## Usage

      mix quality.update_baselines
      mix quality.update_baselines --force

  ## Options

    * `--force` - Force update even if quality has decreased
  """

  use Mix.Task

  @shortdoc "Update quality baseline metrics"

  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [force: :boolean]
      )

    force = Keyword.get(opts, :force, false)

    Mix.shell().info("📊 Updating quality baselines...")

    # Get current quality metrics
    current_metrics = get_current_metrics()

    # Load existing baselines if they exist
    existing_baselines = load_existing_baselines()

    # Check if update should proceed
    should_update = force or should_update_baselines?(current_metrics, existing_baselines)

    if should_update do
      # Update baselines
      update_baselines(current_metrics)
      Mix.shell().info("✅ Quality baselines updated successfully")
    else
      Mix.shell().info("⚠️  Quality has decreased. Use --force to update anyway")
      exit({:shutdown, 1})
    end
  end

  defp get_current_metrics do
    # Run quality report to get current metrics
    {output, exit_code} =
      System.cmd("mix", ["quality_report", "--format", "json"],
        stderr_to_stdout: true,
        env: [{"MIX_ENV", "test"}]
      )

    if exit_code != 0 do
      Mix.shell().error("Failed to generate quality report")
      exit({:shutdown, 1})
    end

    case Jason.decode(output) do
      {:ok, metrics} ->
        metrics

      {:error, _} ->
        Mix.shell().error("Failed to parse quality report JSON")
        exit({:shutdown, 1})
    end
  end

  defp load_existing_baselines do
    baseline_file = "quality_baseline.json"

    if File.exists?(baseline_file) do
      case File.read(baseline_file) |> Jason.decode() do
        {:ok, baselines} -> baselines
        _ -> nil
      end
    else
      nil
    end
  end

  defp should_update_baselines?(_current, nil), do: true

  defp should_update_baselines?(current, existing) do
    current_score = current["overall_score"] || 0
    existing_score = existing["overall_score"] || 0

    current_score >= existing_score
  end

  defp update_baselines(metrics) do
    baseline_file = "quality_baseline.json"

    # Create comprehensive baseline from current metrics
    baseline = %{
      timestamp: DateTime.utc_now() |> DateTime.to_string(),
      overall_score: metrics["overall_score"],
      component_scores: metrics["component_scores"],
      compilation: extract_compilation_baseline(metrics),
      code_quality: extract_code_quality_baseline(metrics),
      testing: extract_testing_baseline(metrics),
      coverage: extract_coverage_baseline(metrics),
      security: extract_security_baseline(metrics),
      dependencies: extract_dependencies_baseline(metrics)
    }

    json = Jason.encode!(baseline, pretty: true)
    File.write!(baseline_file, json)

    # Also create a timestamped backup
    backup_file = "quality_baselines/baseline_#{DateTime.utc_now() |> DateTime.to_unix()}.json"
    File.mkdir_p!("quality_baselines")
    File.write!(backup_file, json)

    Mix.shell().info("📄 Baseline saved to #{baseline_file}")
    Mix.shell().info("💾 Backup saved to #{backup_file}")
  end

  defp extract_compilation_baseline(metrics) do
    compilation = metrics["compilation"] || %{}

    %{
      warnings: compilation["warnings"] || 0,
      errors: compilation["errors"] || 0,
      status: compilation["status"] || "unknown"
    }
  end

  defp extract_code_quality_baseline(metrics) do
    code_quality = metrics["code_quality"] || %{}
    credo = code_quality["credo"] || %{}
    dialyzer = code_quality["dialyzer"] || %{}

    %{
      credo: %{
        total_issues: credo["total_issues"] || 0,
        high_priority: credo["high_priority"] || 0,
        status: credo["status"] || "unknown"
      },
      dialyzer: %{
        errors: dialyzer["errors"] || 0,
        status: dialyzer["status"] || "unknown"
      }
    }
  end

  defp extract_testing_baseline(metrics) do
    testing = metrics["testing"] || %{}

    %{
      total_tests: testing["total_tests"] || 0,
      passed: testing["passed"] || 0,
      failed: testing["failed"] || 0,
      success_rate: testing["success_rate"] || 0,
      status: testing["status"] || "unknown"
    }
  end

  defp extract_coverage_baseline(metrics) do
    coverage = metrics["coverage"] || %{}

    %{
      percentage: coverage["percentage"] || 0,
      lines_covered: coverage["lines_covered"] || 0,
      lines_total: coverage["lines_total"] || 0,
      status: coverage["status"] || "unknown"
    }
  end

  defp extract_security_baseline(metrics) do
    security = metrics["security"] || %{}

    %{
      overall_status: security["overall_status"] || "unknown",
      deps_audit: security["deps_audit"] || %{},
      sobelow: security["sobelow"] || %{}
    }
  end

  defp extract_dependencies_baseline(metrics) do
    dependencies = metrics["dependencies"] || %{}

    %{
      total_deps: dependencies["total_deps"] || 0,
      outdated_deps: dependencies["outdated_deps"] || 0
    }
  end
end
