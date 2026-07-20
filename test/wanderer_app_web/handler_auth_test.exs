defmodule WandererAppWeb.HandlerAuthTest do
  @moduledoc """
  Regression tests for the IDOR fixes in LiveView event handlers.

  These tests cover `WandererAppWeb.HandlerAuth`, the small authorization
  helper that the patched handlers now route client-supplied record IDs
  through. Each helper must return `{:error, :not_found}` when a record
  belongs to a different map (or user) than the one in the current LV scope.

  See the PR description for the full list of handlers these protect.
  """

  use WandererApp.DataCase, async: false

  alias WandererAppWeb.HandlerAuth

  describe "authorize_subscription/2" do
    setup do
      user = create_user()
      character_a = create_character(%{user_id: user.id})
      character_b = create_character(%{user_id: user.id})
      map_a = create_map(%{owner_id: character_a.id})
      map_b = create_map(%{owner_id: character_b.id})

      {:ok, subscription_a} =
        Ash.create(WandererApp.Api.MapSubscription, %{
          map_id: map_a.id,
          plan: :omega,
          characters_limit: 100,
          hubs_limit: 10,
          auto_renew?: true,
          active_till: DateTime.utc_now() |> DateTime.add(30, :day)
        })

      {:ok, map_a: map_a, map_b: map_b, subscription_a: subscription_a}
    end

    test "returns {:ok, sub} when subscription belongs to the given map", %{
      map_a: map_a,
      subscription_a: subscription_a
    } do
      assert {:ok, returned} = HandlerAuth.authorize_subscription(subscription_a.id, map_a.id)
      assert returned.id == subscription_a.id
    end

    test "returns {:error, :not_found} when subscription is on a different map", %{
      map_b: map_b,
      subscription_a: subscription_a
    } do
      # The classic IDOR repro: pass map_a's subscription id while scoped to map_b.
      assert {:error, :not_found} =
               HandlerAuth.authorize_subscription(subscription_a.id, map_b.id)
    end

    test "returns {:error, :not_found} for a nonexistent subscription id", %{map_a: map_a} do
      assert {:error, :not_found} =
               HandlerAuth.authorize_subscription(Ecto.UUID.generate(), map_a.id)
    end
  end

  describe "authorize_character/2" do
    setup do
      user_a = create_user()
      user_b = create_user()
      character_a = create_character(%{user_id: user_a.id})

      {:ok, user_a: user_a, user_b: user_b, character_a: character_a}
    end

    test "returns {:ok, char} when character is owned by the given user", %{
      user_a: user_a,
      character_a: character_a
    } do
      assert {:ok, returned} = HandlerAuth.authorize_character(character_a.id, user_a.id)
      assert returned.id == character_a.id
    end

    test "returns {:error, :not_found} when character belongs to a different user", %{
      user_b: user_b,
      character_a: character_a
    } do
      # Repro for characters_live.ex "delete": user B pushes user A's character_id.
      assert {:error, :not_found} = HandlerAuth.authorize_character(character_a.id, user_b.id)
    end

    test "returns {:error, :not_found} for a nonexistent character id", %{user_a: user_a} do
      assert {:error, :not_found} =
               HandlerAuth.authorize_character(Ecto.UUID.generate(), user_a.id)
    end
  end

  describe "authorize_ping/2" do
    setup do
      user = create_user()
      character_a = create_character(%{user_id: user.id})
      character_b = create_character(%{user_id: user.id})
      map_a = create_map(%{owner_id: character_a.id})
      map_b = create_map(%{owner_id: character_b.id})

      system_a =
        create_map_system(map_a.id, %{solar_system_id: 30_000_142, position_x: 0, position_y: 0})

      {:ok, ping_a} =
        Ash.create(WandererApp.Api.MapPing, %{
          map_id: map_a.id,
          system_id: system_a.id,
          character_id: character_a.id,
          type: 0,
          message: "test"
        })

      {:ok, map_a: map_a, map_b: map_b, ping_a: ping_a}
    end

    test "returns {:ok, ping} when ping belongs to the given map", %{
      map_a: map_a,
      ping_a: ping_a
    } do
      assert {:ok, returned} = HandlerAuth.authorize_ping(ping_a.id, map_a.id)
      assert returned.id == ping_a.id
    end

    test "returns {:error, :not_found} when ping is on a different map", %{
      map_b: map_b,
      ping_a: ping_a
    } do
      # Repro for cancel_ping cross-map cancellation.
      assert {:error, :not_found} = HandlerAuth.authorize_ping(ping_a.id, map_b.id)
    end
  end

  describe "authorize_system_comment/2" do
    setup do
      user = create_user()
      character_a = create_character(%{user_id: user.id})
      character_b = create_character(%{user_id: user.id})
      map_a = create_map(%{owner_id: character_a.id})
      map_b = create_map(%{owner_id: character_b.id})

      system_a =
        create_map_system(map_a.id, %{solar_system_id: 30_000_142, position_x: 0, position_y: 0})

      {:ok, comment_a} =
        Ash.create(WandererApp.Api.MapSystemComment, %{
          system_id: system_a.id,
          character_id: character_a.id,
          text: "hi"
        })

      {:ok, map_a: map_a, map_b: map_b, comment_a: comment_a}
    end

    test "returns {:ok, comment} when comment's system belongs to the given map", %{
      map_a: map_a,
      comment_a: comment_a
    } do
      assert {:ok, returned} = HandlerAuth.authorize_system_comment(comment_a.id, map_a.id)
      assert returned.id == comment_a.id
    end

    test "returns {:error, :not_found} when comment's system is on a different map", %{
      map_b: map_b,
      comment_a: comment_a
    } do
      # Repro for deleteSystemComment cross-map deletion.
      assert {:error, :not_found} =
               HandlerAuth.authorize_system_comment(comment_a.id, map_b.id)
    end
  end

  describe "authorize_passage/2" do
    setup do
      user = create_user()
      character_a = create_character(%{user_id: user.id})
      character_b = create_character(%{user_id: user.id})
      map_a = create_map(%{owner_id: character_a.id})
      map_b = create_map(%{owner_id: character_b.id})

      {:ok, passage_a} =
        Ash.create(WandererApp.Api.MapChainPassages, %{
          map_id: map_a.id,
          character_id: character_a.id,
          ship_type_id: 587,
          ship_name: "Rifter",
          mass: 1_000_000,
          solar_system_source_id: 30_000_142,
          solar_system_target_id: 30_000_144
        })

      {:ok, map_a: map_a, map_b: map_b, passage_a: passage_a}
    end

    test "returns {:ok, passage} when passage belongs to the given map", %{
      map_a: map_a,
      passage_a: passage_a
    } do
      assert {:ok, returned} = HandlerAuth.authorize_passage(passage_a.id, map_a.id)
      assert returned.id == passage_a.id
    end

    test "returns {:error, :not_found} when passage is on a different map", %{
      map_b: map_b,
      passage_a: passage_a
    } do
      # Repro for update_passage_mass cross-map corruption.
      assert {:error, :not_found} = HandlerAuth.authorize_passage(passage_a.id, map_b.id)
    end
  end

  describe "user_owns_character_eve_id?/2" do
    test "returns true when eve_id (as integer) matches a character in the list" do
      characters = [%{eve_id: "100"}, %{eve_id: "200"}]
      assert HandlerAuth.user_owns_character_eve_id?(characters, 100)
    end

    test "returns true when eve_id (as string) matches a character in the list" do
      characters = [%{eve_id: "100"}, %{eve_id: "200"}]
      assert HandlerAuth.user_owns_character_eve_id?(characters, "200")
    end

    test "returns false when eve_id does not match any character" do
      # Repro for updateCharacterTracking attempting to untrack someone else's char.
      characters = [%{eve_id: "100"}, %{eve_id: "200"}]
      refute HandlerAuth.user_owns_character_eve_id?(characters, "999")
    end

    test "returns false for empty character list" do
      refute HandlerAuth.user_owns_character_eve_id?([], "100")
    end
  end

  describe "parse_subscription_period/1" do
    test "accepts the form's allowed periods" do
      assert {:ok, 1} = HandlerAuth.parse_subscription_period("1")
      assert {:ok, 3} = HandlerAuth.parse_subscription_period("3")
      assert {:ok, 6} = HandlerAuth.parse_subscription_period("6")
      assert {:ok, 12} = HandlerAuth.parse_subscription_period("12")
    end

    test "rejects negative period (subscribe exploit)" do
      # Repro for the negative-period subscription exploit: `period: "-1"`
      # previously produced a back-dated `active_till` and flipped the
      # `estimated_price * period` calculation to a negative number.
      assert {:error, _} = HandlerAuth.parse_subscription_period("-1")
      assert {:error, _} = HandlerAuth.parse_subscription_period("-12")
    end

    test "rejects zero, out-of-range, and trailing-garbage values" do
      assert {:error, _} = HandlerAuth.parse_subscription_period("0")
      assert {:error, _} = HandlerAuth.parse_subscription_period("2")
      assert {:error, _} = HandlerAuth.parse_subscription_period("24")
      assert {:error, _} = HandlerAuth.parse_subscription_period("999999999")
      assert {:error, _} = HandlerAuth.parse_subscription_period("12x")
      assert {:error, _} = HandlerAuth.parse_subscription_period("abc")
      assert {:error, _} = HandlerAuth.parse_subscription_period("")
    end

    test "rejects non-binary input without raising" do
      # The pre-fix handler called `String.to_integer` on raw client input
      # and crashed the LV process on a non-binary. The parser must accept
      # whatever the client sends.
      assert {:error, _} = HandlerAuth.parse_subscription_period(nil)
      assert {:error, _} = HandlerAuth.parse_subscription_period(1)
      assert {:error, _} = HandlerAuth.parse_subscription_period(%{})
    end
  end

  describe "parse_characters_limit/1" do
    test "accepts values in the form's allowed range (50..5000)" do
      assert {:ok, 50} = HandlerAuth.parse_characters_limit("50")
      assert {:ok, 5_000} = HandlerAuth.parse_characters_limit("5000")
      assert {:ok, 250} = HandlerAuth.parse_characters_limit(250)
    end

    test "rejects values outside the allowed range" do
      assert {:error, _} = HandlerAuth.parse_characters_limit("0")
      assert {:error, _} = HandlerAuth.parse_characters_limit("49")
      assert {:error, _} = HandlerAuth.parse_characters_limit("5001")
      assert {:error, _} = HandlerAuth.parse_characters_limit("999999999999")
      assert {:error, _} = HandlerAuth.parse_characters_limit("-50")
    end

    test "rejects malformed input without raising" do
      assert {:error, _} = HandlerAuth.parse_characters_limit("abc")
      assert {:error, _} = HandlerAuth.parse_characters_limit("")
      assert {:error, _} = HandlerAuth.parse_characters_limit(nil)
    end
  end

  describe "parse_hubs_limit/1" do
    test "accepts values in the form's allowed range (20..50)" do
      assert {:ok, 20} = HandlerAuth.parse_hubs_limit("20")
      assert {:ok, 50} = HandlerAuth.parse_hubs_limit("50")
    end

    test "rejects values outside the allowed range" do
      assert {:error, _} = HandlerAuth.parse_hubs_limit("19")
      assert {:error, _} = HandlerAuth.parse_hubs_limit("51")
      assert {:error, _} = HandlerAuth.parse_hubs_limit("0")
      assert {:error, _} = HandlerAuth.parse_hubs_limit("-5")
    end

    test "rejects malformed input without raising" do
      assert {:error, _} = HandlerAuth.parse_hubs_limit("abc")
      assert {:error, _} = HandlerAuth.parse_hubs_limit(nil)
    end
  end
end
