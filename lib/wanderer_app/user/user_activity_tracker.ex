defmodule WandererApp.User.ActivityTracker do
  @moduledoc false
  use GenServer

  require Logger

  @name __MODULE__

  def start_link(args) do
    GenServer.start(__MODULE__, args, name: @name)
  end

  @impl true
  def init(_args) do
    Logger.info("#{__MODULE__} started")

    {:ok, %{}, {:continue, :start}}
  end

  @impl true
  def handle_continue(:start, state) do
    :telemetry.attach_many(
      "map_user_activity",
      [
        [:wanderer_app, :map, :hub, :add],
        [:wanderer_app, :map, :hub, :remove],
        [:wanderer_app, :map, :system, :add],
        [:wanderer_app, :map, :system, :update],
        [:wanderer_app, :map, :systems, :remove],
        [:wanderer_app, :map, :connection, :add],
        [:wanderer_app, :map, :connection, :update],
        [:wanderer_app, :map, :connection, :remove],
        [:wanderer_app, :map, :acl, :add],
        [:wanderer_app, :map, :acl, :remove],
        [:wanderer_app, :acl, :member, :add],
        [:wanderer_app, :acl, :member, :remove],
        [:wanderer_app, :acl, :member, :update]
      ],
      &handle_event/4,
      nil
    )

    {:noreply, state}
  end

  def handle_event([:wanderer_app, :map, :system, :add], _event_data, metadata, _config) do
    {:ok, _} = _track_map_event(:system_added, metadata)
  end

  def handle_event([:wanderer_app, :map, :hub, :add], _event_data, metadata, _config) do
    {:ok, _} = _track_map_event(:hub_added, metadata)
  end

  def handle_event([:wanderer_app, :map, :hub, :remove], _event_data, metadata, _config) do
    {:ok, _} = _track_map_event(:hub_removed, metadata)
  end

  def handle_event([:wanderer_app, :map, :system, :update], _event_data, metadata, _config) do
    {:ok, _} = _track_map_event(:system_updated, metadata)
  end

  def handle_event([:wanderer_app, :map, :systems, :remove], _event_data, metadata, _config) do
    {:ok, _} = _track_map_event(:systems_removed, metadata)
  end

  def handle_event([:wanderer_app, :map, :connection, :add], _event_data, metadata, _config) do
    {:ok, _} = _track_map_event(:map_connection_added, metadata)
  end

  def handle_event([:wanderer_app, :map, :connection, :update], _event_data, metadata, _config) do
    {:ok, _} = _track_map_event(:map_connection_updated, metadata)
  end

  def handle_event([:wanderer_app, :map, :connection, :remove], _event_data, metadata, _config) do
    {:ok, _} = _track_map_event(:map_connection_removed, metadata)
  end

  def handle_event([:wanderer_app, :acl, :member, :add], _event_data, metadata, _config) do
    {:ok, _} = _track_acl_event(:map_acl_member_added, metadata)
  end

  def handle_event([:wanderer_app, :acl, :member, :remove], _event_data, metadata, _config) do
    {:ok, _} = _track_acl_event(:map_acl_member_removed, metadata)
  end

  def handle_event([:wanderer_app, :acl, :member, :update], _event_data, metadata, _config) do
    {:ok, _} = _track_acl_event(:map_acl_member_updated, metadata)
  end

  def handle_event([:wanderer_app, :map, :acl, :add], _event_data, _metadata, _config) do
    # {:ok, _} = _track_map_event(:map_acl_added, metadata)
  end

  def handle_event([:wanderer_app, :map, :acl, :remove], _event_data, _metadata, _config) do
    # {:ok, _} = _track_map_event(:map_acl_removed, metadata)
  end

  defp _track_map_event(
         event_type,
         metadata
       ),
       do: WandererApp.Map.Audit.track_map_event(event_type, metadata)

  defp _track_acl_event(
         event_type,
         metadata
       ),
       do: WandererApp.Map.Audit.track_acl_event(event_type, metadata)

  @impl true
  def terminate(_reason, _state) do
    :ok
  end
end
