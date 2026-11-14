defmodule WandererAppWeb.MapCharactersLiveTest do
  use WandererAppWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias WandererApp.{Cache, Character, MapCharacterSettingsRepo}
  alias WandererAppWeb.{Factory, MapCharactersLive}

  setup %{conn: conn} do
    user = Factory.insert(:user, %{})
    owner = Factory.insert(:character, %{user_id: user.id})
    map = Factory.insert(:map, %{owner_id: owner.id})
    other_map = Factory.insert(:map, %{owner_id: owner.id})

    present = member(map, user, true)
    viewer = member(map, user, false)
    absent = member(map, user, true)
    untracked = member(map, user, false)
    other = member(other_map, user, true)

    put_presence(map, [presence(present, true), presence(viewer, false)])
    Cachex.put(:character_state_cache, present.id, %{is_online: true, active_maps: []})
    Cachex.put(:character_state_cache, viewer.id, %{is_online: false, active_maps: []})

    on_exit(fn -> Cache.delete("map_#{map.id}:presence_data") end)

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Plug.Conn.put_session(:user_id, user.id)

    %{
      conn: conn,
      user: user,
      map: map,
      other_map: other_map,
      present: present,
      viewer: viewer,
      absent: absent,
      untracked: untracked,
      other: other
    }
  end

  test "defaults to mapper sessions including viewers, not every tracked member", ctx do
    {:ok, view, _} = live(ctx.conn, ~p"/#{ctx.map.slug}/characters")

    assert selected?(view, "active")
    assert has_element?(view, "#character-view-heading", "Active sessions (2)")
    assert row?(view, ctx.present)
    assert row?(view, ctx.viewer)
    refute row?(view, ctx.absent)
    refute row?(view, ctx.untracked)
    refute row?(view, ctx.other)
    assert has_element?(view, "#map-character-#{ctx.present.id}", "EVE online")
    assert has_element?(view, "#map-character-#{ctx.viewer.id}", "EVE offline")
    assert has_element?(view, "#map-character-#{ctx.viewer.id}", "Viewer (not tracked)")
  end

  test "shows all saved tracked characters for this map without mutating settings", ctx do
    {:ok, view, _} = live(ctx.conn, ~p"/#{ctx.map.slug}/characters")
    change_view(view, "tracked")

    assert selected?(view, "tracked")
    assert has_element?(view, "#character-view-heading", "All tracked characters (2)")
    assert row?(view, ctx.present)
    assert row?(view, ctx.absent)
    refute row?(view, ctx.viewer)
    refute row?(view, ctx.untracked)
    refute row?(view, ctx.other)
    assert {:ok, settings} = MapCharacterSettingsRepo.get_all_by_map(ctx.map.id)
    assert Enum.count(settings, &(&1.tracked == true)) == 2

    change_view(view, "active")
    assert selected?(view, "active")
    assert row?(view, ctx.viewer)
    refute row?(view, ctx.absent)
  end

  test "renders absent tracking preferences without inventing a session or runtime state", ctx do
    assert {:ok, nil} = Character.get_character_state(ctx.absent.id, false)
    {:ok, view, _} = live(ctx.conn, ~p"/#{ctx.map.slug}/characters")
    change_view(view, "tracked")

    row = "#map-character-#{ctx.absent.id}"
    assert has_element?(view, row, "No active session")
    assert has_element?(view, row, "Tracking enabled")
    assert has_element?(view, row, "EVE status unknown")
    refute has_element?(view, "#{row} [phx-hook='LocalTime']")
    assert {:ok, nil} = Character.get_character_state(ctx.absent.id, false)
  end

  test "does not truncate tracked rosters above twenty entries", ctx do
    extras = Enum.map(1..23, fn _ -> member(ctx.map, ctx.user, true) end)
    {:ok, view, _} = live(ctx.conn, ~p"/#{ctx.map.slug}/characters")
    change_view(view, "tracked")

    for character <- [ctx.present, ctx.absent | extras] do
      Cachex.del(:character_cache, character.id)
    end

    reads =
      count_character_reads(fn ->
        send(view.pid, :refresh_tracking_data)
        render(view)
      end)

    assert reads == 1

    assert count_character_reads(fn ->
             send(view.pid, :refresh_tracking_data)
             render(view)
           end) == 0

    assert has_element?(view, "#character-view-heading", "All tracked characters (25)")
    assert has_element?(view, "#map-character-#{ctx.present.id} time", "2026-10-14T12:00:00Z")
    assert has_element?(view, "#map-character-#{ctx.absent.id}", "No active session")
    refute row?(view, ctx.viewer)

    assert view
           |> render()
           |> Floki.parse_fragment!()
           |> Floki.find("li[id^='map-character-']")
           |> length() == 25
  end

  test "batch loads uncached active sessions without dropping viewers or presence metadata",
       ctx do
    {:ok, view, _} = live(ctx.conn, ~p"/#{ctx.map.slug}/characters")
    Cachex.del(:character_cache, ctx.present.id)
    Cachex.del(:character_cache, ctx.viewer.id)

    reads =
      count_character_reads(fn ->
        send(view.pid, :refresh_tracking_data)
        render(view)
      end)

    assert reads == 1
    assert has_element?(view, "#map-character-#{ctx.present.id}", ctx.present.name)
    assert has_element?(view, "#map-character-#{ctx.viewer.id}", ctx.viewer.name)
    assert has_element?(view, "#map-character-#{ctx.viewer.id}", "Viewer (not tracked)")
    assert has_element?(view, "#map-character-#{ctx.present.id} time", "2026-10-14T12:00:00Z")
    refute row?(view, ctx.absent)
  end

  test "preserves cached character data while batch loading missing records", ctx do
    {:ok, view, _} = live(ctx.conn, ~p"/#{ctx.map.slug}/characters")
    change_view(view, "tracked")
    {:ok, _} = Character.get_character(ctx.present.id)
    Character.update_character(ctx.present.id, %{name: "Cached pilot name"})
    Cachex.del(:character_cache, ctx.absent.id)

    reads =
      count_character_reads(fn ->
        send(view.pid, :refresh_tracking_data)
        render(view)
      end)

    assert reads == 1
    assert has_element?(view, "#map-character-#{ctx.present.id}", "Cached pilot name")
    assert has_element?(view, "#map-character-#{ctx.absent.id}", ctx.absent.name)
  end

  test "keeps the selected view while refreshing saved tracking preferences", ctx do
    {:ok, view, _} = live(ctx.conn, ~p"/#{ctx.map.slug}/characters")
    change_view(view, "tracked")

    {:ok, _} =
      MapCharacterSettingsRepo.untrack(%{map_id: ctx.map.id, character_id: ctx.absent.id})

    put_presence(ctx.map, [])

    send(view.pid, :refresh_tracking_data)
    render(view)

    assert selected?(view, "tracked")
    assert row?(view, ctx.present)
    refute row?(view, ctx.absent)
    assert has_element?(view, "#character-view-heading", "All tracked characters (1)")
    assert has_element?(view, "#map-character-#{ctx.present.id}", "No active session")
  end

  test "refreshes active sessions without resetting the view", ctx do
    {:ok, view, _} = live(ctx.conn, ~p"/#{ctx.map.slug}/characters")
    put_presence(ctx.map, [presence(ctx.viewer, false)])
    send(view.pid, :refresh_tracking_data)
    render(view)

    assert selected?(view, "active")
    assert row?(view, ctx.viewer)
    refute row?(view, ctx.present)
  end

  test "ignores unknown view values and resets to active on a new visit", ctx do
    {:ok, view, _} = live(ctx.conn, ~p"/#{ctx.map.slug}/characters")
    change_view(view, "tracked")
    render_click(view, "change_character_view", %{"view" => "invalid"})
    assert selected?(view, "tracked")

    {:ok, revisited, _} = live(ctx.conn, ~p"/#{ctx.map.slug}/characters")
    assert selected?(revisited, "active")
    assert row?(revisited, ctx.viewer)
  end

  test "treats a nullable saved flag as disabled even if presence still says tracked", ctx do
    nullable = member(ctx.map, ctx.user, nil)
    put_presence(ctx.map, [presence(nullable, true)])
    {:ok, view, _} = live(ctx.conn, ~p"/#{ctx.map.slug}/characters")

    assert has_element?(view, "#map-character-#{nullable.id}", "Viewer (not tracked)")
    change_view(view, "tracked")
    refute row?(view, nullable)
  end

  test "shows distinct empty states for active sessions and tracked preferences", ctx do
    put_presence(ctx.map, [])
    {:ok, view, _} = live(ctx.conn, ~p"/#{ctx.map.slug}/characters")
    assert has_element?(view, "#character-list-empty", "No active mapper sessions.")

    for character <- [ctx.present, ctx.absent] do
      {:ok, _} =
        MapCharacterSettingsRepo.untrack(%{map_id: ctx.map.id, character_id: character.id})
    end

    assert count_character_reads(fn -> change_view(view, "tracked") end) == 0

    assert has_element?(
             view,
             "#character-list-empty",
             "No characters have tracking enabled for this map."
           )
  end

  test "skips missing presence characters instead of crashing the roster", ctx do
    put_presence(ctx.map, [
      presence(ctx.present, true),
      %{character_id: Ecto.UUID.generate(), tracked: true, from: DateTime.utc_now()}
    ])

    ExUnit.CaptureLog.capture_log(fn ->
      {:ok, view, _} = live(ctx.conn, ~p"/#{ctx.map.slug}/characters")
      assert row?(view, ctx.present)
      assert has_element?(view, "#character-view-heading", "Active sessions (1)")

      assert has_element?(
               view,
               "#character-list-incomplete",
               "Some characters could not be loaded."
             )

      put_presence(ctx.map, [presence(ctx.present, true)])
      send(view.pid, :refresh_tracking_data)
      render(view)
      refute has_element?(view, "#character-list-incomplete")
    end)
  end

  test "does not claim the roster is empty when every character lookup fails", ctx do
    put_presence(ctx.map, [
      %{character_id: Ecto.UUID.generate(), tracked: true, from: DateTime.utc_now()}
    ])

    ExUnit.CaptureLog.capture_log(fn ->
      {:ok, view, _} = live(ctx.conn, ~p"/#{ctx.map.slug}/characters")
      assert has_element?(view, "#character-list-incomplete")
      refute has_element?(view, "#character-list-empty")
    end)
  end

  test "reports a failed settings read instead of a successful empty roster" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        map_id: "invalid-map-id",
        character_view: :tracked,
        groups: [],
        characters_count: 0
      }
    }

    ExUnit.CaptureLog.capture_log(fn ->
      assert {:noreply, socket} = MapCharactersLive.handle_info(:refresh_tracking_data, socket)
      assert socket.assigns.characters_load_error
      assert socket.assigns.groups == []
    end)
  end

  test "does not authorize an unrelated user to administer character tracking", ctx do
    outsider = Factory.insert(:user, %{}) |> Ash.load!(:characters)

    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, flash: %{}, current_user: outsider}
    }

    assert {:ok, socket} = MapCharactersLive.mount(%{"slug" => ctx.map.slug}, %{}, socket)
    assert {:live, :redirect, %{to: "/maps"}} = socket.redirected
    refute Map.has_key?(socket.assigns, :map_id)
  end

  describe "administrator untrack" do
    test "disables an absent character's saved preference and retains the tracked view", ctx do
      Factory.insert(:map_character_settings, %{
        map_id: ctx.other_map.id,
        character_id: ctx.absent.id,
        tracked: true
      })

      {:ok, view, _} = live(ctx.conn, ~p"/#{ctx.map.slug}/characters")
      change_view(view, "tracked")

      view
      |> element("#map-character-#{ctx.absent.id} button[phx-click='untrack']")
      |> render_click()

      assert {:ok, %{tracked: false}} = MapCharacterSettingsRepo.get(ctx.map.id, ctx.absent.id)

      assert {:ok, %{tracked: true}} =
               MapCharacterSettingsRepo.get(ctx.other_map.id, ctx.absent.id)

      assert selected?(view, "tracked")
      refute row?(view, ctx.absent)
      assert has_element?(view, "#character-view-heading", "All tracked characters (1)")
    end

    test "persists before requesting runtime stop and shows a present character as a viewer",
         ctx do
      Cachex.put(:character_state_cache, ctx.present.id, %{
        is_online: true,
        active_maps: [ctx.map.id]
      })

      observe_runtime_stop(ctx.present.id, fn ->
        MapCharacterSettingsRepo.get(ctx.map.id, ctx.present.id)
      end)

      {:ok, view, _} = live(ctx.conn, ~p"/#{ctx.map.slug}/characters")
      change_view(view, "tracked")

      view
      |> element("#map-character-#{ctx.present.id} button[phx-click='untrack']")
      |> render_click()

      assert_receive {:runtime_stop, _reason, {:ok, %{tracked: false}}}
      assert selected?(view, "tracked")
      refute row?(view, ctx.present)
      change_view(view, "active")
      assert has_element?(view, "#map-character-#{ctx.present.id}", "Viewer (not tracked)")
      refute has_element?(view, "#map-character-#{ctx.present.id} button[phx-click='untrack']")
    end

    test "keeps active sessions selected when untracking a present character", ctx do
      {:ok, view, _} = live(ctx.conn, ~p"/#{ctx.map.slug}/characters")

      view
      |> element("#map-character-#{ctx.present.id} button[phx-click='untrack']")
      |> render_click()

      assert selected?(view, "active")
      assert has_element?(view, "#map-character-#{ctx.present.id}", "Viewer (not tracked)")
      assert has_element?(view, "#character-view-heading", "Active sessions (2)")
      assert {:ok, %{tracked: false}} = MapCharacterSettingsRepo.get(ctx.map.id, ctx.present.id)
    end

    test "keeps the saved preference disabled when a pending presence join arrives", ctx do
      prepare_presence_join(ctx.map, ctx.present)
      {:ok, view, _} = live(ctx.conn, ~p"/#{ctx.map.slug}/characters")
      change_view(view, "tracked")

      view
      |> element("#map-character-#{ctx.present.id} button[phx-click='untrack']")
      |> render_click()

      assert {:ok, %{tracked: false}} = MapCharacterSettingsRepo.get(ctx.map.id, ctx.present.id)

      complete_presence_join(ctx.map, ctx.present)

      assert {:ok, %{tracked: false}} = MapCharacterSettingsRepo.get(ctx.map.id, ctx.present.id)
      assert {:ok, %{active_maps: []}} = Character.get_character_state(ctx.present.id, false)
      send(view.pid, :refresh_tracking_data)
      render(view)
      assert selected?(view, "tracked")
      refute row?(view, ctx.present)
    end

    test "does not treat refreshed credentials as consent to re-enable tracking", ctx do
      prepare_presence_join(ctx.map, ctx.present)

      {:ok, _} =
        MapCharacterSettingsRepo.untrack(%{map_id: ctx.map.id, character_id: ctx.present.id})

      refresh_character_credentials(ctx.present)

      complete_presence_join(ctx.map, ctx.present)

      assert {:ok, %{tracked: false}} = MapCharacterSettingsRepo.get(ctx.map.id, ctx.present.id)
      assert {:ok, %{active_maps: []}} = Character.get_character_state(ctx.present.id, false)
    end

    test "resumes enabled tracking with refreshed credentials", ctx do
      prepare_presence_join(ctx.map, ctx.present)
      refresh_character_credentials(ctx.present)

      complete_presence_join(ctx.map, ctx.present)

      assert {:ok, %{tracked: true}} = MapCharacterSettingsRepo.get(ctx.map.id, ctx.present.id)
      assert {:ok, state} = Character.get_character_state(ctx.present.id, false)
      assert ctx.map.id in state.active_maps
      assert state.track_location
      assert state.track_ship
    end

    test "permits an explicit tracking enable after administrator untrack", ctx do
      prepare_presence_join(ctx.map, ctx.present)

      {:ok, _} =
        MapCharacterSettingsRepo.untrack(%{map_id: ctx.map.id, character_id: ctx.present.id})

      # This is the same saved-preference action used by TrackingUtils.update_tracking/6.
      {:ok, _} =
        MapCharacterSettingsRepo.track(%{map_id: ctx.map.id, character_id: ctx.present.id})

      complete_presence_join(ctx.map, ctx.present)

      assert {:ok, %{tracked: true}} = MapCharacterSettingsRepo.get(ctx.map.id, ctx.present.id)
      assert {:ok, state} = Character.get_character_state(ctx.present.id, false)
      assert ctx.map.id in state.active_maps
    end

    test "ignores unknown ids, other-map targets, and already-untracked viewers", ctx do
      {:ok, view, _} = live(ctx.conn, ~p"/#{ctx.map.slug}/characters")

      for id <- [Ecto.UUID.generate(), ctx.other.id, ctx.viewer.id] do
        render_click(view, "untrack", %{"event-data" => id})
      end

      assert {:ok, %{tracked: true}} =
               MapCharacterSettingsRepo.get(ctx.other_map.id, ctx.other.id)

      assert {:ok, %{tracked: false}} = MapCharacterSettingsRepo.get(ctx.map.id, ctx.viewer.id)
      assert {:ok, %{tracked: true}} = MapCharacterSettingsRepo.get(ctx.map.id, ctx.present.id)
      refute render(view) =~ "Character untracked!"
    end

    test "does not request runtime stop or claim success when the repository rejects untrack",
         ctx do
      invalid_map_id = "invalid-map-id"
      Cachex.put(:character_state_cache, ctx.present.id, %{active_maps: [invalid_map_id]})
      observe_runtime_stop(ctx.present.id, fn -> :unexpected_stop end)

      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          flash: %{},
          map_id: invalid_map_id,
          current_user: ctx.user,
          character_view: :tracked,
          character_settings: [
            %{map_id: invalid_map_id, character_id: ctx.present.id, tracked: true}
          ]
        }
      }

      ExUnit.CaptureLog.capture_log(fn ->
        assert {:noreply, socket} =
                 MapCharactersLive.handle_event(
                   "untrack",
                   %{"event-data" => ctx.present.id},
                   socket
                 )

        assert socket.assigns.flash["error"] == "Unable to untrack character. Please try again."
        refute Map.has_key?(socket.assigns.flash, "info")
        assert socket.assigns.character_view == :tracked
        refute_receive {:runtime_stop, _, _}
      end)
    end
  end

  defp count_character_reads(fun) do
    {:ok, counter} = Agent.start_link(fn -> 0 end)
    handler_id = {__MODULE__, :character_reads, System.unique_integer([:positive])}

    :telemetry.attach(
      handler_id,
      [:wanderer_app, :repo, :query],
      fn _event, _measurements, metadata, _config ->
        if metadata[:source] == "character_v1" and
             String.starts_with?(metadata[:query] || "", "SELECT") do
          Agent.update(counter, &(&1 + 1))
        end
      end,
      nil
    )

    try do
      fun.()
      Agent.get(counter, & &1)
    after
      :telemetry.detach(handler_id)
      Agent.stop(counter)
    end
  end

  defp prepare_presence_join(map, character) do
    # ConnCase does not start the production tracker manager. Run the real manager
    # with isolated queues so its normal startup cannot consume other tests' work.
    queue_keys = ["tracked_characters", "track_characters_queue", "character_untrack_queue"]
    original_queues = Map.new(queue_keys, &{&1, Cache.lookup!(&1)})
    Enum.each(queue_keys, &Cache.insert(&1, []))
    on_exit(fn -> Enum.each(original_queues, fn {key, value} -> Cache.insert(key, value) end) end)
    start_supervised!({WandererApp.Character.TrackerManager, []})

    Cachex.put(:character_cache, character.id, %{character | access_token: "presence-test-token"})

    Cachex.put(
      :character_state_cache,
      character.id,
      WandererApp.Character.Tracker.new(%{character_id: character.id, is_online: true})
    )

    Cachex.put(:map_cache, map.id, %WandererApp.Map{map_id: map.id, owner_id: map.owner_id})

    on_exit(fn ->
      Cachex.del(:map_cache, map.id)
      Cache.delete("character:#{character.id}:map:#{map.id}:tracking_start_time")
    end)
  end

  defp refresh_character_credentials(character) do
    attrs = %{
      access_token: "refreshed-presence-test-token",
      refresh_token: "refreshed-test-token"
    }

    {:ok, _} = WandererApp.Api.Character.update(character, attrs)
    Character.update_character(character.id, attrs)
  end

  defp complete_presence_join(map, character) do
    test_pid = self()
    handler_id = "presence-join-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler_id,
      [:wanderer_app, :map, :character, :added],
      fn _event, _measurements, _metadata, _config ->
        send(test_pid, :presence_character_added)
      end,
      nil
    )

    try do
      WandererApp.Map.Server.CharactersImpl.track_characters(map.id, [character.id])
      assert_receive :presence_character_added, 1_000

      # The enable cast is sent by this process, so the call orders the runtime assertions after it.
      :sys.get_state(WandererApp.Character.TrackerManager)
    after
      :telemetry.detach(handler_id)
    end
  end

  defp observe_runtime_stop(character_id, read_preference) do
    test_pid = self()
    handler_id = "admin-untrack-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler_id,
      [:wanderer_app, :character, :tracking, :stopped],
      fn _event, _measurements, metadata, _config ->
        if metadata.character_id == character_id do
          send(test_pid, {:runtime_stop, metadata.reason, read_preference.()})
        end
      end,
      nil
    )

    on_exit(fn ->
      :telemetry.detach(handler_id)

      Cache.insert_or_update("character_untrack_queue", [], fn queue ->
        Enum.reject(queue, fn {_map_id, id} -> id == character_id end)
      end)
    end)
  end

  defp member(map, user, tracked) do
    character = Factory.insert(:character, %{user_id: user.id})

    Factory.insert(:map_character_settings, %{
      map_id: map.id,
      character_id: character.id,
      tracked: tracked
    })

    on_exit(fn ->
      Cachex.del(:character_cache, character.id)
      Cachex.del(:character_state_cache, character.id)
    end)

    character
  end

  defp presence(character, tracked) do
    %{character_id: character.id, tracked: tracked, from: ~U[2026-10-14 12:00:00Z]}
  end

  defp put_presence(map, characters), do: Cache.insert("map_#{map.id}:presence_data", characters)

  defp change_view(view, value),
    do: view |> element("button[phx-value-view='#{value}']") |> render_click()

  defp selected?(view, value),
    do: has_element?(view, "button[phx-value-view='#{value}'][aria-pressed='true']")

  defp row?(view, character), do: has_element?(view, "#map-character-#{character.id}")
end
