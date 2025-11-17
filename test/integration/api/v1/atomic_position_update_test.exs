defmodule WandererAppWeb.Api.V1.AtomicPositionUpdateTest do
  use WandererApp.DataCase, async: false

  alias WandererApp.MapSystemRepo
  alias WandererApp.Map.UpdateCoordinator

  import WandererAppWeb.Factory

  @moduledoc """
  Integration tests verifying that atomic position updates result in minimal broadcasts.
  """

  describe "Atomic position update with UpdateCoordinator" do
    setup do
      character = insert(:character)
      map = insert(:map, %{owner_id: character.id})

      # Initialize map cache
      WandererApp.Map.update_map(map.id, %{
        id: map.id,
        name: map.name,
        systems: %{},
        connections: %{}
      })

      WandererApp.Cache.insert("map_#{map.id}:started", true)

      # Initialize R-tree manually for testing
      rt_name = "rtree_#{map.id}"
      WandererApp.Map.CacheRTree.init_tree(rt_name)

      # Stub the PubSub mock to actually call Phoenix.PubSub
      # This allows us to test real broadcasts in integration tests
      Test.PubSubMock
      |> Mox.stub(:broadcast!, fn pubsub, topic, message ->
        Phoenix.PubSub.broadcast!(pubsub, topic, message)
      end)

      # Subscribe to broadcasts
      # Note: The topic is the map_id itself, not "maps:#{map_id}"
      Phoenix.PubSub.subscribe(WandererApp.PubSub, map.id)

      on_exit(fn ->
        WandererApp.Cache.delete("map_#{map.id}:started")
        WandererApp.Map.CacheRTree.clear_tree("rtree_#{map.id}")
      end)

      %{map: map, character: character}
    end

    test "atomic position update triggers minimal broadcast", %{map: map} do
      # Create system
      system =
        insert(:map_system, %{
          map_id: map.id,
          solar_system_id: 30_000_142,
          position_x: 0,
          position_y: 0
        })

      WandererApp.Map.add_system(map.id, system)

      # Clear any existing messages
      flush_messages()

      # Update via atomic action
      updated_system =
        MapSystemRepo.update_position_atomic!(system, %{
          position_x: 150,
          position_y: 250
        })

      # Wait for broadcast
      :timer.sleep(100)

      # Verify position was updated in database
      assert updated_system.position_x == 150
      assert updated_system.position_y == 250

      # Collect broadcasts
      broadcasts = collect_broadcasts()

      # Should receive at least one position-related broadcast
      assert length(broadcasts) > 0,
             "Expected at least one broadcast, got #{length(broadcasts)}"

      # Verify broadcasts contain position update info
      position_updates =
        Enum.filter(broadcasts, fn msg ->
          msg.event == :position_updated or msg.event == :update_system
        end)

      assert length(position_updates) > 0,
             "Expected position update broadcast, got events: #{inspect(Enum.map(broadcasts, & &1.event))}"
    end

    test "UpdateCoordinator with minimal flag broadcasts minimal payload", %{map: map} do
      system =
        insert(:map_system, %{
          map_id: map.id,
          solar_system_id: 30_000_142,
          position_x: 100,
          position_y: 200,
          name: "Test System",
          description: "A test system"
        })

      WandererApp.Map.add_system(map.id, system)
      flush_messages()

      # Update system with minimal flag
      system_with_new_pos = %{system | position_x: 300, position_y: 400}

      UpdateCoordinator.update_system(
        map.id,
        system_with_new_pos,
        event: :position_updated,
        minimal: true
      )

      :timer.sleep(50)

      # Receive broadcast
      broadcast = receive_broadcast()
      assert broadcast.event == :position_updated

      payload = broadcast.payload

      # Verify minimal payload
      assert Map.has_key?(payload, :id)
      assert Map.has_key?(payload, :solar_system_id)
      assert Map.has_key?(payload, :position_x)
      assert Map.has_key?(payload, :position_y)
      assert Map.has_key?(payload, :updated_at)

      # Should not have extra fields (minimal payload)
      refute Map.has_key?(payload, :description)
      refute Map.has_key?(payload, :labels)
      refute Map.has_key?(payload, :tag)
    end

    test "minimal broadcast is smaller than standard broadcast", %{map: map} do
      system =
        insert(:map_system, %{
          map_id: map.id,
          solar_system_id: 30_000_142,
          position_x: 0,
          position_y: 0,
          name: "Test System with Long Name",
          description: "A detailed description that adds to payload size"
        })

      WandererApp.Map.add_system(map.id, system)
      flush_messages()

      # Minimal update
      system_updated = %{system | position_x: 100, position_y: 200}

      UpdateCoordinator.update_system(
        map.id,
        system_updated,
        event: :position_updated,
        minimal: true
      )

      :timer.sleep(50)

      minimal_broadcast = receive_broadcast()
      minimal_size = byte_size(:erlang.term_to_binary(minimal_broadcast.payload))

      flush_messages()

      # Standard update
      system_updated2 = %{system | position_x: 150, position_y: 250}

      UpdateCoordinator.update_system(
        map.id,
        system_updated2,
        event: :update_system,
        minimal: false
      )

      :timer.sleep(50)

      standard_broadcast = receive_broadcast()
      standard_size = byte_size(:erlang.term_to_binary(standard_broadcast.payload))

      reduction = (1 - minimal_size / standard_size) * 100

      # Minimal should be at least 30% smaller
      assert minimal_size < standard_size * 0.7,
             "Minimal payload should be at least 30% smaller (minimal: #{minimal_size}, standard: #{standard_size})"
    end

    test "cache is updated after atomic position update", %{map: map} do
      system =
        insert(:map_system, %{
          map_id: map.id,
          solar_system_id: 30_000_142,
          position_x: 0,
          position_y: 0
        })

      WandererApp.Map.add_system(map.id, system)

      # Update position
      MapSystemRepo.update_position_atomic!(system, %{
        position_x: 500,
        position_y: 600
      })

      # Wait for cache update
      :timer.sleep(100)

      # Verify cache was updated
      cached_map = WandererApp.Map.get_map!(map.id)
      # Cache is keyed by solar_system_id, not system.id
      cached_system = Map.get(cached_map.systems, system.solar_system_id)

      assert cached_system.position_x == 500
      assert cached_system.position_y == 600
    end
  end

  # Helper functions
  defp flush_messages do
    receive do
      _ -> flush_messages()
    after
      10 -> :ok
    end
  end

  defp receive_broadcast do
    receive do
      %{event: _event, payload: _payload} = broadcast ->
        broadcast
    after
      100 -> raise "No broadcast received"
    end
  end

  defp collect_broadcasts(acc \\ []) do
    receive do
      %{event: _event, payload: _payload} = broadcast ->
        collect_broadcasts([broadcast | acc])
    after
      50 -> Enum.reverse(acc)
    end
  end
end
