defmodule WandererApp.Api.ActorHelpersTest do
  use WandererApp.DataCase, async: true
  import WandererAppWeb.Factory

  alias WandererApp.Api.ActorHelpers
  alias WandererApp.Api.ActorWithMap

  describe "get_map/1" do
    test "extracts map from ActorWithMap in context" do
      user = insert(:user)
      character = insert(:character, user_id: user.id)
      map = insert(:map, owner_id: character.id)

      actor = %ActorWithMap{user: user, map: map}
      context = %{actor: actor}

      assert ActorHelpers.get_map(context) == map
    end

    test "extracts map from context[:map]" do
      user = insert(:user)
      character = insert(:character, user_id: user.id)
      map = insert(:map, owner_id: character.id)

      context = %{map: map}

      assert ActorHelpers.get_map(context) == map
    end

    test "returns nil when no map in context" do
      user = insert(:user)
      context = %{actor: user}

      assert ActorHelpers.get_map(context) == nil
    end

    test "returns nil for empty context" do
      assert ActorHelpers.get_map(%{}) == nil
    end

    test "returns nil for non-map input" do
      assert ActorHelpers.get_map(nil) == nil
    end
  end

  describe "get_character_ids/1" do
    test "extracts character IDs from ActorWithMap with preloaded characters" do
      user = insert(:user)
      character1 = insert(:character, user_id: user.id)
      character2 = insert(:character, user_id: user.id)

      user_with_chars = user |> Ash.load!(:characters)
      actor = %ActorWithMap{user: user_with_chars, map: nil}

      assert {:ok, character_ids} = ActorHelpers.get_character_ids(actor)
      assert length(character_ids) == 2
      assert character1.id in character_ids
      assert character2.id in character_ids
    end

    test "extracts character IDs from user with preloaded characters" do
      user = insert(:user)
      character1 = insert(:character, user_id: user.id)
      character2 = insert(:character, user_id: user.id)

      user_with_chars = user |> Ash.load!(:characters)

      assert {:ok, character_ids} = ActorHelpers.get_character_ids(user_with_chars)
      assert length(character_ids) == 2
      assert character1.id in character_ids
      assert character2.id in character_ids
    end

    test "loads characters when not preloaded" do
      user = insert(:user)
      character = insert(:character, user_id: user.id)

      # Get user without preloading characters
      {:ok, user_without_preload} = WandererApp.Api.User |> Ash.get(user.id)

      assert {:ok, character_ids} = ActorHelpers.get_character_ids(user_without_preload)
      assert character_ids == [character.id]
    end

    test "returns empty list when user has no characters" do
      user = insert(:user)
      user_with_chars = user |> Ash.load!(:characters)

      assert {:ok, []} = ActorHelpers.get_character_ids(user_with_chars)
    end

    test "returns error for invalid actor" do
      assert {:error, :invalid_actor_for_character_extraction} =
               ActorHelpers.get_character_ids(%{})

      assert {:error, :invalid_actor_for_character_extraction} =
               ActorHelpers.get_character_ids(nil)
    end
  end

  describe "get_user/1" do
    test "extracts user from ActorWithMap" do
      user = insert(:user)
      character = insert(:character, user_id: user.id)
      map = insert(:map, owner_id: character.id)

      actor = %ActorWithMap{user: user, map: map}

      assert ActorHelpers.get_user(actor) == user
    end

    test "returns user when already a user struct" do
      user = insert(:user)

      assert ActorHelpers.get_user(user) == user
    end

    test "returns nil for non-user input" do
      assert ActorHelpers.get_user(%{}) == nil
      assert ActorHelpers.get_user(nil) == nil
    end
  end

  describe "telemetry" do
    setup do
      # Attach telemetry handler to capture events
      test_pid = self()

      :telemetry.attach_many(
        "test-actor-helpers",
        [
          [:wanderer_app, :filter, :characters_preloaded],
          [:wanderer_app, :filter, :characters_lazy_loaded]
        ],
        fn event_name, measurements, metadata, _config ->
          send(test_pid, {:telemetry_event, event_name, measurements, metadata})
        end,
        nil
      )

      on_exit(fn ->
        :telemetry.detach("test-actor-helpers")
      end)

      :ok
    end

    test "emits telemetry event when characters are preloaded" do
      user = insert(:user)
      _character = insert(:character, user_id: user.id)

      user_with_chars = user |> Ash.load!(:characters)

      ActorHelpers.get_character_ids(user_with_chars)

      assert_receive {:telemetry_event, [:wanderer_app, :filter, :characters_preloaded],
                      %{count: 1}, %{user_id: user_id}}

      assert user_id == user.id
    end

    test "emits telemetry event when characters are lazy loaded" do
      user = insert(:user)
      _character = insert(:character, user_id: user.id)

      # Get user without preloading characters
      {:ok, user_without_preload} = WandererApp.Api.User |> Ash.get(user.id)

      ActorHelpers.get_character_ids(user_without_preload)

      assert_receive {:telemetry_event, [:wanderer_app, :filter, :characters_lazy_loaded],
                      %{count: 1}, %{user_id: user_id}}

      assert user_id == user.id
    end
  end
end
