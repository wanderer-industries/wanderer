defmodule WandererApp.CharactersTrackingLiveTest do
  @moduledoc """
  Integration tests for CharactersTrackingLive tracking functionality.

  These tests verify the fix for the bug where enabling tracking via the
  /tracking/:slug page (CharactersTrackingLive) only updated the database
  but did NOT set the tracking_start_time cache key, causing characters
  to not actually be tracked on the map.

  The fix ensures CharactersTrackingLive uses TrackingUtils.update_tracking()
  which properly sets:
  1. Database tracking flag (MapCharacterSettings.tracked = true)
  2. Runtime cache key (character:<id>:map:<map_id>:tracking_start_time)

  Related files:
  - lib/wanderer_app_web/live/characters/characters_tracking_live.ex
  - lib/wanderer_app/character/tracking_utils.ex
  - lib/wanderer_app/map.ex (get_tracked_character_ids)
  """

  use WandererApp.IntegrationCase, async: false

  import Mox
  import WandererApp.MapTestHelpers

  setup :verify_on_exit!

  @test_character_eve_id_1 3_100_000_001
  @test_character_eve_id_2 3_100_000_002

  setup do
    # Setup system static info cache for test systems
    setup_system_static_info_cache()

    # Setup DDRT (R-tree) mock stubs for system positioning
    setup_ddrt_mocks()

    # Create test user
    user =
      create_user(%{
        name: "Tracking Live Test User",
        hash: "tracking_live_test_hash_#{:rand.uniform(1_000_000)}"
      })

    # Create first test character
    character1 =
      create_character(%{
        eve_id: "#{@test_character_eve_id_1}",
        name: "Tracking Live Test Character 1",
        user_id: user.id,
        scopes: "esi-location.read_location.v1 esi-location.read_ship_type.v1",
        tracking_pool: "default"
      })

    # Create second test character (to test multiple character tracking)
    character2 =
      create_character(%{
        eve_id: "#{@test_character_eve_id_2}",
        name: "Tracking Live Test Character 2",
        user_id: user.id,
        scopes: "esi-location.read_location.v1 esi-location.read_ship_type.v1",
        tracking_pool: "default"
      })

    # Create test map owned by first character
    map =
      create_map(%{
        name: "Track Live Test",
        slug: "tracking-live-test-#{:rand.uniform(1_000_000)}",
        owner_id: character1.id,
        scope: :all,
        only_tracked_characters: false
      })

    on_exit(fn ->
      cleanup_test_data(map.id)
      cleanup_character_caches(map.id, character1.id)
      cleanup_character_caches(map.id, character2.id)
      cleanup_tracking_caches(character1.id, map.id)
      cleanup_tracking_caches(character2.id, map.id)
    end)

    {:ok, user: user, character1: character1, character2: character2, map: map}
  end

  describe "TrackingUtils.update_tracking sets tracking_start_time cache key" do
    @tag :integration
    test "enabling tracking via update_tracking sets tracking_start_time immediately", %{
      map: map,
      character1: character,
      user: user
    } do
      # Verify no tracking_start_time exists initially
      tracking_key = "character:#{character.id}:map:#{map.id}:tracking_start_time"
      {:ok, initial_value} = WandererApp.Cache.lookup(tracking_key)
      assert is_nil(initial_value), "tracking_start_time should not exist initially"

      # Call update_tracking (this is what CharactersTrackingLive now does)
      # The eve_id is passed as a string which is how it comes from the UI
      result =
        WandererApp.Character.TrackingUtils.update_tracking(
          map.id,
          character.eve_id,
          user.id,
          true,
          self(),
          false
        )

      assert {:ok, _tracking_data, _event} = result

      # Verify tracking_start_time is now set
      {:ok, tracking_start_time} = WandererApp.Cache.lookup(tracking_key)

      assert not is_nil(tracking_start_time),
             "tracking_start_time should be set immediately after enabling tracking"

      assert %DateTime{} = tracking_start_time,
             "tracking_start_time should be a DateTime"

      # Verify the time is recent (within last 5 seconds)
      time_diff = DateTime.diff(DateTime.utc_now(), tracking_start_time, :second)
      assert time_diff >= 0 and time_diff < 5, "tracking_start_time should be recent"
    end

    @tag :integration
    test "enabling tracking for multiple characters sets all tracking_start_times", %{
      map: map,
      character1: character1,
      character2: character2,
      user: user
    } do
      # Verify no tracking_start_time exists initially for either character
      tracking_key1 = "character:#{character1.id}:map:#{map.id}:tracking_start_time"
      tracking_key2 = "character:#{character2.id}:map:#{map.id}:tracking_start_time"

      {:ok, initial_value1} = WandererApp.Cache.lookup(tracking_key1)
      {:ok, initial_value2} = WandererApp.Cache.lookup(tracking_key2)

      assert is_nil(initial_value1), "tracking_start_time should not exist initially for char1"
      assert is_nil(initial_value2), "tracking_start_time should not exist initially for char2"

      # Enable tracking for first character
      {:ok, _, _} =
        WandererApp.Character.TrackingUtils.update_tracking(
          map.id,
          character1.eve_id,
          user.id,
          true,
          self(),
          false
        )

      # Enable tracking for second character
      {:ok, _, _} =
        WandererApp.Character.TrackingUtils.update_tracking(
          map.id,
          character2.eve_id,
          user.id,
          true,
          self(),
          false
        )

      # Verify both characters have tracking_start_time set
      {:ok, tracking_time1} = WandererApp.Cache.lookup(tracking_key1)
      {:ok, tracking_time2} = WandererApp.Cache.lookup(tracking_key2)

      assert not is_nil(tracking_time1),
             "Character 1 should have tracking_start_time set"

      assert not is_nil(tracking_time2),
             "Character 2 should have tracking_start_time set"
    end

    @tag :integration
    test "disabling tracking via update_tracking works correctly", %{
      map: map,
      character1: character,
      user: user
    } do
      # First enable tracking
      {:ok, _, _} =
        WandererApp.Character.TrackingUtils.update_tracking(
          map.id,
          character.eve_id,
          user.id,
          true,
          self(),
          false
        )

      # Verify tracking is enabled
      {:ok, settings} =
        WandererApp.MapCharacterSettingsRepo.get(map.id, character.id)

      assert settings.tracked == true, "Character should be tracked after enabling"

      # Now disable tracking
      {:ok, _, _} =
        WandererApp.Character.TrackingUtils.update_tracking(
          map.id,
          character.eve_id,
          user.id,
          false,
          self(),
          false
        )

      # Verify tracking is disabled in database
      {:ok, updated_settings} =
        WandererApp.MapCharacterSettingsRepo.get(map.id, character.id)

      assert updated_settings.tracked == false, "Character should be untracked after disabling"
    end

    @tag :integration
    test "toggle tracking on and off maintains correct state", %{
      map: map,
      character1: character,
      user: user
    } do
      tracking_key = "character:#{character.id}:map:#{map.id}:tracking_start_time"

      # Initial state: not tracked
      {:ok, initial_time} = WandererApp.Cache.lookup(tracking_key)
      assert is_nil(initial_time)

      # Toggle ON
      {:ok, _, _} =
        WandererApp.Character.TrackingUtils.update_tracking(
          map.id,
          character.eve_id,
          user.id,
          true,
          self(),
          false
        )

      {:ok, time_after_on} = WandererApp.Cache.lookup(tracking_key)
      assert not is_nil(time_after_on), "tracking_start_time should be set after toggle ON"

      {:ok, settings_on} = WandererApp.MapCharacterSettingsRepo.get(map.id, character.id)
      assert settings_on.tracked == true

      # Toggle OFF
      {:ok, _, _} =
        WandererApp.Character.TrackingUtils.update_tracking(
          map.id,
          character.eve_id,
          user.id,
          false,
          self(),
          false
        )

      {:ok, settings_off} = WandererApp.MapCharacterSettingsRepo.get(map.id, character.id)
      assert settings_off.tracked == false

      # Toggle ON again
      {:ok, _, _} =
        WandererApp.Character.TrackingUtils.update_tracking(
          map.id,
          character.eve_id,
          user.id,
          true,
          self(),
          false
        )

      {:ok, time_after_second_on} = WandererApp.Cache.lookup(tracking_key)

      assert not is_nil(time_after_second_on),
             "tracking_start_time should be set after second toggle ON"

      {:ok, settings_on_again} = WandererApp.MapCharacterSettingsRepo.get(map.id, character.id)
      assert settings_on_again.tracked == true
    end
  end

  describe "Database and cache consistency" do
    @tag :integration
    test "tracking state is consistent between database and cache", %{
      map: map,
      character1: character,
      user: user
    } do
      tracking_key = "character:#{character.id}:map:#{map.id}:tracking_start_time"

      # Enable tracking
      {:ok, _, _} =
        WandererApp.Character.TrackingUtils.update_tracking(
          map.id,
          character.eve_id,
          user.id,
          true,
          self(),
          false
        )

      # Check database state
      {:ok, db_settings} = WandererApp.MapCharacterSettingsRepo.get(map.id, character.id)
      assert db_settings.tracked == true, "Database should show tracked=true"

      # Check cache state
      {:ok, cache_time} = WandererApp.Cache.lookup(tracking_key)
      assert not is_nil(cache_time), "Cache should have tracking_start_time"

      # Both should indicate the character is being tracked
    end

    @tag :integration
    test "stale location caches are cleared when tracking is re-enabled", %{
      map: map,
      character1: character,
      user: user
    } do
      # Set up stale location caches (simulating previous tracking session)
      WandererApp.Cache.insert(
        "map:#{map.id}:character:#{character.id}:solar_system_id",
        30_000_142
      )

      WandererApp.Cache.insert(
        "map:#{map.id}:character:#{character.id}:station_id",
        60_003_760
      )

      WandererApp.Cache.insert(
        "map:#{map.id}:character:#{character.id}:structure_id",
        1_000_000_001
      )

      # Verify stale caches exist
      {:ok, stale_system} =
        WandererApp.Cache.lookup("map:#{map.id}:character:#{character.id}:solar_system_id")

      assert stale_system == 30_000_142

      # Enable tracking (this should clear stale location caches)
      {:ok, _, _} =
        WandererApp.Character.TrackingUtils.update_tracking(
          map.id,
          character.eve_id,
          user.id,
          true,
          self(),
          false
        )

      # Verify stale caches are cleared
      {:ok, cleared_system} =
        WandererApp.Cache.lookup("map:#{map.id}:character:#{character.id}:solar_system_id")

      {:ok, cleared_station} =
        WandererApp.Cache.lookup("map:#{map.id}:character:#{character.id}:station_id")

      {:ok, cleared_structure} =
        WandererApp.Cache.lookup("map:#{map.id}:character:#{character.id}:structure_id")

      assert is_nil(cleared_system), "solar_system_id cache should be cleared"
      assert is_nil(cleared_station), "station_id cache should be cleared"
      assert is_nil(cleared_structure), "structure_id cache should be cleared"
    end
  end

  describe "Error handling" do
    @tag :integration
    test "update_tracking returns error for invalid character", %{
      map: map,
      user: user
    } do
      # Try to enable tracking for a non-existent character
      result =
        WandererApp.Character.TrackingUtils.update_tracking(
          map.id,
          "999999999999",
          user.id,
          true,
          self(),
          false
        )

      assert {:error, _reason} = result
    end

    @tag :integration
    test "update_tracking handles nil caller_pid gracefully", %{
      map: map,
      character1: character,
      user: user
    } do
      # Calling with nil caller_pid should return an error
      result =
        WandererApp.Character.TrackingUtils.update_tracking(
          map.id,
          character.eve_id,
          user.id,
          true,
          nil,
          false
        )

      assert {:error, _reason} = result
    end
  end

  # Helper function to cleanup tracking-specific caches
  defp cleanup_tracking_caches(character_id, map_id) do
    WandererApp.Cache.delete("character:#{character_id}:map:#{map_id}:tracking_start_time")
    WandererApp.Cache.delete("#{character_id}:track_requested")

    # Clean up presence subscription cache
    WandererApp.Cache.delete("#{inspect(self())}_map_#{map_id}:character_#{character_id}:tracked")

    # Clean up untrack queue
    WandererApp.Cache.insert_or_update(
      "character_untrack_queue",
      [],
      fn queue ->
        Enum.reject(queue, fn {m_id, c_id} ->
          m_id == map_id and c_id == character_id
        end)
      end
    )
  end
end
