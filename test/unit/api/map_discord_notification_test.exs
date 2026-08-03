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

  test "accepts a mixed-case host", %{map: map} do
    # URI.parse/1 downcases the scheme but leaves the host as typed, so a URL
    # copied from a browser address bar can arrive capitalized.
    url = "https://Discord.COM/api/webhooks/123/tok"
    assert {:ok, _} = MapDiscordNotification.create(%{map_id: map.id, webhook_url: url})
  end

  test "still rejects a mixed-case non-discord host", %{map: map} do
    url = "https://Evil.Example.COM/api/webhooks/123/tok"
    assert {:error, _} = MapDiscordNotification.create(%{map_id: map.id, webhook_url: url})
  end

  test "does not decrypt webhook_url unless explicitly loaded", %{map: map} do
    # The resource deliberately omits decrypt_by_default so that reads which do
    # not need the credential — notably the copy DiscordDispatcher caches in
    # ETS — never hold it in plaintext. Guard that here: a regression that
    # re-adds decrypt_by_default would silently reintroduce the exposure.
    {:ok, _} = MapDiscordNotification.create(%{map_id: map.id, webhook_url: valid_url()})

    {:ok, plain} = MapDiscordNotification.by_map(map.id)
    assert %Ash.NotLoaded{} = plain.webhook_url

    {:ok, loaded} = MapDiscordNotification.by_map(map.id, load: [:webhook_url])
    assert loaded.webhook_url == valid_url()
  end

  test "an update cannot move the config to a different map", %{map: map} do
    # :map_id is attribute_writable? for create, but reassigning it on update
    # would move an existing webhook config out from under the per-map
    # authorization the LiveView performs. The :update action's explicit
    # accept list is what prevents it.
    other = Factory.insert(:map, %{})
    {:ok, rec} = MapDiscordNotification.create(%{map_id: map.id, webhook_url: valid_url()})

    # Ash rejects the input outright rather than silently dropping it, so a
    # caller attempting the move gets an error instead of a no-op.
    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             MapDiscordNotification.update(rec, %{map_id: other.id})

    assert Enum.any?(errors, &match?(%Ash.Error.Invalid.NoSuchInput{input: :map_id}, &1))

    assert {:ok, reloaded} = MapDiscordNotification.by_map(map.id)
    assert reloaded.id == rec.id
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
    {:ok, reloaded} = MapDiscordNotification.by_map(map.id, load: [:webhook_url])
    assert reloaded.webhook_url == valid_url()
  end

  test "accepts a valid replacement url on UPDATE" do
    # Guards against a blanket-reject regression: replacement must still work.
    map = WandererAppWeb.Factory.insert(:map, %{})
    {:ok, rec} = MapDiscordNotification.create(%{map_id: map.id, webhook_url: valid_url()})
    replacement = "https://canary.discord.com/api/v10/webhooks/999/newtok"

    assert {:ok, updated} =
             MapDiscordNotification.update(rec, %{webhook_url: replacement}, load: [:webhook_url])

    assert updated.webhook_url == replacement
  end

  test "replacing the url clears the previous endpoint's failure state", %{map: map} do
    # A fresh webhook must not inherit a failure run: at 9 consecutive failures
    # the very next hiccup would disable a URL that has never actually failed.
    {:ok, rec} = MapDiscordNotification.create(%{map_id: map.id, webhook_url: valid_url()})
    {:ok, rec} = MapDiscordNotification.record_failure(rec, "boom")
    assert rec.consecutive_failures == 1
    assert rec.last_error == "boom"

    replacement = "https://canary.discord.com/api/v10/webhooks/999/newtok"
    assert {:ok, updated} = MapDiscordNotification.update(rec, %{webhook_url: replacement})

    assert updated.consecutive_failures == 0
    assert updated.last_error == nil
    assert updated.last_error_at == nil
  end

  test "a status-only update leaves the failure state alone", %{map: map} do
    # The reset is keyed to a URL change; toggling wh_only must not silently
    # forgive a run of failures against the URL that is still stored.
    {:ok, rec} = MapDiscordNotification.create(%{map_id: map.id, webhook_url: valid_url()})
    {:ok, rec} = MapDiscordNotification.record_failure(rec, "boom")

    assert {:ok, updated} = MapDiscordNotification.update(rec, %{wh_only: false})

    assert updated.consecutive_failures == 1
    assert updated.last_error == "boom"
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

  test "record_failure increments from the committed row, not a stale copy", %{map: map} do
    {:ok, stale} = MapDiscordNotification.create(%{map_id: map.id, webhook_url: valid_url()})

    # Advance the stored counter behind the back of the `stale` struct. The
    # increment is an atomic SQL expression (`consecutive_failures + 1`), so the
    # second call must still land on 2 even though `stale` still reads 0.
    {:ok, _} = MapDiscordNotification.record_failure(stale, "first")

    {:ok, updated} = MapDiscordNotification.record_failure(stale, "second")

    assert updated.consecutive_failures == 2
  end

  test "record_failure disables against the committed counter, not the stale one", %{map: map} do
    {:ok, stale} = MapDiscordNotification.create(%{map_id: map.id, webhook_url: valid_url()})

    # Drive the row to 9 without refreshing `stale`, which still reads 0.
    Enum.reduce(1..9, stale, fn _, acc ->
      {:ok, updated} = MapDiscordNotification.record_failure(acc, "boom")
      updated
    end)

    # The threshold is evaluated in SQL over the row's own pre-update value, so
    # this 10th failure disables even though the caller's copy says otherwise.
    {:ok, updated} = MapDiscordNotification.record_failure(stale, "tenth")

    assert updated.consecutive_failures == 10
    assert updated.enabled? == false
  end

  test "record_failure truncates an over-long error", %{map: map} do
    {:ok, rec} = MapDiscordNotification.create(%{map_id: map.id, webhook_url: valid_url()})

    # :last_error has a max_length of 500; without truncation the write would be
    # rejected outright, losing the failure record entirely.
    {:ok, updated} = MapDiscordNotification.record_failure(rec, String.duplicate("x", 900))

    assert String.length(updated.last_error) == 500
  end

  test "disable turns the config off immediately and stores the error", %{map: map} do
    # The 404 path: the webhook is gone upstream and will never recover, so this
    # bypasses record_failure's 10-failure threshold entirely.
    {:ok, rec} = MapDiscordNotification.create(%{map_id: map.id, webhook_url: valid_url()})

    {:ok, disabled} = MapDiscordNotification.disable(rec, "404 webhook not found")

    assert disabled.enabled? == false
    assert disabled.last_error == "404 webhook not found"
    assert disabled.last_error_at != nil
    # Not a failure *run* — the counter is untouched.
    assert disabled.consecutive_failures == 0
  end

  test "disable truncates an over-long error", %{map: map} do
    {:ok, rec} = MapDiscordNotification.create(%{map_id: map.id, webhook_url: valid_url()})

    {:ok, disabled} = MapDiscordNotification.disable(rec, String.duplicate("y", 900))

    assert disabled.enabled? == false
    assert String.length(disabled.last_error) == 500
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
