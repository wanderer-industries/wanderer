defmodule WandererApp.Api.Changes.InjectMapFromActorTest do
  # Tests Ash changeset logic but doesn't need database
  use ExUnit.Case, async: true

  alias WandererApp.Api.ActorWithMap

  describe "change/3" do
    # Note: Testing InjectMapFromActor.change/3 directly is difficult because it
    # triggers Ash's validation pipeline. The actual behavior is tested via
    # integration tests.

    test "allows map_id when provided directly without actor" do
      # Create a basic changeset with map_id in params
      changeset =
        WandererApp.Api.MapSystem
        |> Ash.Changeset.new()
        |> Map.put(:params, %{
          map_id: "direct-map-id",
          solar_system_id: 30_000_142,
          name: "Jita"
        })

      context = %{}

      result = WandererApp.Api.Changes.InjectMapFromActor.change(changeset, [], context)

      # Should not add our "required" error (map_id is in params)
      # Note: Ash may add other validation errors for invalid map_id
      refute result.errors |> Enum.any?(&String.contains?(&1.message || "", "required"))
    end

    test "adds error when no map context and no map_id provided" do
      # Create a basic changeset without map_id
      changeset =
        WandererApp.Api.MapSystem
        |> Ash.Changeset.new()
        |> Map.put(:params, %{solar_system_id: 30_000_142, name: "Jita"})

      context = %{}

      result = WandererApp.Api.Changes.InjectMapFromActor.change(changeset, [], context)

      # Should add our "required" error
      assert result.errors |> Enum.any?(&String.contains?(&1.message || "", "required"))
    end

    test "ActorHelpers.get_map extracts from ActorWithMap" do
      map = %{id: "map-123"}
      user = %{id: "user-456"}
      actor = ActorWithMap.new(user, map)

      context = %{actor: actor}

      # Test ActorHelpers directly
      assert WandererApp.Api.ActorHelpers.get_map(context) == map
    end

    test "ActorHelpers.get_map extracts from direct map context" do
      map = %{id: "map-789"}

      context = %{map: map}

      # Test ActorHelpers directly
      assert WandererApp.Api.ActorHelpers.get_map(context) == map
    end
  end
end
