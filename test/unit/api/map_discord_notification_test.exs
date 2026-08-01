defmodule WandererApp.Api.MapDiscordNotificationTest do
  use WandererApp.DataCase, async: false

  alias WandererApp.Api.MapDiscordNotification
  alias WandererAppWeb.Factory

  defp valid_url, do: "https://discord.com/api/webhooks/123456789/abcdefTOKEN"

  setup do
    map = Factory.insert(:map, %{})
    %{map: map}
  end

  test "creates with valid discord url and defaults", %{map: map} do
    assert {:ok, rec} =
             MapDiscordNotification.create(%{map_id: map.id, webhook_url: valid_url()})

    assert rec.enabled? == true
    assert rec.wh_only == true
    assert rec.excluded_systems == []
    assert rec.consecutive_failures == 0
  end

  test "accepts discordapp.com host", %{map: map} do
    url = "https://discordapp.com/api/webhooks/123/tok"
    assert {:ok, _} = MapDiscordNotification.create(%{map_id: map.id, webhook_url: url})
  end

  test "rejects non-https scheme", %{map: map} do
    url = "http://discord.com/api/webhooks/123/tok"
    assert {:error, _} = MapDiscordNotification.create(%{map_id: map.id, webhook_url: url})
  end

  test "rejects non-discord host", %{map: map} do
    url = "https://evil.example.com/api/webhooks/123/tok"

    # Assert on the specific validation message, not a bare {:error, _}. A
    # blanket-reject regression (e.g. reading the AshCloak attribute instead of
    # the argument, which yields %Ash.NotLoaded{}) would satisfy {:error, _}
    # while rejecting valid URLs too.
    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             MapDiscordNotification.create(%{map_id: map.id, webhook_url: url})

    assert Enum.any?(errors, fn e ->
             Map.get(e, :field) == :webhook_url and
               to_string(Map.get(e, :message, "")) =~ "Discord webhook URL"
           end)
  end

  test "rejects host that merely contains discord.com", %{map: map} do
    url = "https://discord.com.evil.example/api/webhooks/123/tok"
    assert {:error, _} = MapDiscordNotification.create(%{map_id: map.id, webhook_url: url})
  end

  test "rejects malformed webhook path", %{map: map} do
    url = "https://discord.com/api/not-webhooks/123/tok"
    assert {:error, _} = MapDiscordNotification.create(%{map_id: map.id, webhook_url: url})
  end

  test "rejects invalid url on UPDATE as well as create", %{map: map} do
    {:ok, rec} = MapDiscordNotification.create(%{map_id: map.id, webhook_url: valid_url()})

    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             MapDiscordNotification.update(rec, %{webhook_url: "https://evil.example.com/x"})

    assert Enum.any?(errors, fn e ->
             Map.get(e, :field) == :webhook_url and
               to_string(Map.get(e, :message, "")) =~ "Discord webhook URL"
           end)

    # The rejected value must not have been persisted.
    {:ok, reloaded} = MapDiscordNotification.by_map(map.id)
    assert reloaded.webhook_url == valid_url()
  end

  test "accepts a valid replacement url on UPDATE" do
    # Guards against a blanket-reject regression: replacement must still work.
    map = WandererAppWeb.Factory.insert(:map, %{})
    {:ok, rec} = MapDiscordNotification.create(%{map_id: map.id, webhook_url: valid_url()})
    replacement = "https://canary.discord.com/api/v10/webhooks/999/newtok"

    assert {:ok, updated} = MapDiscordNotification.update(rec, %{webhook_url: replacement})
    assert updated.webhook_url == replacement
  end

  test "enforces one notification per map", %{map: map} do
    {:ok, _} = MapDiscordNotification.create(%{map_id: map.id, webhook_url: valid_url()})

    assert {:error, _} =
             MapDiscordNotification.create(%{map_id: map.id, webhook_url: valid_url()})
  end

  test "by_map returns the record", %{map: map} do
    {:ok, created} = MapDiscordNotification.create(%{map_id: map.id, webhook_url: valid_url()})

    assert {:ok, found} = MapDiscordNotification.by_map(map.id)
    assert found.id == created.id
  end

  test "deleting the map cascades the notification away", %{map: map} do
    {:ok, rec} = MapDiscordNotification.create(%{map_id: map.id, webhook_url: valid_url()})

    Ash.destroy!(map)

    assert {:error, _} = MapDiscordNotification.by_id(rec.id)
  end

  test "record_failure increments and does not disable before the threshold", %{map: map} do
    {:ok, rec} = MapDiscordNotification.create(%{map_id: map.id, webhook_url: valid_url()})

    rec =
      Enum.reduce(1..9, rec, fn _, acc ->
        {:ok, updated} = MapDiscordNotification.record_failure(acc, "boom")
        updated
      end)

    assert rec.consecutive_failures == 9
    assert rec.enabled? == true
    assert rec.last_error == "boom"
  end

  test "record_failure disables at 10 consecutive failures", %{map: map} do
    {:ok, rec} = MapDiscordNotification.create(%{map_id: map.id, webhook_url: valid_url()})

    rec =
      Enum.reduce(1..10, rec, fn _, acc ->
        {:ok, updated} = MapDiscordNotification.record_failure(acc, "boom")
        updated
      end)

    assert rec.consecutive_failures == 10
    assert rec.enabled? == false
  end

  test "record_failure re-reads the counter rather than trusting a stale copy", %{map: map} do
    {:ok, stale} = MapDiscordNotification.create(%{map_id: map.id, webhook_url: valid_url()})

    # Advance the stored counter behind the back of the `stale` struct.
    {:ok, _} = MapDiscordNotification.record_failure(stale, "first")

    {:ok, updated} = MapDiscordNotification.record_failure(stale, "second")

    assert updated.consecutive_failures == 2
  end

  test "record_success clears the failure state", %{map: map} do
    {:ok, rec} = MapDiscordNotification.create(%{map_id: map.id, webhook_url: valid_url()})
    {:ok, rec} = MapDiscordNotification.record_failure(rec, "boom")

    {:ok, rec} = MapDiscordNotification.record_success(rec)

    assert rec.consecutive_failures == 0
    assert rec.last_error == nil
    assert rec.last_delivery_at != nil
  end

  test "destroy invalidates the cache and stops the worker", %{map: map} do
    {:ok, rec} = MapDiscordNotification.create(%{map_id: map.id, webhook_url: valid_url()})

    # Neither the cache nor the worker registry is running in this test; the
    # custom destroy must tolerate that rather than crash.
    assert :ok = MapDiscordNotification.destroy(rec)
    assert {:error, _} = MapDiscordNotification.by_map(map.id)
  end
end
