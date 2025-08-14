defmodule WandererApp.ExternalEvents.Event do
  @moduledoc """
  Event struct for external webhook and WebSocket delivery.

  This is completely separate from the internal PubSub event system
  and is only used for external client notifications.
  """

  @type event_type ::
          :add_system
          | :deleted_system
          | :system_renamed
          | :system_metadata_changed
          | :signatures_updated
          | :signature_added
          | :signature_removed
          | :connection_added
          | :connection_removed
          | :connection_updated
          | :character_added
          | :character_removed
          | :character_updated
          | :map_kill
          | :acl_member_added
          | :acl_member_removed
          | :acl_member_updated
          | :rally_point_added
          | :rally_point_removed

  @type t :: %__MODULE__{
          # ULID for ordering
          id: String.t(),
          # Map identifier
          map_id: String.t(),
          # Event type
          type: event_type(),
          # Event-specific data
          payload: map(),
          # When the event occurred
          timestamp: DateTime.t()
        }

  defstruct [:id, :map_id, :type, :payload, :timestamp]

  @doc """
  Creates a new external event with ULID for ordering.

  Validates that the event_type is supported before creating the event.
  """
  @spec new(String.t(), event_type(), map()) :: t() | {:error, :invalid_event_type}
  def new(map_id, event_type, payload) when is_binary(map_id) and is_map(payload) do
    if valid_event_type?(event_type) do
      %__MODULE__{
        id: Ecto.ULID.generate(System.system_time(:millisecond)),
        map_id: map_id,
        type: event_type,
        payload: payload,
        timestamp: DateTime.utc_now()
      }
    else
      raise ArgumentError,
            "Invalid event type: #{inspect(event_type)}. Must be one of: #{supported_event_types() |> Enum.map(&to_string/1) |> Enum.join(", ")}"
    end
  end

  @doc """
  Converts an event to JSON format for delivery.
  """
  @spec to_json(t()) :: map()
  def to_json(%__MODULE__{} = event) do
    %{
      "id" => event.id,
      "type" => to_string(event.type),
      "map_id" => event.map_id,
      "timestamp" => DateTime.to_iso8601(event.timestamp),
      "payload" => serialize_payload(event.payload)
    }
  end

  # Convert Ash structs and other complex types to plain maps
  defp serialize_payload(payload) when is_struct(payload) do
    serialize_payload(payload, MapSet.new())
  end

  defp serialize_payload(payload) when is_map(payload) do
    serialize_payload(payload, MapSet.new())
  end

  # Define allowlisted fields for different struct types
  @system_fields [
    :id,
    :solar_system_id,
    :name,
    :position_x,
    :position_y,
    :visible,
    :locked,
    # ADD
    :temporary_name,
    # ADD
    :labels,
    # ADD
    :description,
    # ADD
    :status
  ]
  @character_fields [
    :id,
    :character_id,
    :character_eve_id,
    :name,
    :corporation_id,
    :alliance_id,
    :ship_type_id,
    # ADD: Ship name for external clients
    :ship_name,
    :online,
    # ADD: Character location
    :solar_system_id,
    # ADD: Structure location
    :structure_id,
    # ADD: Station location
    :station_id
  ]
  @connection_fields [
    :id,
    :source_id,
    :target_id,
    :connection_type,
    :time_status,
    :mass_status,
    :ship_size
  ]
  @signature_fields [:id, :signature_id, :name, :type, :group]

  # Overloaded versions with visited tracking
  defp serialize_payload(payload, visited) when is_struct(payload) do
    # Check for circular reference
    ref = {payload.__struct__, Map.get(payload, :id)}

    if MapSet.member?(visited, ref) do
      # Return a reference indicator instead of recursing
      %{"__ref__" => to_string(ref)}
    else
      visited = MapSet.put(visited, ref)

      # Get allowlisted fields based on struct type
      allowed_fields = get_allowed_fields(payload.__struct__)

      payload
      |> Map.from_struct()
      |> Map.take(allowed_fields)
      |> serialize_fields(visited)
    end
  end

  # Get allowed fields based on struct type
  defp get_allowed_fields(module) do
    module_name = module |> Module.split() |> List.last()

    case module_name do
      "MapSystem" -> @system_fields
      "MapCharacter" -> @character_fields
      "MapConnection" -> @connection_fields
      "MapSystemSignature" -> @signature_fields
      # Default minimal fields for unknown types
      _ -> [:id, :name]
    end
  end

  defp serialize_payload(payload, visited) when is_map(payload) do
    Map.new(payload, fn {k, v} -> {to_string(k), serialize_value(v, visited)} end)
  end

  defp serialize_fields(fields, visited) do
    Enum.reduce(fields, %{}, fn {k, v}, acc ->
      if is_nil(v) do
        acc
      else
        Map.put(acc, to_string(k), serialize_value(v, visited))
      end
    end)
  end

  defp serialize_value(%DateTime{} = dt, _visited), do: DateTime.to_iso8601(dt)
  defp serialize_value(%NaiveDateTime{} = dt, _visited), do: NaiveDateTime.to_iso8601(dt)
  defp serialize_value(v, visited) when is_struct(v), do: serialize_payload(v, visited)
  defp serialize_value(v, visited) when is_map(v), do: serialize_payload(v, visited)
  defp serialize_value(v, visited) when is_list(v), do: Enum.map(v, &serialize_value(&1, visited))
  defp serialize_value(v, _visited), do: v

  @doc """
  Returns all supported event types.
  """
  @spec supported_event_types() :: [event_type()]
  def supported_event_types do
    [
      :add_system,
      :deleted_system,
      :system_renamed,
      :system_metadata_changed,
      :signatures_updated,
      :signature_added,
      :signature_removed,
      :connection_added,
      :connection_removed,
      :connection_updated,
      :character_added,
      :character_removed,
      :character_updated,
      :map_kill,
      :acl_member_added,
      :acl_member_removed,
      :acl_member_updated,
      :rally_point_added,
      :rally_point_removed
    ]
  end

  @doc """
  Validates an event type.
  """
  @spec valid_event_type?(atom()) :: boolean()
  def valid_event_type?(event_type) when is_atom(event_type) do
    event_type in supported_event_types()
  end

  def valid_event_type?(_), do: false
end
