defmodule WandererApp.ExternalEvents.EventFilter do
  @moduledoc """
  Event filtering logic for external event streams (WebSocket, SSE, webhooks).

  Handles parsing of event filters from client requests and matching events
  against those filters. Supports wildcard ("*") and comma-separated event lists.
  """

  @supported_events [
    # System events
    :add_system,
    :deleted_system,
    :system_renamed,
    :system_metadata_changed,
    # Connection events
    :connection_added,
    :connection_removed,
    :connection_updated,
    # Character events (existing)
    :character_added,
    :character_removed,
    :character_updated,
    # Character events (new for SSE)
    :character_location_changed,
    :character_online_status_changed,
    :character_ship_changed,
    :character_ready_status_changed,
    # Signature events
    :signature_added,
    :signature_removed,
    :signatures_updated,
    # Kill events
    :map_kill,
    # ACL events
    :acl_member_added,
    :acl_member_removed,
    :acl_member_updated,
    # Rally point events
    :rally_point_added,
    :rally_point_removed
  ]

  @type event_type :: atom()
  @type event_filter :: [event_type()]

  @doc """
  Parses event filter from client input.

  ## Examples

      iex> EventFilter.parse(nil)
      [:add_system, :deleted_system, ...]  # all events
      
      iex> EventFilter.parse("*")
      [:add_system, :deleted_system, ...]  # all events
      
      iex> EventFilter.parse("add_system,character_added")
      [:add_system, :character_added]
      
      iex> EventFilter.parse("invalid,add_system")
      [:add_system]  # invalid events are filtered out
  """
  @spec parse(nil | String.t()) :: event_filter()
  def parse(nil), do: @supported_events
  def parse("*"), do: @supported_events
  def parse(""), do: @supported_events

  def parse(events) when is_binary(events) do
    events
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&to_event_atom/1)
    |> Enum.filter(&(&1 in @supported_events))
    |> Enum.uniq()
  end

  @doc """
  Checks if an event type matches the given filter.

  ## Examples

      iex> EventFilter.matches?(:add_system, [:add_system, :character_added])
      true
      
      iex> EventFilter.matches?(:map_kill, [:add_system, :character_added])
      false
  """
  @spec matches?(event_type(), event_filter()) :: boolean()
  def matches?(event_type, filter) when is_list(filter) do
    # Convert string event types to atoms for comparison
    atom_event_type =
      case event_type do
        atom when is_atom(atom) ->
          atom

        string when is_binary(string) ->
          try do
            String.to_existing_atom(string)
          rescue
            ArgumentError -> nil
          end

        _ ->
          nil
      end

    atom_event_type && atom_event_type in filter
  end

  @doc """
  Returns all supported event types.
  """
  @spec supported_events() :: event_filter()
  def supported_events, do: @supported_events

  @doc """
  Validates if an event type is supported.
  """
  @spec valid_event?(event_type()) :: boolean()
  def valid_event?(event_type) when is_atom(event_type) do
    event_type in @supported_events
  end

  # Helper to safely convert string to atom, returns nil for invalid atoms
  defp to_event_atom(event_string) do
    try do
      String.to_existing_atom(event_string)
    rescue
      ArgumentError -> nil
    end
  end
end
