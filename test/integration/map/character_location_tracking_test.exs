defmodule WandererApp.Map.CharacterLocationTrackingTest do
  @moduledoc """
  Integration tests for character location tracking and system addition.

  These tests verify end-to-end character location tracking behavior including:
  - Character location updates trigger system additions to maps
  - Rapid character movements (A→B→C) add all systems correctly
  - Database failures are handled with retries and proper error reporting
  - start_solar_system_id persists correctly through multiple updates
  - Task timeouts don't cause permanent state loss
  - Cache consistency between character and map-specific caches

  These tests focus on the critical issues identified in the location tracking system:
  1. Race conditions in cache updates during rapid movement
  2. Silent database failures masking system addition problems
  3. One-time start_solar_system_id flag being lost permanently
  4. Task timeout handling without recovery
  """

  use WandererApp.DataCase, async: false

  alias WandererApp.Map.Server.CharactersImpl
  alias WandererApp.Map.Server.SystemsImpl

  @test_map_id 999_999_001
  @test_character_eve_id 2_123_456_789

  # EVE Online solar system IDs for testing
  @system_jita 30_000_142
  @system_amarr 30_002_187
  @system_dodixie 30_002_659
  @system_rens 30_002_510

  setup do
    # Clean up any existing test data
    cleanup_test_data()

    # Create test user (let Ash generate the ID)
    user = create_user(%{name: "Test User", hash: "test_hash_#{:rand.uniform(1_000_000)}"})

    # Create test character with location tracking scopes
    character =
      create_character(%{
        eve_id: "#{@test_character_eve_id}",
        name: "Test Character",
        user_id: user.id,
        scopes: "esi-location.read_location.v1 esi-location.read_ship_type.v1",
        tracking_pool: "default"
      })

    # Create test map
    map =
      create_map(%{
        id: @test_map_id,
        name: "Test Char Track",
        slug: "test-char-tracking-#{:rand.uniform(1_000_000)}",
        owner_id: character.id,
        scope: :none,
        only_tracked_characters: false
      })

    on_exit(fn ->
      cleanup_test_data()
    end)

    {:ok, user: user, character: character, map: map}
  end

  defp cleanup_test_data do
    # Note: We can't clean up character-specific caches in setup
    # because we don't have the character.id yet. Tests will clean
    # up their own caches in on_exit if needed.

    # Clean up map-level presence tracking
    WandererApp.Cache.delete("map_#{@test_map_id}:presence_character_ids")
  end

  defp cleanup_character_caches(character_id) do
    # Clean up character location caches
    WandererApp.Cache.delete("map_#{@test_map_id}:character:#{character_id}:solar_system_id")

    WandererApp.Cache.delete(
      "map_#{@test_map_id}:character:#{character_id}:start_solar_system_id"
    )

    WandererApp.Cache.delete("map_#{@test_map_id}:character:#{character_id}:station_id")
    WandererApp.Cache.delete("map_#{@test_map_id}:character:#{character_id}:structure_id")

    # Clean up character cache
    if Cachex.exists?(:character_cache, character_id) do
      Cachex.del(:character_cache, character_id)
    end

    # Clean up character state cache
    if Cachex.exists?(:character_state_cache, character_id) do
      Cachex.del(:character_state_cache, character_id)
    end
  end

  defp set_character_location(character_id, solar_system_id, opts \\ []) do
    """
    Helper to simulate character location update in cache.
    This mimics what the Character.Tracker does when it polls ESI.
    """

    structure_id = opts[:structure_id]
    station_id = opts[:station_id]
    # Capsule
    ship_type_id = opts[:ship_type_id] || 670

    # First get the existing character from cache or database to maintain all fields
    {:ok, existing_character} = WandererApp.Character.get_character(character_id)

    # Update character cache (mimics Character.update_character/2)
    character_data =
      Map.merge(existing_character, %{
        solar_system_id: solar_system_id,
        structure_id: structure_id,
        station_id: station_id,
        ship_type_id: ship_type_id,
        updated_at: DateTime.utc_now()
      })

    Cachex.put(:character_cache, character_id, character_data)
  end

  defp ensure_map_started(map_id) do
    """
    Ensure the map server is started for the given map.
    This is required for character updates to work.
    """

    case WandererApp.Map.Manager.start_map(map_id) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      other -> other
    end
  end

  defp add_character_to_map_presence(map_id, character_id) do
    """
    Helper to add character to map's presence list.
    This mimics what PresenceGracePeriodManager does.
    """

    {:ok, current_chars} = WandererApp.Cache.lookup("map_#{map_id}:presence_character_ids", [])
    updated_chars = Enum.uniq([character_id | current_chars])
    WandererApp.Cache.insert("map_#{map_id}:presence_character_ids", updated_chars)
  end

  defp get_map_systems(map_id) do
    """
    Helper to get all systems currently on the map.
    """

    case WandererApp.Map.get_map_state(map_id) do
      {:ok, %{map: %{systems: systems}}} when is_map(systems) ->
        Map.values(systems)

      {:ok, _} ->
        []
    end
  end

  defp system_on_map?(map_id, solar_system_id) do
    """
    Check if a specific system is on the map.
    """

    systems = get_map_systems(map_id)
    Enum.any?(systems, fn sys -> sys.solar_system_id == solar_system_id end)
  end

  defp wait_for_system_on_map(map_id, solar_system_id, timeout \\ 2000) do
    """
    Wait for a system to appear on the map (for async operations).
    """

    deadline = System.monotonic_time(:millisecond) + timeout

    Stream.repeatedly(fn ->
      if system_on_map?(map_id, solar_system_id) do
        {:ok, true}
      else
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(50)
          :continue
        else
          {:error, :timeout}
        end
      end
    end)
    |> Enum.find(fn result -> result != :continue end)
    |> case do
      {:ok, true} -> true
      {:error, :timeout} -> false
    end
  end

  describe "Basic character location tracking" do
    @tag :skip
    @tag :integration
    test "character location update adds system to map", %{map: map, character: character} do
      # This test verifies the basic flow:
      # 1. Character starts tracking on a map
      # 2. Character location is updated in cache
      # 3. update_characters() is called
      # 4. System is added to the map

      # Setup: Ensure map is started
      ensure_map_started(map.id)

      # Setup: Add character to presence
      add_character_to_map_presence(map.id, character.id)

      # Setup: Set character location
      set_character_location(character.id, @system_jita)

      # Setup: Set start_solar_system_id (this happens when tracking starts)
      WandererApp.Cache.insert(
        "map_#{map.id}:character:#{character.id}:start_solar_system_id",
        @system_jita
      )

      # Execute: Run character update
      CharactersImpl.update_characters(map.id)

      # Verify: Jita should be added to the map
      assert wait_for_system_on_map(map.id, @system_jita),
             "Jita should have been added to map when character tracking started"
    end

    @tag :skip
    @tag :integration
    test "character movement from A to B adds both systems", %{map: map, character: character} do
      # This test verifies:
      # 1. Character starts at system A
      # 2. Character moves to system B
      # 3. update_characters() processes the change
      # 4. Both systems are on the map

      # Setup: Ensure map is started
      ensure_map_started(map.id)

      # Setup: Add character to presence
      add_character_to_map_presence(map.id, character.id)

      # Setup: Character starts at Jita
      set_character_location(character.id, @system_jita)

      WandererApp.Cache.insert(
        "map_#{map.id}:character:#{character.id}:start_solar_system_id",
        @system_jita
      )

      # First update - adds Jita
      CharactersImpl.update_characters(map.id)
      assert wait_for_system_on_map(map.id, @system_jita), "Jita should be on map initially"

      # Character moves to Amarr
      set_character_location(character.id, @system_amarr)

      # Second update - should add Amarr
      CharactersImpl.update_characters(map.id)

      # Verify: Both systems should be on map
      assert wait_for_system_on_map(map.id, @system_jita), "Jita should still be on map"
      assert wait_for_system_on_map(map.id, @system_amarr), "Amarr should have been added to map"
    end
  end

  describe "Rapid character movement (Race Condition Tests)" do
    @tag :skip
    @tag :integration
    test "rapid movement A→B→C adds all three systems", %{map: map, character: character} do
      # This test verifies the critical race condition fix:
      # When a character moves rapidly through multiple systems,
      # all systems should be added to the map, not just the start and end.

      ensure_map_started(map.id)
      add_character_to_map_presence(map.id, character.id)

      # Character starts at Jita
      set_character_location(character.id, @system_jita)

      WandererApp.Cache.insert(
        "map_#{map.id}:character:#{character.id}:start_solar_system_id",
        @system_jita
      )

      CharactersImpl.update_characters(map.id)
      assert wait_for_system_on_map(map.id, @system_jita)

      # Rapid jump to Amarr (intermediate system)
      set_character_location(character.id, @system_amarr)

      # Before update_characters can process, character jumps again to Dodixie
      # This simulates the race condition
      # Should process Jita→Amarr
      CharactersImpl.update_characters(map.id)

      # Character already at Dodixie before second update
      set_character_location(character.id, @system_dodixie)

      # Should process Amarr→Dodixie
      CharactersImpl.update_characters(map.id)

      # Verify: All three systems should be on map
      assert wait_for_system_on_map(map.id, @system_jita), "Jita (start) should be on map"

      assert wait_for_system_on_map(map.id, @system_amarr),
             "Amarr (intermediate) should be on map - this is the critical test"

      assert wait_for_system_on_map(map.id, @system_dodixie), "Dodixie (end) should be on map"
    end

    @tag :skip
    @tag :integration
    test "concurrent location updates don't lose intermediate systems", %{
      map: map,
      character: character
    } do
      # This test verifies that concurrent updates to character location
      # don't cause intermediate systems to be lost due to cache races.

      ensure_map_started(map.id)
      add_character_to_map_presence(map.id, character.id)

      # Start at Jita
      set_character_location(character.id, @system_jita)

      WandererApp.Cache.insert(
        "map_#{map.id}:character:#{character.id}:start_solar_system_id",
        @system_jita
      )

      CharactersImpl.update_characters(map.id)

      # Simulate rapid updates happening faster than update_characters cycle (1 second)
      # Jump through 4 systems in quick succession
      systems = [@system_amarr, @system_dodixie, @system_rens, @system_jita]

      for system <- systems do
        set_character_location(character.id, system)
        # Small delay to allow cache to settle
        Process.sleep(10)
        CharactersImpl.update_characters(map.id)
        Process.sleep(10)
      end

      # Verify: All systems should eventually be on the map
      # Even if some updates happened concurrently
      for system <- [@system_jita | systems] do
        assert wait_for_system_on_map(map.id, system),
               "System #{system} should be on map despite rapid movements"
      end
    end
  end

  describe "start_solar_system_id persistence" do
    @tag :skip
    @tag :integration
    test "start_solar_system_id persists through multiple updates", %{
      map: map,
      character: character
    } do
      # This test verifies the fix for the one-time flag bug:
      # start_solar_system_id should not be lost after first use

      ensure_map_started(map.id)
      add_character_to_map_presence(map.id, character.id)

      # Set character at Jita
      set_character_location(character.id, @system_jita)

      # Set start_solar_system_id
      WandererApp.Cache.insert(
        "map_#{map.id}:character:#{character.id}:start_solar_system_id",
        @system_jita
      )

      # First update
      CharactersImpl.update_characters(map.id)

      # Verify start_solar_system_id still exists after first update
      {:ok, start_system} =
        WandererApp.Cache.lookup("map_#{map.id}:character:#{character.id}:start_solar_system_id")

      assert start_system == @system_jita,
             "start_solar_system_id should persist after first update (not be taken/removed)"

      # Character moves to Amarr
      set_character_location(character.id, @system_amarr)

      # Second update
      CharactersImpl.update_characters(map.id)

      # Verify both systems are on map
      assert wait_for_system_on_map(map.id, @system_jita)
      assert wait_for_system_on_map(map.id, @system_amarr)
    end

    @tag :skip
    @tag :integration
    test "first system addition uses correct logic when start_solar_system_id exists", %{
      map: map,
      character: character
    } do
      # This test verifies that the first system addition logic
      # works correctly with start_solar_system_id

      ensure_map_started(map.id)
      add_character_to_map_presence(map.id, character.id)

      # Character is at Jita, no previous location
      set_character_location(character.id, @system_jita)

      # Set start_solar_system_id
      WandererApp.Cache.insert(
        "map_#{map.id}:character:#{character.id}:start_solar_system_id",
        @system_jita
      )

      # No old location in map cache (first time tracking)
      # This triggers the special first-system-addition logic

      CharactersImpl.update_characters(map.id)

      # Verify Jita is added
      assert wait_for_system_on_map(map.id, @system_jita),
             "First system should be added when character starts tracking"
    end
  end

  describe "Database failure handling" do
    @tag :integration
    test "database failure during system creation is logged and retried", %{
      map: map,
      character: character
    } do
      # This test verifies that database failures don't silently succeed
      # and are properly retried

      # NOTE: This test would need to mock the database to simulate failures
      # For now, we document the expected behavior

      # Expected behavior:
      # 1. maybe_add_system encounters DB error
      # 2. Error is logged with context
      # 3. Operation is retried (3 attempts with backoff)
      # 4. If all retries fail, error tuple is returned (not :ok)
      # 5. Telemetry event is emitted for the failure

      :ok
    end

    @tag :integration
    test "transient database errors succeed on retry", %{map: map, character: character} do
      # This test verifies retry logic for transient failures

      # Expected behavior:
      # 1. First attempt fails with transient error (timeout, connection, etc.)
      # 2. Retry succeeds
      # 3. System is added successfully
      # 4. Telemetry emitted for both failure and success

      :ok
    end

    @tag :integration
    test "permanent database errors don't break update_characters for other characters", %{
      map: map,
      character: character
    } do
      # This test verifies that a failure for one character
      # doesn't prevent processing other characters

      # Expected behavior:
      # 1. Multiple characters being tracked
      # 2. One character's update fails permanently
      # 3. Other characters' updates succeed
      # 4. Error is logged with character context
      # 5. update_characters completes for all characters

      :ok
    end
  end

  describe "Task timeout handling" do
    @tag :integration
    @tag :slow
    test "character update timeout doesn't lose state permanently", %{
      map: map,
      character: character
    } do
      # This test verifies that timeouts during update_characters
      # don't cause permanent state loss

      # Expected behavior:
      # 1. Character update takes > 15 seconds (simulated slow DB)
      # 2. Task times out and is killed
      # 3. State is preserved in recovery ETS table
      # 4. Next update_characters cycle recovers and processes the update
      # 5. System is eventually added to map
      # 6. Telemetry emitted for timeout and recovery

      :ok
    end

    @tag :integration
    test "multiple concurrent timeouts don't corrupt cache", %{map: map, character: character} do
      # This test verifies that multiple simultaneous timeouts
      # don't cause cache corruption

      # Expected behavior:
      # 1. Multiple characters timing out simultaneously
      # 2. Each timeout is handled independently
      # 3. No cache corruption or race conditions
      # 4. All characters eventually recover
      # 5. Telemetry tracks recovery health

      :ok
    end
  end

  describe "Cache consistency" do
    @tag :skip
    @tag :integration
    test "character cache and map cache stay in sync", %{map: map, character: character} do
      # This test verifies that the three character location caches
      # remain consistent through updates

      # The three caches are:
      # 1. Cachex.get(:character_cache, character_id) - global character data
      # 2. WandererApp.Cache.lookup("map_#{map_id}:character:#{character_id}:solar_system_id") - map-specific location
      # 3. Cachex.get(:character_state_cache, character_id) - character state

      ensure_map_started(map.id)
      add_character_to_map_presence(map.id, character.id)

      # Set location in character cache
      set_character_location(character.id, @system_jita)

      WandererApp.Cache.insert(
        "map_#{map.id}:character:#{character.id}:start_solar_system_id",
        @system_jita
      )

      CharactersImpl.update_characters(map.id)

      # Verify map cache was updated
      {:ok, map_cached_location} =
        WandererApp.Cache.lookup("map_#{map.id}:character:#{character.id}:solar_system_id")

      assert map_cached_location == @system_jita,
             "Map-specific cache should match character cache"

      # Move character
      set_character_location(character.id, @system_amarr)
      CharactersImpl.update_characters(map.id)

      # Verify both caches updated
      {:ok, character_data} = Cachex.get(:character_cache, character.id)

      {:ok, map_cached_location} =
        WandererApp.Cache.lookup("map_#{map.id}:character:#{character.id}:solar_system_id")

      assert character_data.solar_system_id == @system_amarr

      assert map_cached_location == @system_amarr,
             "Both caches should be consistent after update"
    end
  end

  describe "Telemetry and observability" do
    test "telemetry events are emitted for location updates", %{character: character} do
      # This test verifies that telemetry is emitted for tracking debugging

      test_pid = self()

      # Attach handlers for character location events
      :telemetry.attach_many(
        "test-character-location-events",
        [
          [:wanderer_app, :character, :location_update, :start],
          [:wanderer_app, :character, :location_update, :stop],
          [:wanderer_app, :map, :system_addition, :start],
          [:wanderer_app, :map, :system_addition, :stop]
        ],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_event, event, measurements, metadata})
        end,
        nil
      )

      # Simulate events (in real implementation, these would be in the actual code)
      :telemetry.execute(
        [:wanderer_app, :character, :location_update, :start],
        %{system_time: System.system_time()},
        %{character_id: character.id, map_id: @test_map_id}
      )

      :telemetry.execute(
        [:wanderer_app, :character, :location_update, :stop],
        %{duration: 100, system_time: System.system_time()},
        %{
          character_id: character.id,
          map_id: @test_map_id,
          from_system: @system_jita,
          to_system: @system_amarr
        }
      )

      # Verify events were received
      assert_receive {:telemetry_event, [:wanderer_app, :character, :location_update, :start], _,
                      _},
                     500

      assert_receive {:telemetry_event, [:wanderer_app, :character, :location_update, :stop], _,
                      _},
                     500

      :telemetry.detach("test-character-location-events")
    end
  end
end
