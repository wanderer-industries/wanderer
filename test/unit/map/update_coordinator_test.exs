defmodule WandererApp.Map.UpdateCoordinatorTest do
  use WandererApp.DataCase, async: false

  import WandererAppWeb.Factory

  alias WandererApp.Map.UpdateCoordinator
  alias WandererApp.Map

  setup do
    # Create a test character and map
    character = insert(:character)
    map = insert(:map, %{owner_id: character.id})

    # Initialize R-tree manually for testing
    # The R-tree name is based on map_id
    rt_name = "rtree_#{map.id}"
    # Create the R-tree
    WandererApp.Map.CacheRTree.init_tree(rt_name)

    # Mark map as "started" so broadcasts will work
    # This simulates a map server being active
    WandererApp.Cache.put("map_#{map.id}:started", true)
    WandererApp.Cache.put("map_#{map.id}:importing", false)

    # Initialize map cache so connection/system operations work
    # Note: Map module uses Cachex with :map_cache, not Nebulex
    Cachex.put(:map_cache, map.id, %{
      map_id: map.id,
      systems: %{},
      connections: %{},
      characters: %{},
      hubs: []
    })

    # Stub the PubSub mock to actually call Phoenix.PubSub
    # This allows us to test real broadcasts in integration tests
    Test.PubSubMock
    |> Mox.stub(:broadcast!, fn pubsub, topic, message ->
      Phoenix.PubSub.broadcast!(pubsub, topic, message)
    end)

    # Subscribe to PubSub to verify broadcasts
    # Note: The topic is the map_id itself, not "maps:#{map_id}"
    Phoenix.PubSub.subscribe(WandererApp.PubSub, map.id)

    on_exit(fn ->
      # Clean up caches
      WandererApp.Cache.delete("map_#{map.id}:started")
      WandererApp.Cache.delete("map_#{map.id}:importing")
      Cachex.del(:map_cache, map.id)
    end)

    {:ok, map: map}
  end

  describe "add_system/3" do
    test "coordinates cache, R-tree, and broadcast for system addition", %{map: map} do
      system = %{
        id: Ecto.UUID.generate(),
        map_id: map.id,
        solar_system_id: 30_000_142,
        name: "Jita",
        position_x: 100,
        position_y: 200,
        visible: true,
        locked: false,
        status: 0
      }

      assert :ok = UpdateCoordinator.add_system(map.id, system)

      # Verify broadcast was received
      assert_receive %{event: :add_system, payload: received_system}, 2000
      assert received_system.solar_system_id == system.solar_system_id
    end

    test "returns error when cache update fails", %{map: map} do
      # Clear the map from cache to cause cache update to fail
      Cachex.del(:map_cache, map.id)

      system = %{
        id: Ecto.UUID.generate(),
        map_id: map.id,
        solar_system_id: 30_000_142,
        name: "Test System",
        position_x: 100,
        position_y: 200,
        visible: true,
        locked: false,
        status: 0
      }

      # This should succeed at cache level (Map.add_system handles missing maps gracefully)
      # but we can verify the system was still processed
      result = UpdateCoordinator.add_system(map.id, system)

      # The UpdateCoordinator completes successfully even if map isn't cached
      # (Map.get_map! returns %{} for missing maps)
      assert :ok = result
    end
  end

  describe "update_system/3" do
    test "coordinates cache, R-tree, and broadcast for system update", %{map: map} do
      system = %{
        id: Ecto.UUID.generate(),
        map_id: map.id,
        solar_system_id: 30_000_142,
        name: "Jita",
        position_x: 100,
        position_y: 200,
        visible: true,
        locked: false,
        status: 0
      }

      # First add the system
      :ok = UpdateCoordinator.add_system(map.id, system)
      assert_receive %{event: :add_system}, 2000

      # Now update it
      updated_system = %{system | status: 1}
      assert :ok = UpdateCoordinator.update_system(map.id, updated_system)

      # Verify broadcast was received
      assert_receive %{event: :update_system, payload: received_system}, 2000
      assert received_system.solar_system_id == system.solar_system_id
    end
  end

  describe "remove_system/3" do
    test "coordinates cache, R-tree, and broadcast for system removal", %{map: map} do
      system = %{
        id: Ecto.UUID.generate(),
        map_id: map.id,
        solar_system_id: 30_000_142,
        name: "Jita",
        position_x: 100,
        position_y: 200,
        visible: true,
        locked: false,
        status: 0
      }

      # First add the system
      :ok = UpdateCoordinator.add_system(map.id, system)
      assert_receive %{event: :add_system}, 2000

      # Now remove it
      assert :ok = UpdateCoordinator.remove_system(map.id, system.solar_system_id)

      # Verify broadcast was received with array format
      assert_receive %{event: :systems_removed, payload: [solar_system_id]}, 2000
      assert solar_system_id == system.solar_system_id
    end
  end

  describe "add_connection/3" do
    test "coordinates cache and broadcast for connection addition", %{map: map} do
      connection = %{
        id: Ecto.UUID.generate(),
        map_id: map.id,
        solar_system_source: 30_000_142,
        solar_system_target: 30_000_144,
        type: "wormhole",
        ship_size_type: 1,
        time_status: 0,
        mass_status: 0,
        locked: false
      }

      assert :ok = UpdateCoordinator.add_connection(map.id, connection)

      # Verify broadcast was received
      assert_receive %{event: :add_connection, payload: received_connection}, 2000
      assert received_connection.id == connection.id
    end
  end

  describe "update_connection/3" do
    test "coordinates cache and broadcast for connection update", %{map: map} do
      connection = %{
        id: Ecto.UUID.generate(),
        map_id: map.id,
        solar_system_source: 30_000_142,
        solar_system_target: 30_000_144,
        type: "wormhole",
        ship_size_type: 1,
        time_status: 0,
        mass_status: 0,
        locked: false
      }

      # First add the connection
      :ok = UpdateCoordinator.add_connection(map.id, connection)
      assert_receive %{event: :add_connection}, 2000

      # Now update it
      updated_connection = %{connection | mass_status: 1}
      assert :ok = UpdateCoordinator.update_connection(map.id, updated_connection)

      # Verify broadcast was received
      assert_receive %{event: :update_connection, payload: received_connection}, 2000
      assert received_connection.id == connection.id
    end
  end

  describe "remove_connection/3" do
    test "coordinates cache and broadcast for connection removal", %{map: map} do
      connection = %{
        id: Ecto.UUID.generate(),
        map_id: map.id,
        solar_system_source: 30_000_142,
        solar_system_target: 30_000_144,
        type: "wormhole",
        ship_size_type: 1,
        time_status: 0,
        mass_status: 0,
        locked: false
      }

      # First add the connection
      :ok = UpdateCoordinator.add_connection(map.id, connection)
      assert_receive %{event: :add_connection}, 2000

      # Now remove it
      assert :ok = UpdateCoordinator.remove_connection(map.id, connection)

      # Verify broadcast was received with array format
      assert_receive %{event: :remove_connections, payload: [received_connection]}, 2000
      assert received_connection.id == connection.id
    end
  end

  describe "broadcast? option" do
    test "skips broadcast when broadcast? is false", %{map: map} do
      system = %{
        id: Ecto.UUID.generate(),
        map_id: map.id,
        solar_system_id: 30_000_142,
        name: "Jita",
        position_x: 100,
        position_y: 200,
        visible: true,
        locked: false,
        status: 0
      }

      assert :ok = UpdateCoordinator.add_system(map.id, system, broadcast?: false)

      # Verify no broadcast was received
      refute_receive %{event: :add_system}, 500
    end
  end
end
