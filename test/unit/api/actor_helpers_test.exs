defmodule WandererApp.Api.ActorHelpersTest do
  # Pure unit tests - no database or external dependencies
  use ExUnit.Case, async: true

  alias WandererApp.Api.ActorHelpers
  alias WandererApp.Api.ActorWithMap

  describe "get_map/1" do
    test "extracts map from ActorWithMap in :actor key" do
      map = %{id: "map-123"}
      user = %{id: "user-456"}
      actor = ActorWithMap.new(user, map)

      context = %{actor: actor}

      assert ActorHelpers.get_map(context) == map
    end

    test "extracts map from direct :map key" do
      map = %{id: "map-123"}
      context = %{map: map}

      assert ActorHelpers.get_map(context) == map
    end

    test "extracts map from private actor" do
      map = %{id: "map-123"}
      user = %{id: "user-456"}
      actor = ActorWithMap.new(user, map)

      context = %{private: %{actor: actor}}

      assert ActorHelpers.get_map(context) == map
    end

    test "returns nil when no map found" do
      assert ActorHelpers.get_map(%{}) == nil
      assert ActorHelpers.get_map(nil) == nil
    end
  end

  describe "get_user/1" do
    test "extracts user from ActorWithMap" do
      user = %{id: "user-123"}
      map = %{id: "map-456"}
      actor = ActorWithMap.new(user, map)

      assert ActorHelpers.get_user(actor) == user
    end

    test "returns user struct directly" do
      user = %{id: "user-123"}

      assert ActorHelpers.get_user(user) == user
    end

    test "returns nil for invalid input" do
      assert ActorHelpers.get_user(nil) == nil
      assert ActorHelpers.get_user(%{}) == nil
    end
  end

  describe "get_character_ids/1" do
    test "extracts character ids from user with loaded characters" do
      characters = [
        %{id: "char-1"},
        %{id: "char-2"}
      ]

      user = %{id: "user-123", characters: characters}

      assert {:ok, ids} = ActorHelpers.get_character_ids(user)
      assert ids == ["char-1", "char-2"]
    end

    test "extracts character ids from ActorWithMap" do
      characters = [%{id: "char-1"}]
      user = %{id: "user-123", characters: characters}
      map = %{id: "map-456"}
      actor = ActorWithMap.new(user, map)

      assert {:ok, ids} = ActorHelpers.get_character_ids(actor)
      assert ids == ["char-1"]
    end

    test "returns empty list for nil input" do
      assert {:ok, []} = ActorHelpers.get_character_ids(nil)
    end
  end
end
