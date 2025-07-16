defmodule WandererApp.Performance.ApiPerformanceBenchmarks do
  @moduledoc """
  Comprehensive performance benchmarks for API endpoints.

  Tests performance characteristics of JSON:API endpoints under various load conditions
  and validates that performance requirements are met for production deployment.
  """

  use ExUnit.Case, async: false
  use WandererAppWeb.ApiCase

  import WandererApp.Support.ContractHelpers.ApiContractHelpers

  @moduletag :performance
  # 5 minutes for performance tests
  @moduletag timeout: 300_000

  # Performance targets
  @performance_targets %{
    # Response time targets (95th percentile)
    # ms
    single_resource_get: 200,
    # ms
    collection_get: 500,
    # ms
    resource_create: 300,
    # ms
    resource_update: 250,
    # ms
    resource_delete: 150,

    # Throughput targets (requests per second)
    # RPS
    read_throughput: 100,
    # RPS
    write_throughput: 50,

    # Resource limits
    # MB
    max_memory_per_request: 50,
    # connections
    max_db_connections: 10,

    # Concurrent user limits
    max_concurrent_users: 100
  }

  # Test data sizes
  @test_data_sizes %{
    # records
    small: 10,
    # records  
    medium: 100,
    # records
    large: 1000
  }

  describe "Single Resource Performance" do
    setup do
      scenario = create_authenticated_scenario()
      %{scenario: scenario}
    end

    test "GET single resource performance", %{scenario: scenario} do
      conn = build_jsonapi_conn(scenario.auth_token)

      # Warm up
      get(conn, "/api/v1/maps/#{scenario.map.id}")

      # Benchmark single resource retrieval
      {time_microseconds, response} =
        :timer.tc(fn ->
          get(conn, "/api/v1/maps/#{scenario.map.id}")
        end)

      time_ms = time_microseconds / 1000

      assert response.status == 200, "Request should succeed"

      assert time_ms <= @performance_targets.single_resource_get,
             "Single resource GET took #{time_ms}ms, should be <= #{@performance_targets.single_resource_get}ms"

      # Validate response structure hasn't been compromised for speed
      body = json_response(response, 200)
      validate_jsonapi_contract(body)
    end

    test "POST resource creation performance", %{scenario: scenario} do
      conn = build_jsonapi_conn(scenario.auth_token)

      map_data = %{
        "data" => %{
          "type" => "maps",
          "attributes" => %{
            "name" => "Performance Test Map",
            "description" => "Created for performance testing"
          }
        }
      }

      # Warm up
      post(conn, "/api/v1/maps", map_data)

      # Benchmark resource creation
      {time_microseconds, response} =
        :timer.tc(fn ->
          post(conn, "/api/v1/maps", map_data)
        end)

      time_ms = time_microseconds / 1000

      assert response.status in [200, 201], "Creation should succeed"

      assert time_ms <= @performance_targets.resource_create,
             "Resource creation took #{time_ms}ms, should be <= #{@performance_targets.resource_create}ms"
    end

    test "PATCH resource update performance", %{scenario: scenario} do
      conn = build_jsonapi_conn(scenario.auth_token)

      update_data = %{
        "data" => %{
          "type" => "maps",
          "id" => scenario.map.id,
          "attributes" => %{
            "description" => "Updated for performance testing"
          }
        }
      }

      # Warm up
      patch(conn, "/api/v1/maps/#{scenario.map.id}", update_data)

      # Benchmark resource update
      {time_microseconds, response} =
        :timer.tc(fn ->
          patch(conn, "/api/v1/maps/#{scenario.map.id}", update_data)
        end)

      time_ms = time_microseconds / 1000

      assert response.status in [200, 204], "Update should succeed"

      assert time_ms <= @performance_targets.resource_update,
             "Resource update took #{time_ms}ms, should be <= #{@performance_targets.resource_update}ms"
    end
  end

  describe "Collection Performance" do
    setup do
      scenario = create_authenticated_scenario()
      %{scenario: scenario}
    end

    test "GET collection performance - small dataset", %{scenario: scenario} do
      conn = build_jsonapi_conn(scenario.auth_token)

      # Benchmark collection retrieval
      {time_microseconds, response} =
        :timer.tc(fn ->
          get(conn, "/api/v1/maps?page[size]=#{@test_data_sizes.small}")
        end)

      time_ms = time_microseconds / 1000

      assert response.status == 200, "Collection request should succeed"

      assert time_ms <= @performance_targets.collection_get,
             "Small collection GET took #{time_ms}ms, should be <= #{@performance_targets.collection_get}ms"

      body = json_response(response, 200)
      validate_jsonapi_contract(body)

      # Validate pagination performance
      if Map.has_key?(body, "links") do
        links = body["links"]
        assert is_map(links), "Pagination links should be efficiently generated"
      end
    end

    test "GET collection with filtering performance", %{scenario: scenario} do
      conn = build_jsonapi_conn(scenario.auth_token)

      # Test filtering performance
      {time_microseconds, response} =
        :timer.tc(fn ->
          get(conn, "/api/v1/maps?filter[name]=test&page[size]=50")
        end)

      time_ms = time_microseconds / 1000

      assert response.status == 200, "Filtered collection should succeed"

      assert time_ms <= @performance_targets.collection_get * 1.5,
             "Filtered collection took #{time_ms}ms, should be <= #{@performance_targets.collection_get * 1.5}ms"
    end

    test "GET collection with includes performance", %{scenario: scenario} do
      conn = build_jsonapi_conn(scenario.auth_token)

      # Test includes performance
      {time_microseconds, response} =
        :timer.tc(fn ->
          get(conn, "/api/v1/maps?include=owner&page[size]=20")
        end)

      time_ms = time_microseconds / 1000

      assert response.status == 200, "Collection with includes should succeed"

      assert time_ms <= @performance_targets.collection_get * 2,
             "Collection with includes took #{time_ms}ms, should be <= #{@performance_targets.collection_get * 2}ms"

      body = json_response(response, 200)

      # Validate that includes don't break structure
      if Map.has_key?(body, "included") do
        included = body["included"]
        assert is_list(included), "Included resources should be properly structured"
      end
    end
  end

  describe "Concurrent Load Performance" do
    setup do
      scenario = create_authenticated_scenario()
      %{scenario: scenario}
    end

    test "concurrent read performance", %{scenario: scenario} do
      num_concurrent = 10
      num_requests_per_task = 5

      # Create multiple concurrent tasks
      tasks =
        Enum.map(1..num_concurrent, fn _i ->
          Task.async(fn ->
            conn = build_jsonapi_conn(scenario.auth_token)

            results =
              Enum.map(1..num_requests_per_task, fn _j ->
                {time_microseconds, response} =
                  :timer.tc(fn ->
                    get(conn, "/api/v1/maps")
                  end)

                %{
                  time_ms: time_microseconds / 1000,
                  status: response.status,
                  success: response.status == 200
                }
              end)

            results
          end)
        end)

      # Wait for all tasks to complete
      # 30 second timeout
      all_results = Task.await_many(tasks, 30_000)

      # Flatten results
      flat_results = List.flatten(all_results)

      # Calculate statistics
      times = Enum.map(flat_results, & &1.time_ms)
      success_count = Enum.count(flat_results, & &1.success)
      total_requests = length(flat_results)

      avg_time = Enum.sum(times) / length(times)
      max_time = Enum.max(times)
      p95_time = percentile(times, 95)

      success_rate = success_count / total_requests

      # Performance assertions
      assert success_rate >= 0.95,
             "Success rate should be >= 95%, got #{success_rate * 100}%"

      assert p95_time <= @performance_targets.collection_get * 2,
             "95th percentile response time should be <= #{@performance_targets.collection_get * 2}ms, got #{p95_time}ms"

      assert avg_time <= @performance_targets.collection_get,
             "Average response time should be <= #{@performance_targets.collection_get}ms, got #{avg_time}ms"

      IO.puts("\nConcurrent Load Test Results:")
      IO.puts("  Total requests: #{total_requests}")
      IO.puts("  Concurrent users: #{num_concurrent}")
      IO.puts("  Success rate: #{Float.round(success_rate * 100, 2)}%")
      IO.puts("  Average response time: #{Float.round(avg_time, 2)}ms")
      IO.puts("  95th percentile: #{Float.round(p95_time, 2)}ms")
      IO.puts("  Max response time: #{Float.round(max_time, 2)}ms")
    end

    test "mixed read/write performance", %{scenario: scenario} do
      num_concurrent = 5

      # Mix of read and write operations
      read_task =
        Task.async(fn ->
          conn = build_jsonapi_conn(scenario.auth_token)

          Enum.map(1..10, fn _i ->
            {time, response} =
              :timer.tc(fn ->
                get(conn, "/api/v1/maps")
              end)

            %{type: :read, time_ms: time / 1000, status: response.status}
          end)
        end)

      write_tasks =
        Enum.map(1..4, fn i ->
          Task.async(fn ->
            conn = build_jsonapi_conn(scenario.auth_token)

            map_data = %{
              "data" => %{
                "type" => "maps",
                "attributes" => %{
                  "name" => "Concurrent Test Map #{i}",
                  "description" => "Created during concurrent testing"
                }
              }
            }

            {time, response} =
              :timer.tc(fn ->
                post(conn, "/api/v1/maps", map_data)
              end)

            %{type: :write, time_ms: time / 1000, status: response.status}
          end)
        end)

      # Wait for all tasks
      read_results = Task.await(read_task, 30_000)
      write_results = Task.await_many(write_tasks, 30_000)

      all_results = read_results ++ List.flatten(write_results)

      # Validate performance under mixed load
      read_times = all_results |> Enum.filter(&(&1.type == :read)) |> Enum.map(& &1.time_ms)
      write_times = all_results |> Enum.filter(&(&1.type == :write)) |> Enum.map(& &1.time_ms)

      avg_read_time = if read_times != [], do: Enum.sum(read_times) / length(read_times), else: 0

      avg_write_time =
        if write_times != [], do: Enum.sum(write_times) / length(write_times), else: 0

      assert avg_read_time <= @performance_targets.collection_get * 1.5,
             "Read performance under mixed load: #{avg_read_time}ms should be <= #{@performance_targets.collection_get * 1.5}ms"

      assert avg_write_time <= @performance_targets.resource_create * 1.5,
             "Write performance under mixed load: #{avg_write_time}ms should be <= #{@performance_targets.resource_create * 1.5}ms"

      IO.puts("\nMixed Load Test Results:")
      IO.puts("  Average read time: #{Float.round(avg_read_time, 2)}ms")
      IO.puts("  Average write time: #{Float.round(avg_write_time, 2)}ms")
    end
  end

  describe "Memory and Resource Performance" do
    setup do
      scenario = create_authenticated_scenario()
      %{scenario: scenario}
    end

    test "memory usage during large collection requests", %{scenario: scenario} do
      conn = build_jsonapi_conn(scenario.auth_token)

      # Measure memory before request
      {memory_before, _} = :erlang.process_info(self(), :memory)

      # Make request for large dataset (if available)
      response = get(conn, "/api/v1/maps?page[size]=100")

      # Measure memory after request
      {memory_after, _} = :erlang.process_info(self(), :memory)

      memory_diff_mb = (memory_after - memory_before) / (1024 * 1024)

      assert response.status == 200, "Large collection request should succeed"

      assert memory_diff_mb <= @performance_targets.max_memory_per_request,
             "Memory usage #{memory_diff_mb}MB should be <= #{@performance_targets.max_memory_per_request}MB"
    end
  end

  describe "SSE Events Performance" do
    setup do
      scenario = create_authenticated_scenario()
      %{scenario: scenario}
    end

    # Skip until we have SSE testing infrastructure
    @tag :skip
    test "SSE connection establishment performance", %{scenario: scenario} do
      # This would test the time to establish SSE connections
      # and the overhead of JSON:API event formatting

      connection_times =
        Enum.map(1..10, fn _i ->
          {time_microseconds, _result} =
            :timer.tc(fn ->
              # Simulate SSE connection establishment
              # This would be implemented with actual SSE client testing
              # Placeholder
              :timer.sleep(50)
            end)

          time_microseconds / 1000
        end)

      avg_connection_time = Enum.sum(connection_times) / length(connection_times)
      max_connection_time = Enum.max(connection_times)

      # 1 second
      assert avg_connection_time <= 1000,
             "Average SSE connection time #{avg_connection_time}ms should be <= 1000ms"

      # 2 seconds
      assert max_connection_time <= 2000,
             "Max SSE connection time #{max_connection_time}ms should be <= 2000ms"

      IO.puts("\nSSE Performance Results:")
      IO.puts("  Average connection time: #{Float.round(avg_connection_time, 2)}ms")
      IO.puts("  Max connection time: #{Float.round(max_connection_time, 2)}ms")
    end
  end

  # Helper functions

  defp percentile(list, percentile)
       when is_list(list) and percentile >= 0 and percentile <= 100 do
    sorted = Enum.sort(list)
    length = length(sorted)
    index = trunc(length * percentile / 100)

    cond do
      index == 0 -> List.first(sorted)
      index >= length -> List.last(sorted)
      true -> Enum.at(sorted, index - 1)
    end
  end
end
