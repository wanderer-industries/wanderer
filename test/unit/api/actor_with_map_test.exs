defmodule WandererApp.Api.ActorWithMapTest do
  # Pure unit tests - no database or external dependencies
  use ExUnit.Case, async: true

  alias WandererApp.Api.ActorWithMap

  describe "new/2" do
    test "creates struct with user and map" do
      user = %{id: "user-123", name: "Test User"}
      map = %{id: "map-456", name: "Test Map"}

      actor = ActorWithMap.new(user, map)

      assert actor.user == user
      assert actor.map == map
    end

    test "enforces required keys" do
      assert_raise ArgumentError, fn ->
        struct!(ActorWithMap, %{})
      end
    end
  end
end
