defmodule Mix.Tasks.Test.OptimizeSimple do
  @moduledoc """
  Analyzes and optimizes test suite execution.

  ## Usage

      mix test.optimize_simple
      mix test.optimize_simple --report optimization_report.json
  """

  use Mix.Task

  alias WandererApp.TestOptimization

  @shortdoc "Optimize test suite execution"

  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [report: :string],
        aliases: [r: :report]
      )

    Mix.shell().info("🔍 Analyzing test suite for optimization opportunities...")

    # Analyze test suite
    analysis = TestOptimization.analyze_suite()

    # Display summary
    display_summary(analysis)

    # Generate report if requested
    if report_file = opts[:report] do
      generate_report(analysis, report_file)
    end
  end

  defp display_summary(analysis) do
    Mix.shell().info("\n📋 Test Suite Analysis Summary")
    Mix.shell().info("=" |> String.duplicate(50))
    Mix.shell().info("Total test files: #{analysis.total_files}")

    async_safe = Enum.count(analysis.async_safe, & &1.async_safe)
    async_enabled = Enum.count(analysis.async_safe, & &1.async)

    Mix.shell().info("Async-safe files: #{async_safe}")
    Mix.shell().info("Async-enabled files: #{async_enabled}")

    if length(analysis.recommendations) > 0 do
      Mix.shell().info("\n💡 Found #{length(analysis.recommendations)} optimization opportunities")
      Mix.shell().info("Run with --report flag to generate detailed report")
    else
      Mix.shell().info("\n✅ Test suite is well optimized!")
    end
  end

  defp generate_report(analysis, report_file) do
    report = %{
      timestamp: DateTime.utc_now(),
      summary: %{
        total_files: analysis.total_files,
        async_safe: Enum.count(analysis.async_safe, & &1.async_safe),
        async_enabled: Enum.count(analysis.async_safe, & &1.async),
        recommendations: length(analysis.recommendations)
      },
      analysis: analysis
    }

    json = Jason.encode!(report, pretty: true)
    File.write!(report_file, json)

    Mix.shell().info("\n📄 Report written to: #{report_file}")
  end
end
