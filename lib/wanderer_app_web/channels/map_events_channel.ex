defmodule WandererAppWeb.MapEventsChannel do
  @moduledoc """
  WebSocket channel for external map events.

  This channel delivers events from the external event system to WebSocket clients.
  It uses separate topics from the internal PubSub system to avoid conflicts.

  ## Topic Format

  Clients subscribe to: `external_events:map:MAP_ID`

  ## Usage

  ```javascript
  // Connect with API key authentication
  const socket = new Phoenix.Socket("/socket/websocket", {
    params: { api_key: "your_map_api_key_here" }
  })
  socket.connect()

  const channel = socket.channel("external_events:map:123", {})
  channel.join()
    .receive("ok", resp => { console.log("Joined successfully", resp) })
    .receive("error", resp => { console.log("Unable to join", resp) })

  channel.on("external_event", payload => {
    console.log("Received event:", payload)
  })
  ```
  """

  use WandererAppWeb, :channel

  require Logger

  # Log when module is loaded
  Logger.info("MapEventsChannel module loaded")

  @impl true
  def join("external_events:map:" <> map_id, payload, socket) do
    Logger.info("Attempting to join external events channel for map: #{map_id}")

    with {:ok, api_key} <- get_api_key(socket),
         {:ok, map} <- validate_map_access(map_id, api_key) do
      handle_successful_join(map_id, map, payload, socket)
    else
      {:error, :missing_api_key} ->
        Logger.warning("WebSocket join failed: missing API key")
        {:error, %{reason: "Authentication required. Provide api_key parameter."}}

      {:error, :map_not_found} ->
        Logger.warning("WebSocket join failed: map not found - #{map_id}")
        {:error, %{reason: "Map not found"}}

      {:error, :unauthorized} ->
        Logger.warning("WebSocket join failed: unauthorized for map #{map_id}")
        {:error, %{reason: "Unauthorized: Invalid API key for this map"}}

      error ->
        Logger.error("WebSocket join failed: #{inspect(error)}")
        {:error, %{reason: "Authentication failed"}}
    end
  end

  def join(topic, _payload, _socket) do
    Logger.warning("Attempted to join invalid external events topic: #{topic}")
    {:error, %{reason: "Invalid topic format. Use: external_events:map:MAP_ID"}}
  end

  defp handle_successful_join(map_id, map, payload, socket) do
    Logger.info("Client authenticated and joined external events for map #{map_id}")

    # Parse event filters from join payload
    event_filter = parse_event_filter(payload)
    Logger.debug(fn -> "Event filter: #{inspect(event_filter)}" end)

    # Subscribe to external events for this map
    topic = "external_events:map:#{map_id}"
    Phoenix.PubSub.subscribe(WandererApp.PubSub, topic)
    Logger.debug(fn -> "Subscribed to PubSub topic: #{topic}" end)

    # Store map information and event filter in socket assigns
    socket =
      socket
      |> assign(:map_id, map_id)
      |> assign(:map, map)
      |> assign(:event_filter, event_filter)

    # Send initial connection acknowledgment
    {:ok, %{status: "connected", map_id: map_id, map_name: map.name, event_filter: event_filter},
     socket}
  end

  @impl true
  def handle_info({:external_event, event}, socket) do
    # Check if this event should be sent based on the client's filter
    if should_send_event?(event, socket.assigns[:event_filter]) do
      # Forward external events to WebSocket clients
      # The event is a map that needs to be sent directly
      push(socket, "external_event", event)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket) do
    # Silently ignore other messages - this can happen when multiple
    # channels are subscribed to the same PubSub topic
    {:noreply, socket}
  end

  @impl true
  def handle_in("ping", payload, socket) do
    # Simple ping/pong for client heartbeat testing
    {:reply, {:ok, %{pong: payload}}, socket}
  end

  @impl true
  def handle_in(event, payload, socket) do
    Logger.debug(fn -> "Unhandled incoming event: #{event} with payload: #{inspect(payload)}" end)
    {:noreply, socket}
  end

  @impl true
  def terminate(reason, socket) do
    map_id = socket.assigns[:map_id]

    Logger.debug(fn ->
      "Client disconnected from external events for map #{map_id}, reason: #{inspect(reason)}"
    end)

    :ok
  end

  # Private helper functions for authentication

  defp get_api_key(socket) do
    case socket.assigns[:api_key] do
      api_key when is_binary(api_key) and api_key != "" ->
        {:ok, api_key}

      _ ->
        {:error, :missing_api_key}
    end
  end

  defp validate_map_access(map_id, api_key) do
    Logger.debug(fn -> "Validating map access for map_id: #{map_id}" end)
    alias WandererApp.Api.Map, as: ApiMap
    alias Plug.Crypto

    case resolve_map_identifier(map_id) do
      {:ok, map} ->
        Logger.info("Map found: #{map.name}, checking API key...")
        Logger.info("Map public_api_key present: #{not is_nil(map.public_api_key)}")
        Logger.info("Provided API key: #{String.slice(api_key, 0..7)}...")

        if is_binary(map.public_api_key) &&
             Crypto.secure_compare(map.public_api_key, api_key) do
          Logger.info("API key matches, access granted")
          {:ok, map}
        else
          Logger.info("API key mismatch or invalid")
          Logger.info("Map has public_api_key: #{is_binary(map.public_api_key)}")
          {:error, :unauthorized}
        end

      {:error, :not_found} ->
        Logger.debug(fn -> "Map not found" end)
        {:error, :map_not_found}

      error ->
        Logger.error("Map validation error: #{inspect(error)}")
        {:error, :validation_failed}
    end
  end

  # Try to resolve map identifier - could be map_id or slug
  defp resolve_map_identifier(identifier) do
    Logger.debug(fn -> "Resolving map identifier: #{identifier}" end)
    alias WandererApp.Api.Map, as: ApiMap

    # Try ID lookup first
    Logger.debug(fn -> "Trying ID lookup..." end)

    case ApiMap.by_id(identifier) do
      {:ok, map} ->
        Logger.debug(fn -> "Found by ID: #{map.name}" end)
        {:ok, map}

      error ->
        Logger.debug(fn -> "ID lookup failed: #{inspect(error)}, trying slug lookup..." end)
        resolve_by_slug(identifier)
    end
  end

  defp resolve_by_slug(identifier) do
    alias WandererApp.Api.Map, as: ApiMap

    case ApiMap.get_map_by_slug(identifier) do
      {:ok, map} ->
        Logger.debug(fn -> "Found by slug: #{map.name}" end)
        {:ok, map}

      error ->
        Logger.debug(fn -> "Slug lookup failed: #{inspect(error)}" end)
        {:error, :not_found}
    end
  end

  # Event filtering helper functions

  defp parse_event_filter(%{"events" => events}) when is_list(events) do
    # Convert string event types to atoms and validate them
    events
    |> Enum.map(&parse_event_type/1)
    # Remove nil values from invalid event types
    |> Enum.filter(& &1)
    |> case do
      # If no valid events specified, default to all
      [] -> :all
      valid_events -> valid_events
    end
  end

  defp parse_event_filter(%{"events" => "*"}), do: :all
  defp parse_event_filter(%{"events" => ["*"]}), do: :all
  # Default to all events if no filter specified
  defp parse_event_filter(_), do: :all

  defp parse_event_type(event_type) when is_binary(event_type) do
    alias WandererApp.ExternalEvents.Event

    # Convert string to atom if it's a valid event type
    try do
      atom = String.to_existing_atom(event_type)
      if Event.valid_event_type?(atom), do: atom, else: nil
    rescue
      ArgumentError -> nil
    end
  end

  defp parse_event_type(_), do: nil

  defp should_send_event?(_event, :all), do: true

  defp should_send_event?(event, event_filter) when is_list(event_filter) do
    # Extract event type from the event map
    event_type =
      case event do
        %{"type" => type} when is_binary(type) -> String.to_existing_atom(type)
        %{"type" => type} when is_atom(type) -> type
        _ -> nil
      end

    event_type in event_filter
  end

  # Default to sending if filter format is unexpected
  defp should_send_event?(_event, _filter), do: true
end
