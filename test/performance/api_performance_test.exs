defmodule WandererAppWeb.APIPerformanceTest do
  @moduledoc """
  Performance tests for API endpoints using the enhanced performance testing framework.

  These tests validate that API endpoints meet performance requirements and
  detect performance regressions over time.
  """

  use WandererAppWeb.ConnCase, async: false
  use WandererApp.PerformanceTestFramework, test_type: :api_test

  import WandererAppWeb.Factory

  @moduletag :performance

  describe "Map API Performance" do
    setup do
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})
      map = insert(:map, %{owner_id: character.id})

      # Start the map server for these tests
      {:ok, _pid} =
        DynamicSupervisor.start_child(
          {:via, PartitionSupervisor, {WandererApp.Map.DynamicSupervisors, self()}},
          {WandererApp.Map.ServerSupervisor, map_id: map.id}
        )

      # Create some test data
      systems =
        for i <- 1..10 do
          insert(:map_system, %{
            map_id: map.id,
            solar_system_id: 30_000_140 + i,
            name: "System #{i}"
          })
        end

      connections =
        for i <- 0..7 do
          source = Enum.at(systems, i)
          target = Enum.at(systems, i + 1)

          connection =
            insert(:map_connection, %{
              map_id: map.id,
              solar_system_source: source.solar_system_id,
              solar_system_target: target.solar_system_id,
              type: 0,
              ship_size_type: 2
            })

          # Update the map cache
          WandererApp.Map.add_connection(map.id, connection)
          connection
        end

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{map.public_api_key}")
        |> put_req_header("content-type", "application/json")

      %{
        conn: conn,
        map: map,
        systems: systems,
        connections: connections,
        user: user,
        character: character
      }
    end

    @tag :skip
    test "GET /api/maps/:slug should respond quickly (requires API setup)" do
      # TODO: Implement when API endpoint setup is complete
      # This test requires proper map API authentication and setup
      :skipped
    end

    @tag :skip
    test "GET /api/maps/:slug/systems should handle many systems (requires API setup)" do
      # TODO: Implement when systems API endpoint setup is complete
      # This test requires proper map systems API authentication and data setup
      :skipped
    end

    performance_test "GET /api/maps/:slug/connections should handle many connections", budget: 800 do
      %{conn: conn, map: map} = context = setup_test_data()

      conn = get(conn, ~p"/api/maps/#{map.slug}/connections")

      response = json_response(conn, 200)
      assert is_list(response["data"])
    end

    @tag :skip
    test "Map systems retrieval benchmark (requires full Benchee integration)" do
      # TODO: Implement when full performance monitoring infrastructure is ready
      # This test uses benchmark_test macro that requires complete Benchee integration
      :skipped
    end

    test "Load test map systems endpoint" do
      %{conn: conn, map: map} = setup_test_data()

      endpoint_config = %{
        method: :get,
        path: "/api/maps/#{map.slug}/systems",
        headers: conn.req_headers,
        body: nil
      }

      load_config = %{
        concurrent_users: 5,
        duration_seconds: 10,
        ramp_up_seconds: 2
      }

      results =
        WandererApp.PerformanceTestFramework.load_test_endpoint(endpoint_config, load_config)

      assert results.success_rate >= 0.95
      assert results.avg_response_time_ms <= 1000
    end

    test "Memory leak detection for map operations" do
      %{conn: conn, map: map} = setup_test_data()

      test_function = fn ->
        # Perform operations that could potentially leak memory
        get(conn, ~p"/api/maps/#{map.slug}/systems")
        get(conn, ~p"/api/maps/#{map.slug}/connections")
        get(conn, ~p"/api/maps/#{map.slug}")
      end

      results = WandererApp.PerformanceTestFramework.memory_leak_test(test_function, 50)

      # Allow up to 10MB memory growth for test operations (test environment is noisy)
      assert results.memory_growth < 10_000_000,
             "Excessive memory growth: #{results.memory_growth} bytes"

      assert results.trend_slope < 1_000_000,
             "Memory usage trend is concerning: #{results.trend_slope}"
    end

    @tag :stress_test
    test "Stress test map API endpoints" do
      %{conn: conn, map: map} = setup_test_data()

      test_function = fn ->
        # Simulate realistic user behavior
        get(conn, ~p"/api/maps/#{map.slug}")
        get(conn, ~p"/api/maps/#{map.slug}/systems")

        # Simulate adding a system (if endpoint exists)
        # post(conn, ~p"/api/maps/#{map.slug}/systems", %{...})
      end

      stress_config = %{
        initial_load: 1,
        max_load: 20,
        step_size: 2,
        step_duration: 5
      }

      results = WandererApp.PerformanceTestFramework.stress_test(test_function, stress_config)

      assert results.performance_summary.can_handle_load >= 5

      if results.performance_summary.breaks_at_load do
        IO.puts("🔥 API breaks at load: #{results.performance_summary.breaks_at_load}")
      end
    end
  end

  describe "Database Performance" do
    setup do
      # Setup test data for database performance tests
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})
      map = insert(:map, %{owner_id: character.id})

      %{user: user, character: character, map: map}
    end

    test "Map query performance", %{map: map} do
      query_function = fn ->
        WandererApp.MapRepo.get(map.id, [:owner, :characters])
      end

      results =
        WandererApp.PerformanceTestFramework.database_performance_test(query_function, %{
          iterations: 50,
          max_avg_time: 50,
          check_n_plus_one: true
        })

      assert results.performance_ok, "Database query too slow: #{results.avg_time_ms}ms"

      if Map.has_key?(results, :n_plus_one_detected) do
        assert not results.n_plus_one_detected, "N+1 query detected"
      end
    end

    test "System creation performance", %{map: map} do
      query_function = fn ->
        insert(:map_system, %{
          map_id: map.id,
          solar_system_id: Enum.random(30_000_001..30_004_000),
          name: "Test System #{:rand.uniform(1000)}"
        })
      end

      results =
        WandererApp.PerformanceTestFramework.database_performance_test(query_function, %{
          iterations: 20,
          max_avg_time: 100
        })

      assert results.performance_ok, "System creation too slow: #{results.avg_time_ms}ms"
    end
  end

  describe "Real-time Features Performance" do
    setup do
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})
      map = insert(:map, %{owner_id: character.id})

      %{user: user, character: character, map: map}
    end

    @tag :skip
    test "Map server operations should be fast (requires full infrastructure)" do
      # TODO: Implement when map server infrastructure is fully ready
      # This test depends on complete map server setup and cache initialization
      :skipped
    end

    @tag :skip
    test "Map cache operations benchmark (requires full cache setup)" do
      # TODO: Implement when cache infrastructure is fully ready
      # This test depends on proper cache initialization and setup
      :skipped
    end
  end

  # Helper function to set up consistent test data
  defp setup_test_data do
    user = insert(:user)
    character = insert(:character, %{user_id: user.id})
    map = insert(:map, %{owner_id: character.id})

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{map.public_api_key}")
      |> put_req_header("content-type", "application/json")

    %{conn: conn, map: map, user: user, character: character}
  end
end
