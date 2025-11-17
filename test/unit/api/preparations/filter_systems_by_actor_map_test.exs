defmodule WandererApp.Api.Preparations.FilterSystemsByActorMapTest do
  use WandererApp.DataCase, async: false

  import WandererAppWeb.Factory

  alias WandererApp.Api.Preparations.FilterSystemsByActorMap
  alias WandererApp.Api.MapSystem
  alias WandererApp.Api.User

  describe "prepare/3 with no actor" do
    test "allows unfiltered access" do
      user = insert(:user)
      character = insert(:character, user_id: user.id)
      map = insert(:map, owner_id: character.id)
      system = insert(:map_system, map_id: map.id, solar_system_id: 30_000_142)

      query = Ash.Query.for_read(MapSystem, :read)
      context = %{actor: nil}

      result = FilterSystemsByActorMap.prepare(query, %{}, context)
      {:ok, systems} = Ash.read(result)

      # Should get all systems
      assert length(systems) >= 1
      assert Enum.any?(systems, &(&1.id == system.id))
    end
  end

  describe "prepare/3 with ActorWithMap (token auth)" do
    test "filters to specific map only" do
      user = insert(:user)
      character = insert(:character, user_id: user.id)
      map1 = insert(:map, owner_id: character.id)
      map2 = insert(:map, owner_id: character.id)

      system1 = insert(:map_system, map_id: map1.id, solar_system_id: 30_000_142)
      _system2 = insert(:map_system, map_id: map2.id, solar_system_id: 30_000_143)

      # Create ActorWithMap for map1
      actor = WandererApp.Api.ActorWithMap.new(user, map1)

      query = Ash.Query.for_read(MapSystem, :read)
      context = %{actor: actor}

      result = FilterSystemsByActorMap.prepare(query, %{}, context)
      {:ok, systems} = Ash.read(result)

      # Should only get systems from map1
      assert length(systems) == 1
      assert List.first(systems).id == system1.id
    end
  end

  describe "prepare/3 with session auth (preloaded characters)" do
    test "handles preloaded characters correctly" do
      user = insert(:user)
      character = insert(:character, user_id: user.id)
      map = insert(:map, owner_id: character.id)
      system = insert(:map_system, map_id: map.id, solar_system_id: 30_000_142)

      # Preload characters
      {:ok, user_with_chars} = Ash.load(user, :characters)

      query = Ash.Query.for_read(MapSystem, :read)
      context = %{actor: user_with_chars}

      result = FilterSystemsByActorMap.prepare(query, %{}, context)
      {:ok, systems} = Ash.read(result)

      # Should get systems from owned maps
      assert length(systems) == 1
      assert List.first(systems).id == system.id
    end

    test "handles NOT preloaded characters (loads them automatically)" do
      user = insert(:user)
      character = insert(:character, user_id: user.id)
      map = insert(:map, owner_id: character.id)
      system = insert(:map_system, map_id: map.id, solar_system_id: 30_000_142)

      # Create a user struct without preloading characters
      # We simulate a NotLoaded association manually
      user_without_preload = %{user | characters: %Ecto.Association.NotLoaded{}}

      query = Ash.Query.for_read(MapSystem, :read)
      context = %{actor: user_without_preload}

      result = FilterSystemsByActorMap.prepare(query, %{}, context)
      {:ok, systems} = Ash.read(result)

      # Should still work - filter loads characters automatically
      assert length(systems) == 1
      assert List.first(systems).id == system.id
    end

    test "denies access when user has no characters" do
      user = insert(:user)
      # No characters for this user
      character2 = insert(:character)
      map = insert(:map, owner_id: character2.id)
      _system = insert(:map_system, map_id: map.id, solar_system_id: 30_000_142)

      {:ok, user_with_chars} = Ash.load(user, :characters)

      query = Ash.Query.for_read(MapSystem, :read)
      context = %{actor: user_with_chars}

      result = FilterSystemsByActorMap.prepare(query, %{}, context)
      {:ok, systems} = Ash.read(result)

      # User has no characters - no access to any systems
      assert systems == []
    end

    test "filters to maps owned by user's characters only" do
      user1 = insert(:user)
      user2 = insert(:user)
      character1 = insert(:character, user_id: user1.id)
      character2 = insert(:character, user_id: user2.id)

      map1 = insert(:map, owner_id: character1.id)
      map2 = insert(:map, owner_id: character2.id)

      system1 = insert(:map_system, map_id: map1.id, solar_system_id: 30_000_142)
      _system2 = insert(:map_system, map_id: map2.id, solar_system_id: 30_000_143)

      {:ok, user1_with_chars} = Ash.load(user1, :characters)

      query = Ash.Query.for_read(MapSystem, :read)
      context = %{actor: user1_with_chars}

      result = FilterSystemsByActorMap.prepare(query, %{}, context)
      {:ok, systems} = Ash.read(result)

      # User1 should only see systems from their own maps
      assert length(systems) == 1
      assert List.first(systems).id == system1.id
    end
  end

  describe "prepare/3 telemetry tracking" do
    test "emits telemetry when characters are preloaded" do
      user = insert(:user)
      character = insert(:character, user_id: user.id)
      map = insert(:map, owner_id: character.id)
      _system = insert(:map_system, map_id: map.id, solar_system_id: 30_000_142)

      # Set up telemetry handler
      test_pid = self()

      :telemetry.attach(
        "test-filter-preloaded-telemetry",
        [:wanderer_app, :filter, :characters_preloaded],
        fn _event_name, measurements, metadata, _config ->
          send(test_pid, {:telemetry_preloaded, measurements, metadata})
        end,
        nil
      )

      {:ok, user_with_chars} = Ash.load(user, :characters)

      query = Ash.Query.for_read(MapSystem, :read)
      context = %{actor: user_with_chars}

      result = FilterSystemsByActorMap.prepare(query, %{}, context)
      {:ok, _systems} = Ash.read(result)

      # Should receive telemetry event for preloaded characters
      assert_receive {:telemetry_preloaded, %{count: 1}, metadata}, 1000
      assert metadata.user_id == user.id

      # Clean up
      :telemetry.detach("test-filter-preloaded-telemetry")
    end

    test "emits telemetry when characters need lazy loading" do
      user = insert(:user)
      character = insert(:character, user_id: user.id)
      map = insert(:map, owner_id: character.id)
      _system = insert(:map_system, map_id: map.id, solar_system_id: 30_000_142)

      # Set up telemetry handler
      test_pid = self()

      :telemetry.attach(
        "test-filter-lazy-telemetry",
        [:wanderer_app, :filter, :characters_lazy_loaded],
        fn _event_name, measurements, metadata, _config ->
          send(test_pid, {:telemetry_lazy, measurements, metadata})
        end,
        nil
      )

      # Create a user struct without preloading characters
      # We simulate a NotLoaded association manually to trigger lazy loading
      user_without_preload = %{user | characters: %Ecto.Association.NotLoaded{}}

      query = Ash.Query.for_read(MapSystem, :read)
      context = %{actor: user_without_preload}

      result = FilterSystemsByActorMap.prepare(query, %{}, context)
      {:ok, _systems} = Ash.read(result)

      # Should receive telemetry event for lazy loading
      assert_receive {:telemetry_lazy, %{count: 1}, metadata}, 1000
      assert metadata.user_id == user.id

      # Clean up
      :telemetry.detach("test-filter-lazy-telemetry")
    end
  end

  describe "prepare/3 error handling" do
    test "handles invalid user structure gracefully" do
      # Create a struct that looks like a user but has unexpected structure
      invalid_actor = %{some: "data", id: "test-id"}

      user = insert(:user)
      character = insert(:character, user_id: user.id)
      map = insert(:map, owner_id: character.id)
      _system = insert(:map_system, map_id: map.id, solar_system_id: 30_000_142)

      query = Ash.Query.for_read(MapSystem, :read)
      context = %{actor: invalid_actor}

      result = FilterSystemsByActorMap.prepare(query, %{}, context)
      {:ok, systems} = Ash.read(result)

      # Should deny access on error
      assert systems == []
    end
  end
end
