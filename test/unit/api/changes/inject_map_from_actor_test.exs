defmodule WandererApp.Api.Changes.InjectMapFromActorTest do
  use ExUnit.Case, async: true

  alias WandererApp.Api.Changes.InjectMapFromActor
  alias WandererApp.Api.ActorWithMap

  describe "change/3" do
    test "allows map_id when provided directly without actor" do
      # Create a changeset with map_id already set
      changeset = %Ash.Changeset{
        resource: WandererApp.Api.MapSystem,
        action_type: :create,
        attributes: %{
          map_id: "direct-map-id",
          solar_system_id: 30_000_142,
          name: "Jita"
        },
        errors: [],
        valid?: true
      }

      context = %{}

      result = InjectMapFromActor.change(changeset, [], context)

      # Should keep the provided map_id (changeset unchanged)
      assert Map.get(result.attributes, :map_id) == "direct-map-id"
      refute result.errors |> Enum.any?(&(&1.field == :map_id))
    end

    test "adds error when no map context and no map_id provided" do
      # Create a changeset without map_id
      changeset = %Ash.Changeset{
        resource: WandererApp.Api.MapSystem,
        action_type: :create,
        attributes: %{
          solar_system_id: 30_000_142,
          name: "Jita"
        },
        errors: [],
        valid?: true
      }

      context = %{}

      result = InjectMapFromActor.change(changeset, [], context)

      assert result.errors |> Enum.any?(&(&1.field == :map_id))
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
