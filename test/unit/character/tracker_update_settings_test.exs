defmodule WandererApp.Character.TrackerUpdateSettingsTest do
  use ExUnit.Case, async: false

  alias WandererApp.Character
  alias WandererApp.Character.Tracker
  alias WandererApp.Character.TrackerManager.Impl, as: TrackerManagerImpl

  setup do
    character_id = "test-char-#{System.unique_integer([:positive])}"
    map_id = "test-map-#{System.unique_integer([:positive])}"

    on_exit(fn ->
      Cachex.del(:character_state_cache, character_id)
      WandererApp.Cache.delete("character:#{character_id}:last_active_time")
    end)

    %{character_id: character_id, map_id: map_id}
  end

  defp seed_state(character_id, overrides \\ %{}) do
    state =
      Tracker.new(%{character_id: character_id})
      |> Map.merge(overrides)

    Cachex.put(:character_state_cache, character_id, state)
    state
  end

  describe "universal consumers" do
    test "registers maps with the fast profile", %{
      character_id: character_id,
      map_id: map_id
    } do
      seed_state(character_id)

      assert {:ok, state} =
               Tracker.update_settings(character_id, %{map_id: map_id, track: true})

      assert state.consumers == %{{:map, map_id} => :fast}
      assert Tracker.consumer_registered?(state, {:map, map_id})
    end

    test "registers page consumers with the slow profile", %{character_id: character_id} do
      seed_state(character_id)
      consumer_id = {:characters_page, self()}

      assert {:ok, state} =
               Tracker.update_consumer(character_id, consumer_id, :slow, true)

      assert state.consumers == %{consumer_id => :slow}
    end

    test "selects the fastest eligible interval per request" do
      fast_consumer = {:map, "map-id"}
      slow_consumer = {:characters_page, self()}

      online_state =
        Tracker.new(%{
          character_id: "online-character",
          is_online: true,
          consumers: %{fast_consumer => :fast, slow_consumer => :slow}
        })

      offline_state = %{online_state | is_online: false}

      assert Tracker.polling_interval(online_state, :location) == 0
      assert Tracker.polling_interval(online_state, :ship) == 0
      assert Tracker.polling_interval(offline_state, :location) == :timer.minutes(1)
      assert Tracker.polling_interval(offline_state, :ship) == :timer.minutes(1)

      map_only_offline = %{offline_state | consumers: %{fast_consumer => :fast}}
      assert is_nil(Tracker.polling_interval(map_only_offline, :location))
      assert is_nil(Tracker.polling_interval(map_only_offline, :ship))
    end

    test "registration is idempotent", %{character_id: character_id, map_id: map_id} do
      seed_state(character_id)

      assert {:ok, _state} =
               Tracker.update_settings(character_id, %{map_id: map_id, track: true})

      assert {:ok, state} =
               Tracker.update_settings(character_id, %{map_id: map_id, track: true})

      assert state.consumers == %{{:map, map_id} => :fast}
    end

    test "keeps the tracker active until its final consumer is removed", %{
      character_id: character_id,
      map_id: map_id
    } do
      seed_state(character_id)
      page_consumer = {:characters_page, self()}

      assert {:ok, _state} =
               Tracker.update_settings(character_id, %{map_id: map_id, track: true})

      assert {:ok, _state} =
               Tracker.update_consumer(character_id, page_consumer, :slow, true)

      assert {:ok, state} =
               Tracker.update_settings(character_id, %{map_id: map_id, track: false})

      assert state.consumers == %{page_consumer => :slow}
      refute WandererApp.Cache.has_key?("character:#{character_id}:last_active_time")

      assert {:ok, state} =
               Tracker.update_consumer(character_id, page_consumer, :slow, false)

      assert state.consumers == %{}
      assert WandererApp.Cache.has_key?("character:#{character_id}:last_active_time")
    end

    test "migrates legacy map and page registrations on the next update", %{
      character_id: character_id,
      map_id: map_id
    } do
      legacy_page_pid = self()

      seed_state(character_id, %{
        active_maps: [map_id],
        characters_consumers: %{legacy_page_pid => true}
      })

      new_consumer = {:characters_page, make_ref()}

      assert {:ok, state} =
               Tracker.update_consumer(character_id, new_consumer, :slow, true)

      assert state.consumers == %{
               {:map, map_id} => :fast,
               {:characters_page, legacy_page_pid} => :slow,
               new_consumer => :slow
             }

      refute Map.has_key?(state, :active_maps)
      refute Map.has_key?(state, :characters_consumers)
    end
  end

  describe "ship polling" do
    test "respects online_forbidden for online characters even with a slow consumer", %{
      character_id: character_id,
      map_id: map_id
    } do
      Cachex.put(:character_cache, character_id, %{
        id: character_id,
        eve_id: "1",
        access_token: "token",
        tracking_pool: "default"
      })

      WandererApp.Cache.put("character:#{character_id}:online_forbidden", true)

      on_exit(fn ->
        Cachex.del(:character_cache, character_id)
        WandererApp.Cache.delete("character:#{character_id}:online_forbidden")
      end)

      state =
        seed_state(character_id, %{
          is_online: true,
          consumers: %{{:map, map_id} => :fast, {:characters_page, self()} => :slow}
        })

      assert Tracker.update_ship(state) == {:error, :skipped}
    end
  end

  describe "tracker manager restart" do
    test "prunes page consumers whose process is gone", %{
      character_id: character_id,
      map_id: map_id
    } do
      dead_pid = spawn(fn -> :ok end)
      ref = Process.monitor(dead_pid)
      assert_receive {:DOWN, ^ref, :process, ^dead_pid, _reason}

      live_consumer = {:characters_page, self()}

      seed_state(character_id, %{
        consumers: %{
          {:map, map_id} => :fast,
          {:characters_page, dead_pid} => :slow,
          live_consumer => :slow
        }
      })

      {:ok, previous_tracked} = WandererApp.Cache.lookup("tracked_characters", [])
      WandererApp.Cache.insert("tracked_characters", [character_id])

      on_exit(fn ->
        WandererApp.Cache.insert("tracked_characters", previous_tracked)
        WandererApp.Cache.delete("#{character_id}:track_requested")

        WandererApp.Cache.insert_or_update("track_characters_queue", [], fn queue ->
          Enum.reject(queue, &(&1 == character_id))
        end)
      end)

      TrackerManagerImpl.new(%{characters: [], opts: %{}, consumers: %{}})
      |> TrackerManagerImpl.start()

      assert Character.get_character_state!(character_id).consumers == %{
               {:map, map_id} => :fast,
               live_consumer => :slow
             }
    end

    test "restores monitoring for a surviving page consumer", %{character_id: character_id} do
      page_pid = spawn(fn -> Process.sleep(:infinity) end)
      consumer_id = {:characters_page, page_pid}

      seed_state(character_id, %{consumers: %{consumer_id => :slow}})

      {:ok, previous_tracked} = WandererApp.Cache.lookup("tracked_characters", [])
      WandererApp.Cache.insert("tracked_characters", [character_id])

      on_exit(fn ->
        WandererApp.Cache.insert("tracked_characters", previous_tracked)
        WandererApp.Cache.delete("#{character_id}:track_requested")

        WandererApp.Cache.insert_or_update("track_characters_queue", [], fn queue ->
          Enum.reject(queue, &(&1 == character_id))
        end)

        if Process.alive?(page_pid) do
          Process.exit(page_pid, :kill)
        end
      end)

      manager_state =
        TrackerManagerImpl.new(%{characters: [], opts: %{}, consumers: %{}})
        |> TrackerManagerImpl.start()

      assert %{
               monitor_pid: ^page_pid,
               monitor_ref: monitor_ref,
               character_ids: character_ids
             } = manager_state.consumers[consumer_id]

      assert is_reference(monitor_ref)
      assert MapSet.member?(character_ids, character_id)

      Process.exit(page_pid, :kill)
      assert_receive {:DOWN, ^monitor_ref, :process, ^page_pid, reason}

      manager_state =
        TrackerManagerImpl.handle_info(
          {:DOWN, monitor_ref, :process, page_pid, reason},
          manager_state
        )

      refute Map.has_key?(manager_state.consumers, consumer_id)
      refute Map.has_key?(Character.get_character_state!(character_id).consumers, consumer_id)
    end
  end

  describe "field-scoped state updates" do
    test "a worker patch cannot erase a newly registered consumer", %{
      character_id: character_id
    } do
      seed_state(character_id, %{corporation_id: 1})
      stale_state = Character.get_character_state!(character_id)
      consumer_id = {:characters_page, self()}

      assert {:ok, _state} =
               Tracker.update_consumer(character_id, consumer_id, :slow, true)

      assert {:ok, state} =
               Character.update_character_state(character_id, %{
                 corporation_id: stale_state.corporation_id + 1
               })

      assert state.corporation_id == 2
      assert state.consumers == %{consumer_id => :slow}
    end

    test "re-registering the same manager consumer repairs its cached registration", %{
      character_id: character_id
    } do
      seed_state(character_id)
      consumer_pid = spawn(fn -> Process.sleep(:infinity) end)
      consumer_id = {:characters_page, consumer_pid}
      WandererApp.Cache.put("#{character_id}:track_requested", true)

      on_exit(fn ->
        WandererApp.Cache.delete("#{character_id}:track_requested")

        if Process.alive?(consumer_pid) do
          Process.exit(consumer_pid, :kill)
        end
      end)

      manager_state =
        TrackerManagerImpl.new(%{characters: [], opts: %{}, consumers: %{}})
        |> TrackerManagerImpl.register_consumer(
          [character_id],
          consumer_id,
          :slow,
          consumer_pid
        )

      Cachex.put(:character_state_cache, character_id, Tracker.new(%{character_id: character_id}))

      manager_state =
        TrackerManagerImpl.register_consumer(
          manager_state,
          [character_id],
          consumer_id,
          :slow,
          consumer_pid
        )

      assert Character.get_character_state!(character_id).consumers == %{consumer_id => :slow}

      TrackerManagerImpl.unregister_consumer(manager_state, consumer_id)
      Process.exit(consumer_pid, :kill)
    end

    test "a worker patch cannot restore a removed consumer", %{character_id: character_id} do
      consumer_id = {:characters_page, self()}
      seed_state(character_id, %{consumers: %{consumer_id => :slow}, corporation_id: 1})

      assert {:ok, _state} =
               Tracker.update_consumer(character_id, consumer_id, :slow, false)

      assert {:ok, state} =
               Character.update_character_state(character_id, %{corporation_id: 2})

      assert state.corporation_id == 2
      assert state.consumers == %{}
    end
  end
end
