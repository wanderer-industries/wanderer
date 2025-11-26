defmodule WandererApp.Api.Preparations.FilterSystemsByActorMapTest do
  use WandererApp.DataCase, async: false

  require Ash.Query

  alias WandererApp.Api.Preparations.FilterSystemsByActorMap
  alias WandererApp.Api.ActorWithMap

  describe "prepare/3" do
    test "adds map_id filter from actor context" do
      map = %{id: "map-123"}
      user = %{id: "user-456"}
      actor = ActorWithMap.new(user, map)

      query = Ash.Query.new(WandererApp.Api.MapSystem)
      context = %{actor: actor}

      result = FilterSystemsByActorMap.prepare(query, [], context)

      # Check that filter was added
      assert result.filter != nil
      filter_string = inspect(result.filter)
      assert String.contains?(filter_string, "map_id")
    end

    test "adds map_id filter from direct map context" do
      map = %{id: "map-789"}

      query = Ash.Query.new(WandererApp.Api.MapSystem)
      context = %{map: map}

      result = FilterSystemsByActorMap.prepare(query, [], context)

      assert result.filter != nil
      filter_string = inspect(result.filter)
      assert String.contains?(filter_string, "map_id")
    end

    test "returns false filter when no map context" do
      query = Ash.Query.new(WandererApp.Api.MapSystem)
      context = %{}

      result = FilterSystemsByActorMap.prepare(query, [], context)

      # Should add a filter that returns no results
      assert result.filter != nil
    end

    test "returns false filter when actor has nil map" do
      user = %{id: "user-456"}
      actor = ActorWithMap.new(user, nil)

      query = Ash.Query.new(WandererApp.Api.MapSystem)
      context = %{actor: actor}

      result = FilterSystemsByActorMap.prepare(query, [], context)

      # Should add a filter that returns no results
      assert result.filter != nil
    end

    test "returns false filter when map key is nil" do
      query = Ash.Query.new(WandererApp.Api.MapSystem)
      context = %{map: nil}

      result = FilterSystemsByActorMap.prepare(query, [], context)

      # Should add a filter that returns no results
      assert result.filter != nil
    end

    test "handles private actor context" do
      map = %{id: "map-private"}
      user = %{id: "user-789"}
      actor = ActorWithMap.new(user, map)

      query = Ash.Query.new(WandererApp.Api.MapSystem)
      context = %{private: %{actor: actor}}

      result = FilterSystemsByActorMap.prepare(query, [], context)

      assert result.filter != nil
      filter_string = inspect(result.filter)
      assert String.contains?(filter_string, "map_id")
    end
  end
end
