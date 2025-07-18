defmodule WandererApp.TestOptimization do
  @moduledoc """
  Utilities for optimizing test execution performance.

  Provides functionality for:
  - Parallel test execution management
  - Test dependency analysis
  - Smart test ordering
  - Resource pooling
  - Test isolation optimization
  """

  alias WandererApp.TestOptimization.{
    DependencyAnalyzer,
    ParallelExecutor,
    ResourcePool,
    TestOrderOptimizer
  }

  @doc """
  Analyzes test suite and provides optimization recommendations.
  """
  def analyze_suite(test_path \\ "test") do
    test_files = find_test_files(test_path)

    analysis = %{
      total_files: length(test_files),
      async_safe: analyze_async_safety(test_files),
      dependencies: DependencyAnalyzer.analyze(test_files),
      resource_usage: analyze_resource_usage(test_files),
      estimated_time: estimate_execution_time(test_files),
      recommendations: []
    }

    analysis
    |> add_async_recommendations()
    |> add_grouping_recommendations()
    |> add_parallel_recommendations()
  end

  @doc """
  Generates optimized test configuration.
  """
  def generate_config(analysis) do
    %{
      # Test grouping for optimal execution
      test_groups: generate_test_groups(analysis),

      # Parallel execution settings
      parallel_config: %{
        max_workers: optimal_worker_count(),
        # ms - tests faster than this should be async
        async_threshold: 100,
        resource_pools: generate_resource_pools(analysis)
      },

      # Test ordering for better cache utilization
      execution_order: TestOrderOptimizer.optimize(analysis),

      # Timeout configurations
      timeouts: %{
        default: 60_000,
        integration: 120_000,
        slow: 300_000
      }
    }
  end

  defp find_test_files(path) do
    Path.wildcard("#{path}/**/*_test.exs")
  end

  defp analyze_async_safety(test_files) do
    Enum.map(test_files, fn file ->
      content = File.read!(file)

      %{
        file: file,
        async: String.contains?(content, "async: true"),
        async_safe: is_async_safe?(content),
        shared_resources: detect_shared_resources(content)
      }
    end)
  end

  defp is_async_safe?(content) do
    # Check for common async-unsafe patterns
    unsafe_patterns = [
      ~r/Ecto\.Adapters\.SQL\.Sandbox\.mode.*:shared/,
      ~r/Process\.register/,
      ~r/Application\.put_env/,
      ~r/:ets\.new/,
      ~r/File\.write!/,
      ~r/System\.put_env/
    ]

    !Enum.any?(unsafe_patterns, &Regex.match?(&1, content))
  end

  defp detect_shared_resources(content) do
    resources = []

    # Database usage
    resources =
      if String.contains?(content, "Repo.") do
        ["database" | resources]
      else
        resources
      end

    # File system usage
    resources =
      if Regex.match?(~r/File\.(write|rm|mkdir)/, content) do
        ["filesystem" | resources]
      else
        resources
      end

    # External API mocks
    resources =
      if String.contains?(content, "Mock") do
        ["mocks" | resources]
      else
        resources
      end

    # Cache usage
    resources =
      if String.contains?(content, "Cache.") do
        ["cache" | resources]
      else
        resources
      end

    resources
  end

  defp analyze_resource_usage(test_files) do
    test_files
    |> Enum.map(fn file ->
      content = File.read!(file)

      %{
        file: file,
        database_queries: estimate_database_queries(content),
        factory_usage: count_factory_calls(content),
        mock_expectations: count_mock_expectations(content),
        setup_complexity: analyze_setup_complexity(content)
      }
    end)
    |> Enum.group_by(& &1.setup_complexity)
  end

  defp estimate_database_queries(content) do
    patterns = [
      ~r/Repo\.(all|get|one|insert|update|delete)/,
      ~r/Factory\.create_/,
      ~r/Ash\.(create|read|update|destroy)/
    ]

    Enum.sum(
      for pattern <- patterns do
        content
        |> String.split("\n")
        |> Enum.count(&Regex.match?(pattern, &1))
      end
    )
  end

  defp count_factory_calls(content) do
    Regex.scan(~r/Factory\.create_/, content) |> length()
  end

  defp count_mock_expectations(content) do
    Regex.scan(~r/\|>\s*expect\(/, content) |> length()
  end

  defp analyze_setup_complexity(content) do
    setup_blocks = Regex.scan(~r/setup.*?do(.*?)end/ms, content)

    if Enum.empty?(setup_blocks) do
      :simple
    else
      total_lines =
        setup_blocks
        |> Enum.map(fn [_, block] -> String.split(block, "\n") |> length() end)
        |> Enum.sum()

      cond do
        total_lines < 5 -> :simple
        total_lines < 15 -> :moderate
        true -> :complex
      end
    end
  end

  defp estimate_execution_time(test_files) do
    # Rough estimation based on test characteristics
    test_files
    |> Enum.map(fn file ->
      content = File.read!(file)
      test_count = Regex.scan(~r/test\s+"/, content) |> length()

      # 50ms per test baseline
      base_time = test_count * 50

      # Adjust for complexity
      complexity_multiplier =
        cond do
          String.contains?(content, "integration") -> 3
          String.contains?(content, "contract") -> 2
          true -> 1
        end

      # Adjust for database usage
      db_multiplier =
        if String.contains?(content, "Factory.create") do
          1.5
        else
          1
        end

      base_time * complexity_multiplier * db_multiplier
    end)
    |> Enum.sum()
  end

  defp add_async_recommendations(analysis) do
    async_safe_count = Enum.count(analysis.async_safe, & &1.async_safe)
    async_enabled_count = Enum.count(analysis.async_safe, & &1.async)

    recommendations =
      if async_safe_count > async_enabled_count do
        [
          %{
            type: :enable_async,
            impact: :high,
            description:
              "Enable async for #{async_safe_count - async_enabled_count} more test files",
            files:
              Enum.filter(analysis.async_safe, &(&1.async_safe && !&1.async))
              |> Enum.map(& &1.file)
          }
          | analysis.recommendations
        ]
      else
        analysis.recommendations
      end

    %{analysis | recommendations: recommendations}
  end

  defp add_grouping_recommendations(analysis) do
    # Find tests that could be grouped together
    resource_groups =
      analysis.async_safe
      |> Enum.group_by(& &1.shared_resources)
      |> Enum.filter(fn {resources, files} ->
        length(resources) > 0 && length(files) > 3
      end)

    recommendations =
      if map_size(resource_groups) > 0 do
        [
          %{
            type: :group_tests,
            impact: :medium,
            description: "Group tests by shared resources for better isolation",
            groups: resource_groups
          }
          | analysis.recommendations
        ]
      else
        analysis.recommendations
      end

    %{analysis | recommendations: recommendations}
  end

  defp add_parallel_recommendations(analysis) do
    if analysis.total_files > 20 do
      recommendations = [
        %{
          type: :parallel_execution,
          impact: :high,
          description: "Use parallel test execution to reduce runtime",
          config: %{
            suggested_workers: optimal_worker_count(),
            estimated_speedup: calculate_speedup(analysis)
          }
        }
        | analysis.recommendations
      ]

      %{analysis | recommendations: recommendations}
    else
      analysis
    end
  end

  defp optimal_worker_count do
    # Get CPU count, but cap at 8 for test stability
    min(System.schedulers_online(), 8)
  end

  defp calculate_speedup(analysis) do
    # Rough estimate based on async-safe tests
    async_ratio = Enum.count(analysis.async_safe, & &1.async_safe) / length(analysis.async_safe)
    worker_count = optimal_worker_count()

    # Amdahl's law approximation
    1 / (1 - async_ratio + async_ratio / worker_count)
  end

  defp generate_test_groups(analysis) do
    # Group tests by execution characteristics
    analysis.async_safe
    |> Enum.group_by(fn test ->
      cond do
        Enum.member?(test.shared_resources, "database") -> :database_heavy
        Enum.member?(test.shared_resources, "mocks") -> :mock_heavy
        String.contains?(test.file, "integration") -> :integration
        String.contains?(test.file, "contract") -> :contract
        test.async_safe -> :unit_async
        true -> :unit_sync
      end
    end)
  end

  defp generate_resource_pools(analysis) do
    %{
      database: %{
        size: optimal_worker_count() * 2,
        overflow: 5,
        strategy: :fifo
      },
      mock: %{
        size: optimal_worker_count(),
        overflow: 0,
        strategy: :lifo
      }
    }
  end
end

defmodule WandererApp.TestOptimization.DependencyAnalyzer do
  @moduledoc """
  Analyzes test dependencies to optimize execution order.
  """

  def analyze(test_files) do
    test_files
    |> Enum.map(&analyze_file/1)
    |> build_dependency_graph()
  end

  defp analyze_file(file) do
    content = File.read!(file)

    %{
      file: file,
      module: extract_module_name(content),
      imports: extract_imports(content),
      aliases: extract_aliases(content),
      setup_dependencies: extract_setup_deps(content)
    }
  end

  defp extract_module_name(content) do
    case Regex.run(~r/defmodule\s+([\w\.]+)/, content) do
      [_, module] -> module
      _ -> "Unknown"
    end
  end

  defp extract_imports(content) do
    Regex.scan(~r/import\s+([\w\.]+)/, content)
    |> Enum.map(fn [_, module] -> module end)
  end

  defp extract_aliases(content) do
    Regex.scan(~r/alias\s+([\w\.]+)/, content)
    |> Enum.map(fn [_, module] -> module end)
  end

  defp extract_setup_deps(content) do
    Regex.scan(~r/setup\s+\[([\w\s,:]+)\]/, content)
    |> Enum.flat_map(fn [_, deps] ->
      deps
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.map(&String.replace(&1, ":", ""))
    end)
  end

  defp build_dependency_graph(file_analyses) do
    # Build a graph of test dependencies
    Enum.map(file_analyses, fn analysis ->
      deps = find_dependencies(analysis, file_analyses)
      {analysis.file, deps}
    end)
    |> Map.new()
  end

  defp find_dependencies(analysis, all_analyses) do
    # Find which other test files this one depends on
    all_analyses
    |> Enum.filter(&(&1.file != analysis.file))
    |> Enum.filter(fn other ->
      # Check if this test imports or aliases modules from other test
      module_match =
        Enum.any?(analysis.imports ++ analysis.aliases, fn imported ->
          String.contains?(imported, other.module)
        end)

      # Check setup dependencies
      setup_match =
        Enum.any?(analysis.setup_dependencies, fn dep ->
          String.contains?(other.file, dep)
        end)

      module_match || setup_match
    end)
    |> Enum.map(& &1.file)
  end
end

defmodule WandererApp.TestOptimization.TestOrderOptimizer do
  @moduledoc """
  Optimizes test execution order for better performance.
  """

  def optimize(analysis) do
    # Order tests to maximize cache hits and minimize setup/teardown
    analysis.dependencies
    |> topological_sort()
    |> group_by_characteristics(analysis)
    |> optimize_within_groups()
  end

  defp topological_sort(dependencies) do
    # Simple topological sort for dependency ordering
    visited = MapSet.new()
    result = []

    {_visited, result} =
      Enum.reduce(Map.keys(dependencies), {visited, result}, fn node, {visited, result} ->
        if MapSet.member?(visited, node) do
          {visited, result}
        else
          visit(node, dependencies, visited, result)
        end
      end)

    Enum.reverse(result)
  end

  defp visit(node, dependencies, visited, result) do
    visited = MapSet.put(visited, node)

    deps = Map.get(dependencies, node, [])

    {visited, result} =
      Enum.reduce(deps, {visited, result}, fn dep, {visited, result} ->
        if MapSet.member?(visited, dep) do
          {visited, result}
        else
          visit(dep, dependencies, visited, result)
        end
      end)

    {visited, [node | result]}
  end

  defp group_by_characteristics(files, _analysis) do
    # Group files by similar characteristics for cache efficiency
    # TODO: Use analysis to group files more intelligently

    files
    |> Enum.group_by(fn file ->
      # For now, group by file path pattern
      cond do
        String.contains?(file, "integration") -> "integration"
        String.contains?(file, "unit") -> "unit"
        String.contains?(file, "contract") -> "contract"
        true -> "other"
      end
    end)
  end

  defp optimize_within_groups(grouped_files) do
    # Within each group, order by estimated execution time
    grouped_files
    |> Enum.flat_map(fn {_key, files} ->
      # For now, just keep the topological order within groups
      files
    end)
  end
end

defmodule WandererApp.TestOptimization.ParallelExecutor do
  @moduledoc """
  Manages parallel test execution with resource constraints.
  """

  def run_parallel(test_groups, config) do
    # Set up resource pools
    setup_resource_pools(config.resource_pools)

    # Create worker pool
    {:ok, supervisor} = Task.Supervisor.start_link()

    # Execute test groups in parallel
    results =
      test_groups
      |> Enum.map(fn {group_name, tests} ->
        Task.Supervisor.async(supervisor, fn ->
          run_test_group(group_name, tests, config)
        end)
      end)
      |> Task.await_many(:infinity)

    # Cleanup
    cleanup_resource_pools()

    results
  end

  defp setup_resource_pools(pool_configs) do
    Enum.each(pool_configs, fn {name, config} ->
      # In practice, you'd set up actual resource pools here
      # For example, database connection pools, mock registries, etc.
      :ok
    end)
  end

  defp run_test_group(group_name, tests, config) do
    # Run tests in the group with appropriate resource allocation
    IO.puts("Running test group: #{group_name}")

    # TODO: Integrate with ExUnit for actual test execution
    # This is a placeholder implementation for demonstration
    case config[:mode] do
      :actual ->
        # Attempt to run actual tests (requires ExUnit integration)
        run_actual_tests(tests)

      _ ->
        # Fallback to simulation for development/testing
        simulate_test_execution(tests)
    end
  end

  defp run_actual_tests(tests) do
    # TODO: Implement actual ExUnit test execution
    # This would require running ExUnit programmatically and capturing results
    # For now, return simulated results with a note
    IO.puts("WARNING: Actual test execution not yet implemented")
    simulate_test_execution(tests)
  end

  defp simulate_test_execution(tests) do
    # Simulate test execution with more realistic results
    for test <- tests do
      # Simulate some failures for realism
      result = if :rand.uniform(10) > 8, do: :failed, else: :passed

      %{
        test: test,
        result: result,
        duration: :rand.uniform(100),
        simulated: true
      }
    end
  end

  defp cleanup_resource_pools do
    # Cleanup any resources
    :ok
  end
end

defmodule WandererApp.TestOptimization.ResourcePool do
  @moduledoc """
  Manages shared resources for parallel test execution.
  """

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  def acquire(pool, timeout \\ 5000) do
    GenServer.call(pool, :acquire, timeout)
  end

  def release(pool, resource) do
    GenServer.cast(pool, {:release, resource})
  end

  @impl true
  def init(opts) do
    size = Keyword.get(opts, :size, 10)

    resources =
      for i <- 1..size do
        create_resource(opts[:type], i)
      end

    state = %{
      available: resources,
      in_use: %{},
      waiting: :queue.new(),
      config: opts
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:acquire, from, state) do
    case state.available do
      [resource | rest] ->
        state = %{state | available: rest, in_use: Map.put(state.in_use, resource, from)}
        {:reply, {:ok, resource}, state}

      [] ->
        # Add to waiting queue
        state = %{state | waiting: :queue.in(from, state.waiting)}
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:release, resource}, state) do
    state = %{state | in_use: Map.delete(state.in_use, resource)}

    # Check if anyone is waiting
    case :queue.out(state.waiting) do
      {{:value, waiting_from}, new_queue} ->
        # Give resource to waiting process
        GenServer.reply(waiting_from, {:ok, resource})

        state = %{
          state
          | waiting: new_queue,
            in_use: Map.put(state.in_use, resource, waiting_from)
        }

        {:noreply, state}

      {:empty, _} ->
        # Return to available pool
        state = %{state | available: [resource | state.available]}
        {:noreply, state}
    end
  end

  defp create_resource(:database, id) do
    # Create a database connection/sandbox
    {:db_conn, id}
  end

  defp create_resource(:mock, id) do
    # Create a mock context
    {:mock_context, id}
  end

  defp create_resource(type, id) do
    {type, id}
  end
end
