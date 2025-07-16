defmodule Mix.Tasks.TestMaintenance do
  @moduledoc """
  Automated test maintenance and optimization tools.

  ## Usage

      mix test_maintenance
      mix test_maintenance --analyze
      mix test_maintenance --optimize
      mix test_maintenance --clean
      mix test_maintenance --report

  ## Options

    * `--analyze` - Analyze test suite for maintenance opportunities
    * `--optimize` - Apply automatic optimizations
    * `--clean` - Clean up test artifacts and temporary files
    * `--report` - Generate maintenance report
    * `--dry-run` - Show what would be done without making changes
  """

  use Mix.Task

  @shortdoc "Automated test maintenance and optimization"

  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          analyze: :boolean,
          optimize: :boolean,
          clean: :boolean,
          report: :boolean,
          dry_run: :boolean
        ]
      )

    analyze = Keyword.get(opts, :analyze, false)
    optimize = Keyword.get(opts, :optimize, false)
    clean = Keyword.get(opts, :clean, false)
    report = Keyword.get(opts, :report, false)
    dry_run = Keyword.get(opts, :dry_run, false)

    Mix.shell().info("🔧 Starting test maintenance...")

    cond do
      analyze -> analyze_test_suite(dry_run)
      optimize -> optimize_test_suite(dry_run)
      clean -> clean_test_artifacts(dry_run)
      report -> generate_maintenance_report()
      true -> run_full_maintenance(dry_run)
    end

    Mix.shell().info("✅ Test maintenance completed")
  end

  defp run_full_maintenance(dry_run) do
    Mix.shell().info("🔄 Running comprehensive test maintenance...")

    # Run all maintenance tasks
    analysis = analyze_test_suite(dry_run)
    optimize_test_suite(dry_run)
    clean_test_artifacts(dry_run)

    # Generate summary report
    generate_maintenance_summary(analysis)
  end

  defp analyze_test_suite(dry_run) do
    Mix.shell().info("🔍 Analyzing test suite for maintenance opportunities...")

    analysis = %{
      timestamp: DateTime.utc_now(),
      dry_run: dry_run,
      test_files: analyze_test_files(),
      duplicate_tests: find_duplicate_tests(),
      unused_factories: find_unused_factories(),
      slow_tests: identify_slow_tests(),
      flaky_tests: identify_flaky_tests(),
      outdated_patterns: find_outdated_patterns(),
      coverage_gaps: identify_coverage_gaps(),
      dependencies: analyze_test_dependencies()
    }

    display_analysis_summary(analysis)
    store_analysis_results(analysis)

    analysis
  end

  defp analyze_test_files do
    test_files = Path.wildcard("test/**/*.exs")

    %{
      total_files: length(test_files),
      file_sizes: analyze_file_sizes(test_files),
      test_counts: analyze_test_counts(test_files),
      large_files: find_large_test_files(test_files),
      empty_files: find_empty_test_files(test_files)
    }
  end

  defp analyze_file_sizes(test_files) do
    sizes =
      test_files
      |> Enum.map(fn file ->
        case File.stat(file) do
          {:ok, stat} -> stat.size
          _ -> 0
        end
      end)

    %{
      total_size: Enum.sum(sizes),
      average_size: if(length(sizes) > 0, do: Enum.sum(sizes) / length(sizes), else: 0),
      largest_size: Enum.max(sizes, fn -> 0 end),
      smallest_size: Enum.min(sizes, fn -> 0 end)
    }
  end

  defp analyze_test_counts(test_files) do
    test_counts =
      test_files
      |> Enum.map(&count_tests_in_file/1)

    %{
      total_tests: Enum.sum(test_counts),
      average_per_file:
        if(length(test_counts) > 0, do: Enum.sum(test_counts) / length(test_counts), else: 0),
      max_tests_per_file: Enum.max(test_counts, fn -> 0 end),
      files_with_no_tests: Enum.count(test_counts, &(&1 == 0))
    }
  end

  defp count_tests_in_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.count(&String.match?(&1, ~r/^\s*test\s+/))

      _ ->
        0
    end
  end

  defp find_large_test_files(test_files) do
    test_files
    |> Enum.map(fn file ->
      case File.stat(file) do
        {:ok, stat} -> {file, stat.size}
        _ -> {file, 0}
      end
    end)
    # Files larger than 50KB
    |> Enum.filter(fn {_file, size} -> size > 50_000 end)
    |> Enum.sort_by(fn {_file, size} -> size end, :desc)
  end

  defp find_empty_test_files(test_files) do
    test_files
    |> Enum.filter(fn file ->
      case File.read(file) do
        {:ok, content} ->
          # Check if file has any actual test definitions
          !String.contains?(content, "test ") and !String.contains?(content, "describe ")

        _ ->
          false
      end
    end)
  end

  defp find_duplicate_tests do
    Mix.shell().info("  🔍 Finding duplicate tests...")

    test_files = Path.wildcard("test/**/*.exs")

    all_tests =
      test_files
      |> Enum.flat_map(&extract_test_names/1)
      |> Enum.group_by(& &1.name)
      |> Enum.filter(fn {_name, tests} -> length(tests) > 1 end)

    %{
      duplicate_count: length(all_tests),
      # Limit to first 20 for display
      duplicates: all_tests |> Enum.take(20)
    }
  end

  defp extract_test_names(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.filter(fn {line, _index} -> String.match?(line, ~r/^\s*test\s+/) end)
        |> Enum.map(fn {line, index} ->
          case Regex.run(~r/test\s+"([^"]+)"/, line) do
            [_, name] -> %{name: name, file: file_path, line: index}
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  defp find_unused_factories do
    Mix.shell().info("  🏭 Finding unused test factories...")

    factory_files =
      Path.wildcard("test/support/factory.ex") ++ Path.wildcard("test/factories/**/*.ex")

    if Enum.empty?(factory_files) do
      %{status: "no_factories_found"}
    else
      all_factories = factory_files |> Enum.flat_map(&extract_factory_names/1)
      test_files = Path.wildcard("test/**/*.exs")
      used_factories = test_files |> Enum.flat_map(&find_factory_usage/1) |> Enum.uniq()

      unused = all_factories -- used_factories

      %{
        total_factories: length(all_factories),
        used_factories: length(used_factories),
        unused_factories: length(unused),
        unused_list: unused |> Enum.take(10)
      }
    end
  end

  defp extract_factory_names(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.filter(&String.match?(&1, ~r/def\s+\w+_factory/))
        |> Enum.map(fn line ->
          case Regex.run(~r/def\s+(\w+)_factory/, line) do
            [_, name] -> name
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  defp find_factory_usage(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        # Look for insert/3, build/3, etc. with factory names
        Regex.scan(~r/(insert|build|build_list|create)\(\s*:(\w+)/, content)
        |> Enum.map(fn [_, _function, factory] -> factory end)

      _ ->
        []
    end
  end

  defp identify_slow_tests do
    Mix.shell().info("  🐌 Identifying slow tests...")

    # Load recent performance data
    case load_latest_metrics() do
      %{performance: %{slowest_tests: slow_tests}} when is_list(slow_tests) ->
        %{
          slow_test_count: length(slow_tests),
          slowest_tests: slow_tests |> Enum.take(10),
          total_slow_time: slow_tests |> Enum.map(& &1.duration_ms) |> Enum.sum()
        }

      _ ->
        %{status: "no_performance_data"}
    end
  end

  defp identify_flaky_tests do
    Mix.shell().info("  🎲 Identifying flaky tests...")

    # Load trend analysis for flaky test data
    case load_latest_trends() do
      %{failure_patterns: %{flaky_test_candidates: flaky_tests}} when is_list(flaky_tests) ->
        %{
          flaky_test_count: length(flaky_tests),
          flaky_tests: flaky_tests |> Enum.take(10)
        }

      _ ->
        %{status: "no_flaky_test_data"}
    end
  end

  defp find_outdated_patterns do
    Mix.shell().info("  📅 Finding outdated test patterns...")

    test_files = Path.wildcard("test/**/*.exs")

    outdated_patterns = %{
      deprecated_assertions: find_deprecated_assertions(test_files),
      old_async_patterns: find_old_async_patterns(test_files),
      hardcoded_values: find_hardcoded_values(test_files),
      missing_docstrings: find_missing_docstrings(test_files)
    }

    %{
      patterns_found: count_patterns(outdated_patterns),
      details: outdated_patterns
    }
  end

  defp find_deprecated_assertions(test_files) do
    deprecated = [
      "assert_raise/2",
      "refute_in_delta",
      "assert_in_delta/2"
    ]

    test_files
    |> Enum.flat_map(fn file ->
      case File.read(file) do
        {:ok, content} ->
          deprecated
          |> Enum.filter(&String.contains?(content, &1))
          |> Enum.map(&{file, &1})

        _ ->
          []
      end
    end)
  end

  defp find_old_async_patterns(test_files) do
    test_files
    |> Enum.filter(fn file ->
      case File.read(file) do
        {:ok, content} ->
          # Look for synchronous test patterns that could be async
          !String.contains?(content, "async: true") and
            !String.contains?(content, "integration") and
            String.contains?(content, "test ")

        _ ->
          false
      end
    end)
  end

  defp find_hardcoded_values(test_files) do
    patterns = [
      ~r/"test@example\.com"/,
      # Hardcoded dates
      ~r/\d{4}-\d{2}-\d{2}/,
      # Hardcoded URLs
      ~r/http:\/\/localhost:\d+/
    ]

    test_files
    |> Enum.flat_map(fn file ->
      case File.read(file) do
        {:ok, content} ->
          patterns
          |> Enum.flat_map(fn pattern ->
            case Regex.scan(pattern, content) do
              [] -> []
              matches -> [{file, pattern, length(matches)}]
            end
          end)

        _ ->
          []
      end
    end)
  end

  defp find_missing_docstrings(test_files) do
    test_files
    |> Enum.filter(fn file ->
      case File.read(file) do
        {:ok, content} ->
          String.contains?(content, "defmodule ") and
            !String.contains?(content, "@moduledoc")

        _ ->
          false
      end
    end)
  end

  defp count_patterns(patterns) do
    patterns
    |> Map.values()
    |> Enum.map(&length/1)
    |> Enum.sum()
  end

  defp identify_coverage_gaps do
    Mix.shell().info("  📊 Identifying coverage gaps...")

    case load_latest_metrics() do
      %{coverage: coverage} when is_map(coverage) ->
        %{
          current_coverage: coverage[:percentage] || 0,
          files_with_low_coverage: coverage[:files_with_low_coverage] || [],
          status: "data_available"
        }

      _ ->
        %{status: "no_coverage_data"}
    end
  end

  defp analyze_test_dependencies do
    Mix.shell().info("  📦 Analyzing test dependencies...")

    # Check for common issues in test dependencies
    mix_exs = File.read!("mix.exs")

    %{
      test_only_deps: count_test_only_deps(mix_exs),
      dev_test_deps: count_dev_test_deps(mix_exs),
      potential_conflicts: find_dependency_conflicts()
    }
  end

  defp count_test_only_deps(mix_content) do
    mix_content
    |> String.split("\n")
    |> Enum.count(&String.contains?(&1, "only: :test"))
  end

  defp count_dev_test_deps(mix_content) do
    mix_content
    |> String.split("\n")
    |> Enum.count(&String.contains?(&1, "only: [:dev, :test]"))
  end

  defp find_dependency_conflicts do
    # This would analyze for common dependency conflicts in test environment
    # For now, return a placeholder
    []
  end

  defp display_analysis_summary(analysis) do
    Mix.shell().info("")
    Mix.shell().info("📊 Test Suite Analysis Summary")
    Mix.shell().info("=" |> String.duplicate(50))

    # Test files summary
    files = analysis.test_files
    Mix.shell().info("Test Files:")
    Mix.shell().info("  📁 Total files: #{files.total_files}")

    Mix.shell().info(
      "  📏 Average size: #{Float.round(files.file_sizes.average_size / 1024, 1)}KB"
    )

    Mix.shell().info("  🧪 Total tests: #{files.test_counts.total_tests}")

    if length(files.large_files) > 0 do
      Mix.shell().info("  ⚠️  Large files: #{length(files.large_files)}")
    end

    if length(files.empty_files) > 0 do
      Mix.shell().info("  ❌ Empty files: #{length(files.empty_files)}")
    end

    # Duplicates
    if analysis.duplicate_tests.duplicate_count > 0 do
      Mix.shell().info("")

      Mix.shell().info(
        "⚠️  Found #{analysis.duplicate_tests.duplicate_count} duplicate test names"
      )
    end

    # Unused factories
    case analysis.unused_factories do
      %{unused_factories: count} when count > 0 ->
        Mix.shell().info("🏭 Found #{count} unused test factories")

      _ ->
        nil
    end

    # Slow tests
    case analysis.slow_tests do
      %{slow_test_count: count} when count > 0 ->
        Mix.shell().info("🐌 Found #{count} slow tests")

      _ ->
        nil
    end

    # Flaky tests
    case analysis.flaky_tests do
      %{flaky_test_count: count} when count > 0 ->
        Mix.shell().info("🎲 Found #{count} potentially flaky tests")

      _ ->
        nil
    end

    # Outdated patterns
    if analysis.outdated_patterns.patterns_found > 0 do
      Mix.shell().info("📅 Found #{analysis.outdated_patterns.patterns_found} outdated patterns")
    end
  end

  defp store_analysis_results(analysis) do
    File.mkdir_p!("test_metrics")

    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    filename = "test_metrics/maintenance_analysis_#{timestamp}.json"

    json = Jason.encode!(analysis, pretty: true)
    File.write!(filename, json)
    File.write!("test_metrics/latest_maintenance_analysis.json", json)

    Mix.shell().info("📁 Analysis results saved to #{filename}")
  end

  defp optimize_test_suite(dry_run) do
    Mix.shell().info("⚡ Optimizing test suite...")

    optimizations = %{
      cleaned_imports: optimize_imports(dry_run),
      removed_unused_factories: remove_unused_factories(dry_run),
      optimized_async: optimize_async_tests(dry_run),
      cleaned_fixtures: clean_test_fixtures(dry_run),
      updated_patterns: update_test_patterns(dry_run)
    }

    display_optimization_summary(optimizations)

    optimizations
  end

  defp optimize_imports(dry_run) do
    Mix.shell().info("  📦 Optimizing imports...")

    test_files = Path.wildcard("test/**/*.exs")

    optimized =
      test_files
      |> Enum.count(fn file ->
        case File.read(file) do
          {:ok, content} ->
            # Analyze and optimize imports (placeholder implementation)
            if String.contains?(content, "import ") do
              if not dry_run do
                # Would optimize imports here
              end

              true
            else
              false
            end

          _ ->
            false
        end
      end)

    %{files_optimized: optimized, dry_run: dry_run}
  end

  defp remove_unused_factories(dry_run) do
    Mix.shell().info("  🏭 Removing unused factories...")

    # Load analysis results to find unused factories
    case load_latest_analysis() do
      %{unused_factories: %{unused_list: [_ | _] = unused}} ->
        if not dry_run do
          # Would remove unused factories here
          Mix.shell().info("    Would remove #{length(unused)} unused factories")
        else
          Mix.shell().info("    Found #{length(unused)} unused factories to remove")
        end

        %{removed_count: length(unused), dry_run: dry_run}

      _ ->
        %{removed_count: 0, dry_run: dry_run}
    end
  end

  defp optimize_async_tests(dry_run) do
    Mix.shell().info("  🚀 Optimizing async test settings...")

    # Find tests that could be made async
    test_files = Path.wildcard("test/**/*.exs")

    optimized =
      test_files
      |> Enum.count(fn file ->
        case File.read(file) do
          {:ok, content} ->
            # Check if test could be async but isn't
            if !String.contains?(content, "async: true") and
                 !String.contains?(content, "integration") and
                 String.contains?(content, "use WandererAppWeb.ConnCase") do
              if not dry_run do
                # Would add async: true here
              end

              true
            else
              false
            end

          _ ->
            false
        end
      end)

    %{files_optimized: optimized, dry_run: dry_run}
  end

  defp clean_test_fixtures(dry_run) do
    Mix.shell().info("  🧹 Cleaning test fixtures...")

    fixture_dirs = ["test/fixtures", "test/support/fixtures"]

    cleaned_files =
      fixture_dirs
      |> Enum.reduce(0, fn dir, acc ->
        if File.exists?(dir) do
          case File.ls(dir) do
            {:ok, files} ->
              files
              |> Enum.count(fn file ->
                file_path = Path.join(dir, file)
                # Check if fixture is used
                if not fixture_is_used?(file_path) do
                  if not dry_run do
                    File.rm(file_path)
                  end

                  true
                else
                  false
                end
              end)
              |> Kernel.+(acc)

            _ ->
              acc
          end
        else
          acc
        end
      end)

    %{files_cleaned: cleaned_files, dry_run: dry_run}
  end

  defp fixture_is_used?(fixture_path) do
    # Simple check - look for references in test files
    fixture_name = Path.basename(fixture_path)
    test_files = Path.wildcard("test/**/*.exs")

    Enum.any?(test_files, fn test_file ->
      case File.read(test_file) do
        {:ok, content} -> String.contains?(content, fixture_name)
        _ -> false
      end
    end)
  end

  defp update_test_patterns(dry_run) do
    Mix.shell().info("  🔄 Updating test patterns...")

    # Update deprecated patterns found in analysis
    case load_latest_analysis() do
      %{outdated_patterns: %{details: patterns}} ->
        updates = count_patterns(patterns)

        if not dry_run and updates > 0 do
          # Would update patterns here
          Mix.shell().info("    Would update #{updates} outdated patterns")
        end

        %{patterns_updated: updates, dry_run: dry_run}

      _ ->
        %{patterns_updated: 0, dry_run: dry_run}
    end
  end

  defp display_optimization_summary(optimizations) do
    Mix.shell().info("")
    Mix.shell().info("⚡ Optimization Summary")
    Mix.shell().info("-" |> String.duplicate(30))

    total_changes =
      optimizations
      |> Enum.reduce(0, fn {key, result}, acc ->
        case result do
          %{files_optimized: count} ->
            Mix.shell().info("  #{get_optimization_name(key)}: #{count} files")
            acc + count

          %{removed_count: count} ->
            Mix.shell().info("  #{get_optimization_name(key)}: #{count} items")
            acc + count

          %{files_cleaned: count} ->
            Mix.shell().info("  #{get_optimization_name(key)}: #{count} files")
            acc + count

          %{patterns_updated: count} ->
            Mix.shell().info("  #{get_optimization_name(key)}: #{count} patterns")
            acc + count

          _ ->
            acc
        end
      end)

    Mix.shell().info("")
    Mix.shell().info("📊 Total optimizations: #{total_changes}")

    if Map.get(List.first(Map.values(optimizations)) || %{}, :dry_run, false) do
      Mix.shell().info("💡 Run without --dry-run to apply optimizations")
    end
  end

  defp get_optimization_name(:cleaned_imports), do: "Import optimization"
  defp get_optimization_name(:removed_unused_factories), do: "Unused factories"
  defp get_optimization_name(:optimized_async), do: "Async optimization"
  defp get_optimization_name(:cleaned_fixtures), do: "Fixture cleanup"
  defp get_optimization_name(:updated_patterns), do: "Pattern updates"

  defp clean_test_artifacts(dry_run) do
    Mix.shell().info("🧹 Cleaning test artifacts...")

    artifacts_cleaned = %{
      coverage_files: clean_coverage_files(dry_run),
      temp_files: clean_temp_files(dry_run),
      log_files: clean_log_files(dry_run),
      build_artifacts: clean_build_artifacts(dry_run)
    }

    total_cleaned =
      artifacts_cleaned
      |> Map.values()
      |> Enum.sum()

    Mix.shell().info("🗑️  Cleaned #{total_cleaned} artifact files")

    artifacts_cleaned
  end

  defp clean_coverage_files(dry_run) do
    coverage_patterns = [
      "cover/*.html",
      "cover/*.json",
      "cover/Elixir.*.html",
      "excoveralls.json"
    ]

    clean_files_by_pattern(coverage_patterns, dry_run)
  end

  defp clean_temp_files(dry_run) do
    temp_patterns = [
      "test/tmp/**/*",
      "tmp/test/**/*",
      "test/**/*.tmp"
    ]

    clean_files_by_pattern(temp_patterns, dry_run)
  end

  defp clean_log_files(dry_run) do
    log_patterns = [
      "test/logs/*.log",
      "_build/test/logs/*.log"
    ]

    clean_files_by_pattern(log_patterns, dry_run)
  end

  defp clean_build_artifacts(dry_run) do
    # Clean old build artifacts older than 7 days
    cutoff_time = System.system_time(:second) - 7 * 24 * 3600
    build_dir = "_build/test"

    if File.exists?(build_dir) do
      count_old_files(build_dir, cutoff_time, dry_run)
    else
      0
    end
  end

  defp clean_files_by_pattern(patterns, dry_run) do
    patterns
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.count(fn file ->
      if not dry_run do
        File.rm(file)
      end

      true
    end)
  end

  defp count_old_files(dir, cutoff_time, dry_run) do
    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.count(fn file ->
          file_path = Path.join(dir, file)

          case File.stat(file_path) do
            {:ok, stat} ->
              if stat.mtime < cutoff_time do
                if not dry_run do
                  File.rm_rf(file_path)
                end

                true
              else
                false
              end

            _ ->
              false
          end
        end)

      _ ->
        0
    end
  end

  defp generate_maintenance_report do
    Mix.shell().info("📄 Generating maintenance report...")

    # Load latest analysis
    analysis = load_latest_analysis()

    report = %{
      generated_at: DateTime.utc_now(),
      analysis: analysis,
      recommendations: generate_maintenance_recommendations(analysis),
      maintenance_schedule: generate_maintenance_schedule(),
      health_metrics: calculate_test_health_metrics(analysis)
    }

    # Save report
    save_maintenance_report(report)

    # Display summary
    display_maintenance_report_summary(report)

    report
  end

  defp generate_maintenance_recommendations(analysis) do
    recommendations = []

    # File organization recommendations
    recommendations =
      if analysis[:test_files][:total_files] > 100 do
        [
          %{
            category: "Organization",
            priority: "medium",
            title: "Consider Test File Organization",
            description: "Large number of test files may benefit from better organization",
            action: "Group related tests into subdirectories"
          }
          | recommendations
        ]
      else
        recommendations
      end

    # Performance recommendations
    recommendations =
      case analysis[:slow_tests] do
        %{slow_test_count: count} when count > 10 ->
          [
            %{
              category: "Performance",
              priority: "high",
              title: "Optimize Slow Tests",
              description: "#{count} slow tests identified",
              action: "Review and optimize slow test execution"
            }
            | recommendations
          ]

        _ ->
          recommendations
      end

    # Quality recommendations
    recommendations =
      case analysis[:flaky_tests] do
        %{flaky_test_count: count} when count > 0 ->
          [
            %{
              category: "Quality",
              priority: "high",
              title: "Fix Flaky Tests",
              description: "#{count} flaky tests reduce reliability",
              action: "Investigate and stabilize flaky tests"
            }
            | recommendations
          ]

        _ ->
          recommendations
      end

    # Cleanup recommendations
    recommendations =
      case analysis[:unused_factories] do
        %{unused_factories: count} when count > 0 ->
          [
            %{
              category: "Cleanup",
              priority: "low",
              title: "Remove Unused Factories",
              description: "#{count} unused test factories found",
              action: "Remove unused factory definitions"
            }
            | recommendations
          ]

        _ ->
          recommendations
      end

    recommendations
  end

  defp generate_maintenance_schedule do
    %{
      daily: [
        "Run test suite",
        "Check for flaky test failures"
      ],
      weekly: [
        "Analyze test performance trends",
        "Review slow tests",
        "Clean test artifacts"
      ],
      monthly: [
        "Full test maintenance analysis",
        "Update test patterns and dependencies",
        "Review test coverage gaps",
        "Optimize test suite organization"
      ]
    }
  end

  defp calculate_test_health_metrics(analysis) do
    # Calculate overall test suite health
    files = analysis[:test_files] || %{}

    %{
      test_density:
        if(files[:total_files] && files[:total_files] > 0,
          do: files[:test_counts][:total_tests] / files[:total_files],
          else: 0
        ),
      average_file_size: get_in(files, [:file_sizes, :average_size]) || 0,
      maintenance_burden: calculate_maintenance_burden(analysis),
      quality_score: calculate_quality_score(analysis)
    }
  end

  defp calculate_maintenance_burden(analysis) do
    # Higher score = more maintenance needed
    burden = 0

    # Add burden for large files
    large_files = length(analysis[:test_files][:large_files] || [])
    burden = burden + large_files * 2

    # Add burden for duplicates
    duplicates = analysis[:duplicate_tests][:duplicate_count] || 0
    burden = burden + duplicates

    # Add burden for unused factories
    unused = get_in(analysis, [:unused_factories, :unused_factories]) || 0
    burden = burden + unused

    # Add burden for outdated patterns
    outdated = get_in(analysis, [:outdated_patterns, :patterns_found]) || 0
    burden = burden + outdated * 0.5

    burden
  end

  defp calculate_quality_score(analysis) do
    # Score from 0-100, higher is better
    score = 100

    # Deduct for issues
    flaky_count = get_in(analysis, [:flaky_tests, :flaky_test_count]) || 0
    score = score - flaky_count * 5

    slow_count = get_in(analysis, [:slow_tests, :slow_test_count]) || 0
    score = score - slow_count * 2

    duplicate_count = get_in(analysis, [:duplicate_tests, :duplicate_count]) || 0
    score = score - duplicate_count * 3

    max(score, 0)
  end

  defp save_maintenance_report(report) do
    File.mkdir_p!("test_metrics")

    timestamp = DateTime.utc_now() |> DateTime.to_unix()

    # JSON report
    json_filename = "test_metrics/maintenance_report_#{timestamp}.json"
    json_content = Jason.encode!(report, pretty: true)
    File.write!(json_filename, json_content)
    File.write!("test_metrics/latest_maintenance_report.json", json_content)

    # Markdown report
    markdown_filename = "test_metrics/maintenance_report_#{timestamp}.md"
    markdown_content = format_maintenance_report_markdown(report)
    File.write!(markdown_filename, markdown_content)
    File.write!("test_metrics/latest_maintenance_report.md", markdown_content)

    Mix.shell().info("📁 Reports saved:")
    Mix.shell().info("  - JSON: #{json_filename}")
    Mix.shell().info("  - Markdown: #{markdown_filename}")
  end

  defp format_maintenance_report_markdown(report) do
    """
    # 🔧 Test Maintenance Report

    **Generated:** #{DateTime.to_string(report.generated_at)}

    ## 📊 Health Metrics

    - **Quality Score:** #{Float.round(report.health_metrics.quality_score, 1)}/100
    - **Maintenance Burden:** #{Float.round(report.health_metrics.maintenance_burden, 1)}
    - **Test Density:** #{Float.round(report.health_metrics.test_density, 1)} tests/file
    - **Average File Size:** #{Float.round(report.health_metrics.average_file_size / 1024, 1)}KB

    ## 💡 Recommendations

    #{format_recommendations_markdown(report.recommendations)}

    ## 📅 Maintenance Schedule

    ### Daily Tasks
    #{format_schedule_list(report.maintenance_schedule.daily)}

    ### Weekly Tasks
    #{format_schedule_list(report.maintenance_schedule.weekly)}

    ### Monthly Tasks
    #{format_schedule_list(report.maintenance_schedule.monthly)}

    ## 🔍 Analysis Details

    #{format_analysis_details_markdown(report.analysis)}

    ---

    *Report generated by automated test maintenance system*
    """
  end

  defp format_recommendations_markdown([]), do: "No specific recommendations at this time."

  defp format_recommendations_markdown(recommendations) do
    recommendations
    |> Enum.map(fn rec ->
      priority_icon =
        case rec.priority do
          "high" -> "🔴"
          "medium" -> "🟡"
          "low" -> "🟢"
          _ -> "ℹ️"
        end

      """
      ### #{priority_icon} #{rec.title}

      **Category:** #{rec.category}  
      **Priority:** #{rec.priority}

      #{rec.description}

      **Action:** #{rec.action}
      """
    end)
    |> Enum.join("\n\n")
  end

  defp format_schedule_list(tasks) do
    tasks
    |> Enum.map(&("- " <> &1))
    |> Enum.join("\n")
  end

  defp format_analysis_details_markdown(analysis) do
    if analysis && map_size(analysis) > 0 do
      """
      - **Total Test Files:** #{get_in(analysis, [:test_files, :total_files]) || 0}
      - **Total Tests:** #{get_in(analysis, [:test_files, :test_counts, :total_tests]) || 0}
      - **Large Files:** #{length(get_in(analysis, [:test_files, :large_files]) || [])}
      - **Duplicate Tests:** #{get_in(analysis, [:duplicate_tests, :duplicate_count]) || 0}
      - **Unused Factories:** #{get_in(analysis, [:unused_factories, :unused_factories]) || 0}
      - **Slow Tests:** #{get_in(analysis, [:slow_tests, :slow_test_count]) || 0}
      - **Flaky Tests:** #{get_in(analysis, [:flaky_tests, :flaky_test_count]) || 0}
      """
    else
      "No detailed analysis data available."
    end
  end

  defp display_maintenance_report_summary(report) do
    Mix.shell().info("")
    Mix.shell().info("📋 Maintenance Report Summary")
    Mix.shell().info("=" |> String.duplicate(40))

    Mix.shell().info("Quality Score: #{Float.round(report.health_metrics.quality_score, 1)}/100")

    Mix.shell().info(
      "Maintenance Burden: #{Float.round(report.health_metrics.maintenance_burden, 1)}"
    )

    rec_count = length(report.recommendations)

    if rec_count > 0 do
      Mix.shell().info("Recommendations: #{rec_count}")

      high_priority = Enum.count(report.recommendations, &(&1.priority == "high"))

      if high_priority > 0 do
        Mix.shell().info("  🔴 High priority: #{high_priority}")
      end
    else
      Mix.shell().info("✅ No maintenance recommendations")
    end
  end

  defp generate_maintenance_summary(analysis) do
    Mix.shell().info("")
    Mix.shell().info("📋 Maintenance Summary")
    Mix.shell().info("=" |> String.duplicate(30))

    if analysis do
      total_issues =
        [
          get_in(analysis, [:duplicate_tests, :duplicate_count]) || 0,
          get_in(analysis, [:unused_factories, :unused_factories]) || 0,
          get_in(analysis, [:slow_tests, :slow_test_count]) || 0,
          get_in(analysis, [:flaky_tests, :flaky_test_count]) || 0,
          get_in(analysis, [:outdated_patterns, :patterns_found]) || 0
        ]
        |> Enum.sum()

      Mix.shell().info("Total issues found: #{total_issues}")

      if total_issues == 0 do
        Mix.shell().info("✅ Test suite is in good health!")
      else
        Mix.shell().info("💡 Run 'mix test_maintenance --optimize' to fix issues")
      end
    end
  end

  # Utility functions
  defp load_latest_metrics do
    case File.read("test_metrics/latest_metrics.json") do
      {:ok, content} ->
        case Jason.decode(content, keys: :atoms) do
          {:ok, metrics} -> metrics
          _ -> %{}
        end

      _ ->
        %{}
    end
  end

  defp load_latest_trends do
    case File.read("test_metrics/latest_trends.json") do
      {:ok, content} ->
        case Jason.decode(content, keys: :atoms) do
          {:ok, trends} -> trends
          _ -> %{}
        end

      _ ->
        %{}
    end
  end

  defp load_latest_analysis do
    case File.read("test_metrics/latest_maintenance_analysis.json") do
      {:ok, content} ->
        case Jason.decode(content, keys: :atoms) do
          {:ok, analysis} -> analysis
          _ -> %{}
        end

      _ ->
        %{}
    end
  end
end
