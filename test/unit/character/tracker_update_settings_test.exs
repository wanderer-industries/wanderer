defmodule WandererApp.Character.TrackerUpdateSettingsTest do
  @moduledoc """
  Regression tests for `WandererApp.Character.Tracker.update_settings/2`.

  `maybe_start_location_tracking/2` used to match `%{track_location: true}` in
  `track_settings`. No caller passes that key, so it never matched and the
  function could not turn location tracking on. That was harmless while nothing
  turned the flag off; once `maybe_stop_tracking/2` began clearing it, the flag
  could get stuck off. The trigger is not a user action: when a browser's
  presence lapses past the grace period the character is untracked server-side,
  `active_maps` empties, and both flags are cleared. The character is still
  online in EVE throughout, and `update_online/1` only writes the flag on an
  online-status transition — which a character who stays logged in never
  produces. So reconnecting could not restore it.
  """

  use ExUnit.Case, async: false

  alias WandererApp.Character.Tracker

  setup do
    character_id = "test-char-#{System.unique_integer([:positive])}"
    map_id = "test-map-#{System.unique_integer([:positive])}"

    on_exit(fn -> Cachex.del(:character_state_cache, character_id) end)

    %{character_id: character_id, map_id: map_id}
  end

  defp seed_state(character_id, overrides) do
    state =
      Tracker.new(%{character_id: character_id})
      |> Map.merge(overrides)

    Cachex.put(:character_state_cache, character_id, state)
    state
  end

  describe "update_settings/2 when map tracking starts" do
    test "restores location tracking for a character who is already online", %{
      character_id: character_id,
      map_id: map_id
    } do
      # The stuck state: online in EVE, flag cleared server-side after a
      # presence lapse, no online transition pending to restore it.
      seed_state(character_id, %{
        is_online: true,
        track_online: true,
        track_location: false,
        track_ship: false,
        active_maps: []
      })

      {:ok, state} = Tracker.update_settings(character_id, %{map_id: map_id, track: true})

      assert map_id in state.active_maps

      assert state.track_location,
             """
             While track_location is false, update_location/1 falls through to
             its catch-all and returns {:error, :skipped}, so the character's
             position is never fetched and the map never updates as they move.
             """

      assert state.track_ship, "track_ship has the same defect and the same fix"
    end

    test "enables location tracking even when the character is offline", %{
      character_id: character_id,
      map_id: map_id
    } do
      # track_location is an intent flag, not a liveness flag: update_location/1
      # independently requires is_online: true. Setting it while offline avoids
      # depending on an online transition that may never come.
      seed_state(character_id, %{
        is_online: false,
        track_online: true,
        track_location: false,
        track_ship: false,
        active_maps: []
      })

      {:ok, state} = Tracker.update_settings(character_id, %{map_id: map_id, track: true})

      assert state.track_location
      assert state.track_ship
    end

    test "is idempotent when tracking is already active for the map", %{
      character_id: character_id,
      map_id: map_id
    } do
      seed_state(character_id, %{
        is_online: true,
        track_online: true,
        track_location: true,
        track_ship: true,
        active_maps: [map_id]
      })

      {:ok, state} = Tracker.update_settings(character_id, %{map_id: map_id, track: true})

      assert state.track_location
      assert state.track_ship
      assert state.active_maps == [map_id], "map should not be duplicated in active_maps"
    end
  end

  describe "update_settings/2 when map tracking stops" do
    test "clears location and ship tracking once no maps remain active", %{
      character_id: character_id,
      map_id: map_id
    } do
      # Pins the other side of the fix: matching on active_maps must not keep
      # polling alive for a character who has left every map.
      seed_state(character_id, %{
        is_online: true,
        track_online: true,
        track_location: true,
        track_ship: true,
        active_maps: [map_id]
      })

      {:ok, state} = Tracker.update_settings(character_id, %{map_id: map_id, track: false})

      refute state.track_location
      refute state.track_ship
      assert state.active_maps == []
    end
  end
end
