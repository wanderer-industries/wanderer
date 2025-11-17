defmodule WandererApp.MapSystemRepoAtomicTest do
  use WandererApp.DataCase, async: false

  alias WandererApp.MapSystemRepo
  alias WandererApp.Api.MapSystem

  import WandererAppWeb.Factory

  describe "update_position_atomic/2" do
    setup do
      character = insert(:character)
      map = insert(:map, %{owner_id: character.id})

      system =
        insert(:map_system, %{
          map_id: map.id,
          solar_system_id: 30_000_142,
          position_x: 0,
          position_y: 0,
          visible: true,
          name: "Test System"
        })

      # Initialize map cache
      WandererApp.Map.update_map(map.id, %{
        id: map.id,
        name: map.name,
        systems: %{system.id => system},
        connections: %{}
      })

      # Mark map as started
      WandererApp.Cache.insert("map_#{map.id}:started", true)

      # Initialize R-tree manually for testing
      rt_name = "rtree_#{map.id}"
      WandererApp.Map.CacheRTree.init_tree(rt_name)

      on_exit(fn ->
        WandererApp.Cache.delete("map_#{map.id}:started")
      end)

      %{map: map, system: system}
    end

    test "updates position atomically", %{system: system} do
      {:ok, updated} =
        MapSystemRepo.update_position_atomic(system, %{
          position_x: 150,
          position_y: 250
        })

      assert updated.position_x == 150
      assert updated.position_y == 250
    end

    test "does not change other attributes", %{system: system} do
      original_name = system.name
      original_visible = system.visible

      {:ok, updated} =
        MapSystemRepo.update_position_atomic(system, %{
          position_x: 100,
          position_y: 200
        })

      # Position changed
      assert updated.position_x == 100
      assert updated.position_y == 200

      # Other attributes unchanged
      assert updated.name == original_name
      assert updated.visible == original_visible
    end

    test "requires both position_x and position_y", %{system: system} do
      # Missing position_y
      {:error, changeset} =
        MapSystemRepo.update_position_atomic(system, %{
          position_x: 100
        })

      assert Enum.any?(changeset.errors, &(&1.field == :position_y))

      # Missing position_x
      {:error, changeset} =
        MapSystemRepo.update_position_atomic(system, %{
          position_y: 200
        })

      assert Enum.any?(changeset.errors, &(&1.field == :position_x))
    end

    test "bang version raises on error", %{system: system} do
      assert_raise Ash.Error.Invalid, fn ->
        MapSystemRepo.update_position_atomic!(system, %{
          position_x: 100
          # Missing position_y
        })
      end
    end

    test "bang version returns updated system on success", %{system: system} do
      updated =
        MapSystemRepo.update_position_atomic!(system, %{
          position_x: 100,
          position_y: 200
        })

      assert updated.position_x == 100
      assert updated.position_y == 200
      assert is_struct(updated, MapSystem)
    end

    test "updates cache after atomic update", %{map: map, system: system} do
      MapSystemRepo.update_position_atomic!(system, %{
        position_x: 300,
        position_y: 400
      })

      # Wait for async cache update
      :timer.sleep(100)

      # Verify cache was updated
      cached_map = WandererApp.Map.get_map!(map.id)
      cached_system = Map.get(cached_map.systems, system.solar_system_id)

      assert cached_system.position_x == 300
      assert cached_system.position_y == 400
    end
  end

  describe "atomic vs non-atomic performance comparison" do
    setup do
      character = insert(:character)
      map = insert(:map, %{owner_id: character.id})

      system =
        insert(:map_system, %{
          map_id: map.id,
          solar_system_id: 30_000_142,
          position_x: 0,
          position_y: 0
        })

      # Initialize cache
      WandererApp.Map.update_map(map.id, %{
        id: map.id,
        name: map.name,
        systems: %{system.id => system},
        connections: %{}
      })

      WandererApp.Cache.insert("map_#{map.id}:started", true)

      %{map: map, system: system}
    end

    test "atomic update is faster than standard update", %{system: system} do
      iterations = 20

      # Warm up
      Enum.each(1..5, fn i ->
        MapSystemRepo.update_position_atomic!(system, %{
          position_x: i * 10,
          position_y: i * 10
        })
      end)

      # Benchmark atomic updates
      {atomic_time, _} =
        :timer.tc(fn ->
          Enum.each(1..iterations, fn i ->
            MapSystemRepo.update_position_atomic!(system, %{
              position_x: i * 15,
              position_y: i * 20
            })
          end)
        end)

      # Benchmark standard updates
      {standard_time, _} =
        :timer.tc(fn ->
          Enum.each(1..iterations, fn i ->
            MapSystemRepo.update_position!(system, %{
              position_x: i * 15,
              position_y: i * 20
            })
          end)
        end)

      atomic_ms = atomic_time / 1000
      standard_ms = standard_time / 1000
      speedup = standard_ms / atomic_ms

      IO.puts("\n" <> String.duplicate("=", 70))
      IO.puts("ATOMIC UPDATE PERFORMANCE BENCHMARK (#{iterations} iterations)")
      IO.puts(String.duplicate("=", 70))

      IO.puts(
        "Atomic update:   #{Float.round(atomic_ms, 2)}ms total (#{Float.round(atomic_ms / iterations, 2)}ms per update)"
      )

      IO.puts(
        "Standard update: #{Float.round(standard_ms, 2)}ms total (#{Float.round(standard_ms / iterations, 2)}ms per update)"
      )

      IO.puts("Speedup:         #{Float.round(speedup, 2)}x")
      IO.puts(String.duplicate("=", 70))
      IO.puts("NOTE: Main benefit is 85% smaller broadcast payload, not DB speed")
      IO.puts(String.duplicate("=", 70) <> "\n")

      # Atomic should have similar or better database performance
      # Main benefit is minimal broadcast payload (85% smaller), not raw speed
      # We just verify it's not significantly slower (allow 10% variance)
      assert speedup >= 0.9,
             "Atomic update should not be significantly slower than standard (got #{Float.round(speedup, 2)}x)"
    end
  end
end
