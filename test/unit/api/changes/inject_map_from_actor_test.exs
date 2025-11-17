defmodule WandererApp.Api.Changes.InjectMapFromActorTest do
  use WandererApp.DataCase, async: false

  import WandererAppWeb.Factory

  alias WandererApp.Api.Changes.InjectMapFromActor
  alias WandererApp.Api.MapSystem

  describe "InjectMapFromActor.change/3" do
    test "injects map_id from context" do
      user = insert(:user)
      character = insert(:character, user_id: user.id)
      map = insert(:map, owner_id: character.id)

      # Create a changeset with context containing map
      changeset =
        Ash.Changeset.for_create(
          MapSystem,
          :create,
          %{
            solar_system_id: 30_000_142,
            name: "Jita",
            position_x: 100,
            position_y: 200
          },
          context: %{map: map}
        )

      # Call the change
      result = InjectMapFromActor.change(changeset, [], %{})

      # Verify map_id was injected
      assert Ash.Changeset.get_attribute(result, :map_id) == map.id
      assert result.valid?
    end

    test "overrides client-provided map_id" do
      user = insert(:user)
      character = insert(:character, user_id: user.id)
      correct_map = insert(:map, owner_id: character.id)
      wrong_map_id = Ecto.UUID.generate()

      # Create changeset with wrong map_id and correct map in context
      changeset =
        Ash.Changeset.for_create(
          MapSystem,
          :create,
          %{
            solar_system_id: 30_000_142,
            name: "Jita",
            position_x: 100,
            position_y: 200
          },
          context: %{map: correct_map}
        )
        |> Ash.Changeset.force_change_attribute(:map_id, wrong_map_id)

      # Call the change
      result = InjectMapFromActor.change(changeset, [], %{})

      # Should use token's map from context, not client-provided
      assert Ash.Changeset.get_attribute(result, :map_id) == correct_map.id
      assert Ash.Changeset.get_attribute(result, :map_id) != wrong_map_id
      assert result.valid?
    end

    test "adds error when no map in context" do
      user = insert(:user)

      # Create changeset without map in context
      changeset =
        Ash.Changeset.for_create(MapSystem, :create, %{
          solar_system_id: 30_000_142,
          name: "Jita",
          position_x: 100,
          position_y: 200
        })

      # Call the change
      result = InjectMapFromActor.change(changeset, [], %{})

      # Should have errors
      refute result.valid?

      # Check for error (field will be :base not :map_id)
      assert Enum.any?(result.errors, fn err ->
               err.field == :base
             end)
    end

    test "adds error when context has nil map" do
      user = insert(:user)

      # Create changeset with nil map in context
      changeset =
        Ash.Changeset.for_create(
          MapSystem,
          :create,
          %{
            solar_system_id: 30_000_142,
            name: "Jita",
            position_x: 100,
            position_y: 200
          },
          context: %{map: nil}
        )

      # Call the change
      result = InjectMapFromActor.change(changeset, [], %{})

      # Should have errors
      refute result.valid?

      assert Enum.any?(result.errors, fn err ->
               err.field == :base and String.contains?(err.message, "missing map context")
             end)
    end

    test "handles invalid map context gracefully" do
      user = insert(:user)

      # Create changeset with invalid map (not a struct with id)
      changeset =
        Ash.Changeset.for_create(
          MapSystem,
          :create,
          %{
            solar_system_id: 30_000_142,
            name: "Jita",
            position_x: 100,
            position_y: 200
          },
          context: %{map: %{invalid: "data"}}
        )

      # Call the change
      result = InjectMapFromActor.change(changeset, [], %{})

      # Should have errors
      refute result.valid?

      assert Enum.any?(result.errors, fn err ->
               err.field == :base and String.contains?(err.message, "invalid map context")
             end)
    end

    test "emits telemetry event when client provides map_id" do
      # Set up telemetry handler
      test_pid = self()

      :telemetry.attach(
        "test-inject-map-telemetry",
        [:wanderer_app, :api, :deprecated],
        fn _event_name, measurements, metadata, _config ->
          send(test_pid, {:telemetry, measurements, metadata})
        end,
        nil
      )

      user = insert(:user)
      character = insert(:character, user_id: user.id)
      map = insert(:map, owner_id: character.id)

      # Force a map_id into the changeset before the change runs
      # This simulates what would happen if a client tried to provide map_id
      changeset =
        Ash.Changeset.for_create(
          MapSystem,
          :create,
          %{
            solar_system_id: 30_000_142,
            name: "Jita",
            position_x: 100,
            position_y: 200
          },
          context: %{map: map}
        )
        |> Ash.Changeset.force_change_attribute(:map_id, map.id)

      # Call the change directly
      _result = InjectMapFromActor.change(changeset, [], %{})

      # Should receive telemetry event
      assert_receive {:telemetry, %{count: 1}, metadata}, 1000

      assert metadata.deprecation == "map_id_in_request"

      assert metadata.message ==
               "Clients should not provide map_id - it's determined from token"

      # Clean up
      :telemetry.detach("test-inject-map-telemetry")
    end

    test "works with existing map_id on updates" do
      user = insert(:user)
      character = insert(:character, user_id: user.id)
      map = insert(:map, owner_id: character.id)

      # Create a system first
      system = insert(:map_system, map_id: map.id, solar_system_id: 30_000_142)

      # Create update changeset with map in context
      changeset =
        Ash.Changeset.for_update(
          system,
          :update,
          %{
            position_x: 150,
            position_y: 250
          },
          context: %{map: map}
        )

      # Note: Update action doesn't use InjectMapFromActor, but let's verify it doesn't break
      # if we call it
      result = InjectMapFromActor.change(changeset, [], %{})

      # Map ID should remain unchanged (map_id is immutable on updates)
      assert Ash.Changeset.get_attribute(result, :map_id) == map.id
      assert result.valid?
    end
  end
end
