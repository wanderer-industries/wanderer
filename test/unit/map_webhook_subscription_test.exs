defmodule WandererApp.Api.MapWebhookSubscriptionTest do
  use WandererApp.DataCase, async: false

  alias WandererApp.Api.MapWebhookSubscription

  describe "secret lifecycle" do
    test "generates an encrypted secret when creating a subscription" do
      map = insert(:map)

      assert {:ok, webhook} =
               MapWebhookSubscription.create(%{
                 map_id: map.id,
                 url: "https://example.com/webhook",
                 events: ["add_system"],
                 active?: true
               })

      assert is_binary(webhook.secret)
      assert byte_size(webhook.secret) > 0
      assert is_binary(webhook.encrypted_secret)
      refute webhook.encrypted_secret == webhook.secret
    end

    test "replaces and encrypts the secret when rotating it" do
      map = insert(:map)

      assert {:ok, webhook} =
               MapWebhookSubscription.create(%{
                 map_id: map.id,
                 url: "https://example.com/webhook",
                 events: ["add_system"],
                 active?: true
               })

      assert {:ok, rotated_webhook} = MapWebhookSubscription.rotate_secret(webhook)

      refute rotated_webhook.secret == webhook.secret
      refute rotated_webhook.encrypted_secret == webhook.encrypted_secret
      assert is_binary(rotated_webhook.secret)
      assert is_binary(rotated_webhook.encrypted_secret)
      refute rotated_webhook.encrypted_secret == rotated_webhook.secret
    end
  end
end
