defmodule WandererApp.ExternalEvents.WebhookDispatcherTest do
  use WandererApp.DataCase, async: false

  alias WandererApp.Api.MapWebhookSubscription
  alias WandererApp.ExternalEvents.Event
  alias WandererApp.ExternalEvents.WebhookDispatcher

  setup do
    external_events = Application.get_env(:wanderer_app, :external_events, [])

    Application.put_env(
      :wanderer_app,
      :external_events,
      Keyword.put(external_events, :webhooks_enabled, true)
    )

    start_supervised!({Task.Supervisor, name: :"Elixir.WebhookDispatcher.TaskSupervisor"})

    on_exit(fn ->
      Application.put_env(:wanderer_app, :external_events, external_events)
    end)

    :ok
  end

  describe "handle_cast :dispatch_events" do
    test "processes matching subscriptions and returns updated state" do
      map = insert(:map)
      {:ok, map} = Ash.update(map, %{webhooks_enabled: true}, action: :toggle_webhooks)
      WebhookDispatcher.invalidate_cache(map.id)

      {:ok, _sub} =
        MapWebhookSubscription.create(%{
          map_id: map.id,
          url: "https://example.com/webhook",
          events: ["add_system"],
          active?: true
        })

      event = Event.new(map.id, :add_system, %{solar_system_id: 30000142})

      initial_state = %{
        task_supervisor: nil,
        delivery_count: 0,
        webhooks_enabled: true
      }

      assert {:noreply, new_state} =
               WebhookDispatcher.handle_cast({:dispatch_events, map.id, [event]}, initial_state)

      assert new_state.delivery_count == 1
    end

    test "processes non-matching subscriptions without BadMapError and returns state" do
      map = insert(:map)
      {:ok, map} = Ash.update(map, %{webhooks_enabled: true}, action: :toggle_webhooks)
      WebhookDispatcher.invalidate_cache(map.id)

      {:ok, _sub} =
        MapWebhookSubscription.create(%{
          map_id: map.id,
          url: "https://example.com/webhook",
          events: ["characters_updated"],
          active?: true
        })

      # Event type does not match subscription
      event = Event.new(map.id, :add_system, %{solar_system_id: 30000142})

      initial_state = %{
        task_supervisor: nil,
        delivery_count: 0,
        webhooks_enabled: true
      }

      assert {:noreply, new_state} =
               WebhookDispatcher.handle_cast({:dispatch_events, map.id, [event]}, initial_state)

      assert new_state.delivery_count == 1
    end

    test "handles maps without subscriptions gracefully" do
      map = insert(:map)
      {:ok, map} = Ash.update(map, %{webhooks_enabled: true}, action: :toggle_webhooks)
      WebhookDispatcher.invalidate_cache(map.id)

      event = Event.new(map.id, :add_system, %{solar_system_id: 30000142})

      initial_state = %{
        task_supervisor: nil,
        delivery_count: 5,
        webhooks_enabled: true
      }

      assert {:noreply, new_state} =
               WebhookDispatcher.handle_cast({:dispatch_events, map.id, [event]}, initial_state)

      assert new_state.delivery_count == 6
    end

    test "handles disabled webhooks gracefully" do
      map = insert(:map)
      # webhooks_enabled is false by default
      WebhookDispatcher.invalidate_cache(map.id)

      event = Event.new(map.id, :add_system, %{solar_system_id: 30000142})

      initial_state = %{
        task_supervisor: nil,
        delivery_count: 0,
        webhooks_enabled: true
      }

      assert {:noreply, new_state} =
               WebhookDispatcher.handle_cast({:dispatch_events, map.id, [event]}, initial_state)

      assert new_state.delivery_count == 1
    end
  end

  describe "handle_cast :dispatch_event" do
    test "processes single event without BadMapError" do
      map = insert(:map)
      {:ok, map} = Ash.update(map, %{webhooks_enabled: true}, action: :toggle_webhooks)
      WebhookDispatcher.invalidate_cache(map.id)

      {:ok, _sub} =
        MapWebhookSubscription.create(%{
          map_id: map.id,
          url: "https://example.com/webhook",
          events: ["add_system"],
          active?: true
        })

      event = Event.new(map.id, :add_system, %{solar_system_id: 30000142})

      initial_state = %{
        task_supervisor: nil,
        delivery_count: 0,
        webhooks_enabled: true
      }

      assert {:noreply, new_state} =
               WebhookDispatcher.handle_cast({:dispatch_event, map.id, event}, initial_state)

      assert new_state.delivery_count == 1
    end
  end
end
