defmodule WandererApp.ExternalEvents.SseAccessControlTest do
  use WandererApp.DataCase, async: false

  import Mox

  setup :verify_on_exit!

  alias WandererApp.ExternalEvents.SseAccessControl

  # Enable SSE globally for these tests
  setup do
    # Store original value
    original_sse_config = Application.get_env(:wanderer_app, :sse, [])

    # Enable SSE for tests
    Application.put_env(:wanderer_app, :sse, Keyword.put(original_sse_config, :enabled, true))

    on_exit(fn ->
      # Restore original value
      Application.put_env(:wanderer_app, :sse, original_sse_config)
    end)

    :ok
  end

  # Helper to create an active subscription for a map if subscriptions are enabled
  defp create_active_subscription_if_needed(map_id) do
    if WandererApp.Env.map_subscriptions_enabled?() do
      {:ok, _subscription} =
        Ash.create(WandererApp.Api.MapSubscription, %{
          map_id: map_id,
          plan: :omega,
          characters_limit: 100,
          hubs_limit: 10,
          auto_renew?: true,
          active_till: DateTime.utc_now() |> DateTime.add(30, :day)
        })
    end

    :ok
  end

  describe "sse_allowed?/1" do
    setup do
      # Create test user and character
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})

      # Create test map
      map = insert(:map, %{owner_id: character.id})

      # Create a subscription if needed (in Enterprise mode)
      create_active_subscription_if_needed(map.id)

      # Enable SSE for the map
      {:ok, map} = Ash.update(map, %{sse_enabled: true})

      %{map: map}
    end

    test "returns error when map not found" do
      fake_map_id = Ash.UUID.generate()
      assert {:error, :map_not_found} = SseAccessControl.sse_allowed?(fake_map_id)
    end

    test "returns error when map SSE disabled" do
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})
      map = insert(:map, %{owner_id: character.id})
      # Map defaults to sse_enabled: false

      # Should return error because map.sse_enabled is false
      result = SseAccessControl.sse_allowed?(map.id)
      assert {:error, :sse_disabled_for_map} = result
    end

    test "returns :ok when all conditions met in CE mode", %{map: map} do
      # Tests run in CE mode (map_subscriptions_enabled: false by default)
      # When subscriptions are disabled, any map with sse_enabled should be allowed
      result = SseAccessControl.sse_allowed?(map.id)
      assert result == :ok
    end

    test "validates map must have sse_enabled true", %{map: map} do
      # Disable SSE on the map
      {:ok, updated_map} = Ash.update(map, %{sse_enabled: false})

      # Should return error because map SSE is disabled
      assert {:error, :sse_disabled_for_map} = SseAccessControl.sse_allowed?(updated_map.id)
    end
  end
end
