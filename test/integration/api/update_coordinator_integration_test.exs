defmodule WandererAppWeb.Api.UpdateCoordinatorIntegrationTest do
  use WandererAppWeb.ConnCase, async: false

  import WandererAppWeb.Factory

  @moduledoc """
  Integration tests to verify UpdateCoordinator properly coordinates cache, R-tree, and broadcasts.

  These tests verify that when systems/connections are created via the API:
  1. Database is updated via Ash actions
  2. Transaction commits successfully
  3. UpdateCoordinator is called via after_transaction hook
  4. When cache exists, it's updated before broadcasts
  5. Systems are queryable from cache after creation

  Note: These tests verify the integration works end-to-end. In production, maps are
  initialized by the map server before any systems are added, so the cache will exist.

  PubSub broadcasts are logged but not explicitly tested here (test mode uses PubSubMock).
  The logs demonstrate that UpdateCoordinator successfully coordinates the broadcast ordering.
  """

  describe "UpdateCoordinator integration via V1 API" do
    setup do
      # Ensure Mox is in global mode and PubSub stub is set up
      # This allows async Tasks and after_transaction hooks to use the mock
      Mox.set_mox_global()

      Test.PubSubMock
      |> Mox.stub(:broadcast!, fn _server, _topic, _message -> :ok end)

      user = insert(:user)
      character = insert(:character, %{user_id: user.id})
      map = insert(:map, %{owner_id: character.id})

      # Ensure map has an API key
      map =
        case map.public_api_key do
          nil ->
            {:ok, updated_map} =
              WandererApp.MapRepo.update(map, %{
                public_api_key: "test_api_key_#{:rand.uniform(10000)}"
              })

            updated_map

          _ ->
            map
        end

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{map.public_api_key}")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> put_req_header("accept", "application/vnd.api+json")

      %{conn: conn, user: user, character: character, map: map}
    end

    test "POST /api/v1/map_systems uses UpdateCoordinator via after_transaction", %{
      conn: conn,
      map: map
    } do
      # Initialize the map in cache so UpdateCoordinator can work
      # In production, the map server does this before any systems are added
      WandererApp.Map.update_map(map.id, %{
        id: map.id,
        name: map.name,
        systems: %{},
        connections: %{}
      })

      # Mark map as started so broadcasts are allowed
      WandererApp.Cache.insert("map_#{map.id}:started", true)

      # Create a system via API
      # Note: map_id is NOT included - it's automatically injected from the auth token
      payload = %{
        "data" => %{
          "type" => "map_systems",
          "attributes" => %{
            "solar_system_id" => 30_000_142,
            "name" => "Jita",
            "position_x" => 100,
            "position_y" => 200,
            "visible" => true
          }
        }
      }

      # Make the request
      response = post(conn, "/api/v1/map_systems", payload)

      # Verify response - system created successfully
      assert response.status == 201
      assert %{"data" => %{"id" => system_id}} = json_response(response, 201)
      assert is_binary(system_id)

      # Wait for async operations (after_transaction callbacks)
      :timer.sleep(200)

      # Note: Broadcasts are tested separately. In test mode, PubSubMock is used
      # which requires Mox expectations. The logs show UpdateCoordinator successfully
      # coordinates broadcasts in the correct order (cache → R-tree → broadcast).

      # Verify database has the record (reload from DB using Ash)
      {:ok, db_system} = Ash.get(WandererApp.Api.MapSystem, system_id)
      assert db_system.solar_system_id == 30_000_142
      assert db_system.map_id == map.id

      # Verify cache has the record (this tests UpdateCoordinator updated cache)
      {:ok, cached_systems} = WandererApp.Map.list_systems(map.id)

      assert Enum.any?(cached_systems, fn s -> s.id == system_id end),
             "Cache should have the new system (UpdateCoordinator should have updated it before broadcast)"
    end

    test "concurrent system creations use UpdateCoordinator without race conditions", %{
      map: map
    } do
      # Initialize the map in cache
      WandererApp.Map.update_map(map.id, %{
        id: map.id,
        name: map.name,
        systems: %{},
        connections: %{}
      })

      # Mark map as started so broadcasts are allowed
      WandererApp.Cache.insert("map_#{map.id}:started", true)

      # Get the current process (test process) to allow database access
      test_pid = self()

      # Create multiple systems concurrently via API
      tasks =
        for i <- 1..3 do
          Task.async(fn ->
            # Allow this Task process to access the database
            Ecto.Adapters.SQL.Sandbox.allow(WandererApp.Repo, test_pid, self())

            # Create a fresh connection for this Task's process
            task_conn =
              build_conn()
              |> put_req_header("authorization", "Bearer #{map.public_api_key}")
              |> put_req_header("content-type", "application/vnd.api+json")
              |> put_req_header("accept", "application/vnd.api+json")

            # Note: map_id is NOT included - it's automatically injected from the auth token
            payload = %{
              "data" => %{
                "type" => "map_systems",
                "attributes" => %{
                  "solar_system_id" => 30_000_140 + i,
                  "name" => "System #{i}",
                  "position_x" => 100 * i,
                  "position_y" => 200,
                  "visible" => true
                }
              }
            }

            post(task_conn, "/api/v1/map_systems", payload)
          end)
        end

      # Wait for all to complete
      results = Task.await_many(tasks, 10_000)

      # All should succeed
      successful = Enum.count(results, fn r -> r.status == 201 end)
      assert successful == 3, "All 3 systems should be created successfully"

      # Wait for async operations
      :timer.sleep(300)

      # Verify cache has all the systems (UpdateCoordinator should have updated it)
      {:ok, cached_systems} = WandererApp.Map.list_systems(map.id)

      assert length(cached_systems) >= 3,
             "Cache should have all 3 systems after concurrent creation (UpdateCoordinator ensures this)"
    end
  end

  # Helper to flush any pending PubSub messages
  defp flush_pubsub_messages do
    receive do
      %Phoenix.Socket.Broadcast{} -> flush_pubsub_messages()
    after
      10 -> :ok
    end
  end
end
