defmodule WandererApp.ExternalEvents.WebhookDispatcher do
  @moduledoc """
  GenServer that handles HTTP delivery of webhook events.

  This system processes webhook delivery requests asynchronously,
  handles retry logic with exponential backoff, and tracks delivery status.

  Features:
  - Async HTTP delivery using Task.Supervisor  
  - Exponential backoff retry logic (3 attempts max)
  - HMAC-SHA256 signature generation for security
  - Delivery status tracking and telemetry
  - Payload size limits and filtering
  """

  use GenServer

  alias WandererApp.Api.MapWebhookSubscription
  alias WandererApp.ExternalEvents.Event

  require Logger

  # 1MB
  @max_payload_size 1_048_576
  @max_retries 3
  # 1 second
  @base_backoff_ms 1000
  # 60 seconds  
  @max_backoff_ms 60_000
  # ±25% jitter
  @jitter_range 0.25
  @max_consecutive_failures 10

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Dispatches a single event to all matching webhook subscriptions.
  """
  @spec dispatch_event(map_id :: String.t(), Event.t()) :: :ok
  def dispatch_event(map_id, %Event{} = event) do
    GenServer.cast(__MODULE__, {:dispatch_event, map_id, event})
  end

  @doc """
  Dispatches multiple events to all matching webhook subscriptions.
  Optimized for batch processing.
  """
  @spec dispatch_events(map_id :: String.t(), [Event.t()]) :: :ok
  def dispatch_events(map_id, events) when is_list(events) do
    GenServer.cast(__MODULE__, {:dispatch_events, map_id, events})
  end

  @impl true
  def init(_opts) do
    Logger.debug(fn -> "WebhookDispatcher started for HTTP event delivery" end)

    # Extract the pid from the tuple returned by start_link
    {:ok, task_supervisor_pid} =
      Task.Supervisor.start_link(name: WebhookDispatcher.TaskSupervisor)

    # Read configuration once during initialization
    webhooks_enabled = WandererApp.Env.webhooks_enabled?()

    {:ok,
     %{
       task_supervisor: task_supervisor_pid,
       delivery_count: 0,
       webhooks_enabled: webhooks_enabled
     }}
  end

  @impl true
  def handle_cast({:dispatch_event, map_id, event}, state) do
    Logger.debug(fn ->
      "WebhookDispatcher received single event for map #{map_id}, type: #{event.type}"
    end)

    # Emit telemetry for received event
    :telemetry.execute(
      [:wanderer_app, :webhook_dispatcher, :event_received],
      %{count: 1},
      %{map_id: map_id, event_type: event.type}
    )

    new_state = process_webhook_delivery(map_id, [event], state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:dispatch_events, map_id, events}, state) do
    Logger.debug(fn -> "WebhookDispatcher received #{length(events)} events for map #{map_id}" end)

    # Emit telemetry for batch events
    :telemetry.execute(
      [:wanderer_app, :webhook_dispatcher, :batch_received],
      %{count: length(events)},
      %{map_id: map_id}
    )

    new_state = process_webhook_delivery(map_id, events, state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("WebhookDispatcher received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  defp process_webhook_delivery(map_id, events, state) do
    # Check if webhooks are enabled globally and for this map
    case webhooks_allowed?(map_id, state.webhooks_enabled) do
      :ok ->
        # Get active webhook subscriptions for this map
        case get_active_subscriptions(map_id) do
          {:ok, [_ | _] = subscriptions} ->
            Logger.debug(fn ->
              "Found #{length(subscriptions)} active webhook subscriptions for map #{map_id}"
            end)

            process_active_subscriptions(subscriptions, events, state)

          {:ok, []} ->
            Logger.debug(fn -> "No webhook subscriptions found for map #{map_id}" end)
            state

          {:error, reason} ->
            Logger.error(
              "Failed to get webhook subscriptions for map #{map_id}: #{inspect(reason)}"
            )

            state
        end

      {:error, :webhooks_globally_disabled} ->
        Logger.debug(fn -> "Webhooks globally disabled" end)
        state

      {:error, :webhooks_disabled_for_map} ->
        Logger.debug(fn -> "Webhooks disabled for map #{map_id}" end)
        state

      {:error, reason} ->
        Logger.debug(fn -> "Webhooks not allowed for map #{map_id}: #{inspect(reason)}" end)
        state
    end
    |> Map.update(:delivery_count, length(events), &(&1 + length(events)))
  end

  defp process_active_subscriptions(subscriptions, events, state) do
    # Filter subscriptions based on event types
    relevant_subscriptions = filter_subscriptions_by_events(subscriptions, events)

    if length(relevant_subscriptions) > 0 do
      Logger.debug(fn -> "#{length(relevant_subscriptions)} subscriptions match event types" end)

      # Start async delivery tasks for each subscription  
      Enum.each(relevant_subscriptions, fn subscription ->
        start_delivery_task(subscription, events, state)
      end)
    end
  end

  defp get_active_subscriptions(map_id) do
    try do
      subscriptions = MapWebhookSubscription.active_by_map!(map_id)
      {:ok, subscriptions}
    rescue
      # Catch specific Ash errors
      _error in [Ash.Error.Query.NotFound] ->
        {:ok, []}

      error in [Ash.Error.Invalid] ->
        Logger.error("Invalid query for map #{map_id}: #{inspect(error)}")
        {:error, error}

      # Only catch database/connection errors
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "Database connection error getting subscriptions for map #{map_id}: #{inspect(error)}"
        )

        {:error, error}
    end
  end

  defp filter_subscriptions_by_events(subscriptions, events) do
    event_types = Enum.map(events, & &1.type) |> Enum.uniq()

    Enum.filter(subscriptions, fn subscription ->
      # Check if subscription matches any of the event types
      "*" in subscription.events or
        Enum.any?(event_types, fn event_type ->
          to_string(event_type) in subscription.events
        end)
    end)
  end

  defp start_delivery_task(subscription, events, _state) do
    Task.Supervisor.start_child(WebhookDispatcher.TaskSupervisor, fn ->
      deliver_webhook(subscription, events, 1)
    end)
  end

  defp deliver_webhook(subscription, events, attempt) do
    Logger.debug(fn ->
      "Attempting webhook delivery to #{subscription.url} (attempt #{attempt}/#{@max_retries})"
    end)

    start_time = System.monotonic_time(:millisecond)

    # Prepare payload
    case prepare_webhook_payload(events) do
      {:ok, payload} ->
        # Generate timestamp once for both signature and request
        timestamp = System.os_time(:second)

        # Generate signature with the timestamp
        signature = generate_signature(payload, subscription.secret, timestamp)

        # Make HTTP request with the same timestamp
        case make_http_request(subscription.url, payload, signature, timestamp) do
          {:ok, status_code} when status_code >= 200 and status_code < 300 ->
            delivery_time = System.monotonic_time(:millisecond) - start_time
            handle_delivery_success(subscription, delivery_time)

          {:ok, status_code} ->
            handle_delivery_failure(subscription, events, attempt, "HTTP #{status_code}")

          {:error, reason} ->
            handle_delivery_failure(subscription, events, attempt, inspect(reason))
        end

      {:error, reason} ->
        Logger.error("Failed to prepare webhook payload: #{inspect(reason)}")
        handle_delivery_failure(subscription, events, attempt, "Payload preparation failed")
    end
  end

  defp prepare_webhook_payload(events) do
    try do
      # Convert events to JSON
      json_events =
        Enum.map(events, fn event ->
          Event.to_json(event)
        end)

      # Create webhook payload
      payload =
        case length(json_events) do
          # Single event
          1 -> hd(json_events)
          # Batch events
          _ -> %{events: json_events}
        end

      json_payload = Jason.encode!(payload)

      # Check payload size
      if byte_size(json_payload) > @max_payload_size do
        {:error, :payload_too_large}
      else
        {:ok, json_payload}
      end
    rescue
      e -> {:error, e}
    end
  end

  defp generate_signature(payload, secret, timestamp) do
    data_to_sign = "#{timestamp}.#{payload}"

    signature =
      :crypto.mac(:hmac, :sha256, secret, data_to_sign)
      |> Base.encode16(case: :lower)

    "sha256=#{signature}"
  end

  defp make_http_request(url, payload, signature, timestamp) do
    headers = [
      {"Content-Type", "application/json"},
      {"User-Agent", "Wanderer-Webhook/1.0"},
      {"X-Wanderer-Signature", signature},
      {"X-Wanderer-Timestamp", to_string(timestamp)},
      {"X-Wanderer-Version", "1"}
    ]

    request = Finch.build(:post, url, headers, payload)

    case Finch.request(request, WandererApp.Finch, timeout: 30_000) do
      {:ok, %Finch.Response{status: status}} ->
        {:ok, status}

      {:error, %Finch.Error{reason: reason}} ->
        {:error, reason}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_delivery_success(subscription, delivery_time_ms) do
    Logger.debug(fn ->
      "Webhook delivery successful to #{subscription.url} (#{delivery_time_ms}ms)"
    end)

    # Update subscription with successful delivery
    try do
      MapWebhookSubscription.update!(subscription, %{
        last_delivery_at: DateTime.utc_now(),
        consecutive_failures: 0,
        last_error: nil,
        last_error_at: nil
      })
    rescue
      e ->
        Logger.error(
          "Failed to update webhook subscription after successful delivery: #{inspect(e)}"
        )
    end

    # Emit telemetry
    :telemetry.execute(
      [:wanderer_app, :webhook_dispatcher, :delivery_success],
      %{delivery_time: delivery_time_ms},
      %{url: subscription.url, subscription_id: subscription.id}
    )
  end

  defp handle_delivery_failure(subscription, events, attempt, error_reason) do
    Logger.warning(
      "Webhook delivery failed to #{subscription.url}: #{error_reason} (attempt #{attempt}/#{@max_retries})"
    )

    if attempt < @max_retries do
      # Calculate backoff delay with jitter
      backoff_ms = calculate_backoff(attempt)
      Logger.debug(fn -> "Retrying webhook delivery in #{backoff_ms}ms" end)

      # Schedule retry
      Process.sleep(backoff_ms)
      deliver_webhook(subscription, events, attempt + 1)
    else
      # All retries exhausted
      Logger.error(
        "Webhook delivery failed permanently to #{subscription.url} after #{@max_retries} attempts"
      )

      new_consecutive_failures = subscription.consecutive_failures + 1

      # Update subscription with failure
      update_attrs = %{
        consecutive_failures: new_consecutive_failures,
        # Truncate to 1000 chars
        last_error: String.slice(error_reason, 0, 1000),
        last_error_at: DateTime.utc_now()
      }

      # Disable subscription if too many consecutive failures
      update_attrs =
        if new_consecutive_failures >= @max_consecutive_failures do
          Logger.warning(
            "Disabling webhook subscription #{subscription.id} due to #{@max_consecutive_failures} consecutive failures"
          )

          Map.put(update_attrs, :active?, false)
        else
          update_attrs
        end

      try do
        MapWebhookSubscription.update!(subscription, update_attrs)
      rescue
        e ->
          Logger.error("Failed to update webhook subscription after failure: #{inspect(e)}")
      end

      # Emit telemetry
      :telemetry.execute(
        [:wanderer_app, :webhook_dispatcher, :delivery_failure],
        %{consecutive_failures: new_consecutive_failures},
        %{
          url: subscription.url,
          subscription_id: subscription.id,
          error: error_reason,
          disabled: new_consecutive_failures >= @max_consecutive_failures
        }
      )
    end
  end

  defp calculate_backoff(attempt) do
    # Exponential backoff: base * 2^(attempt-1)
    base_delay = @base_backoff_ms * :math.pow(2, attempt - 1)

    # Cap at max backoff
    capped_delay = min(base_delay, @max_backoff_ms)

    # Add jitter (±25%)
    jitter_amount = capped_delay * @jitter_range
    jitter = :rand.uniform() * 2 * jitter_amount - jitter_amount

    round(capped_delay + jitter)
  end

  defp webhooks_allowed?(map_id, webhooks_globally_enabled) do
    with true <- webhooks_globally_enabled,
         {:ok, map} <- WandererApp.Api.Map.by_id(map_id),
         true <- map.webhooks_enabled do
      :ok
    else
      false -> {:error, :webhooks_globally_disabled}
      nil -> {:error, :webhooks_globally_disabled}
      {:error, :not_found} -> {:error, :map_not_found}
      %{webhooks_enabled: false} -> {:error, :webhooks_disabled_for_map}
      {:error, reason} -> {:error, reason}
      error -> {:error, {:unexpected_error, error}}
    end
  end
end
