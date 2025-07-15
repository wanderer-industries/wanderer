defmodule WandererApp.Map.Audit do
  @moduledoc """
  Manager map subscription plans
  """

  require Ash.Query
  require Logger

  alias WandererApp.SecurityAudit

  @logger Application.compile_env(:wanderer_app, :logger)

  @week_seconds :timer.hours(24 * 7)
  @month_seconds @week_seconds * 4
  @audit_expired_seconds @month_seconds * 3

  def track_map_subscription_event(event_type, metadata) do
    case event_type do
      "subscription.created" ->
        track_map_event(event_type, metadata)

      "subscription.updated" ->
        track_map_event(event_type, metadata)

      "subscription.deleted" ->
        track_map_event(event_type, metadata)

      _ ->
        {:ok, nil}
    end
  end

  def archive() do
    Logger.info("Start map audit arhiving...")

    WandererApp.Api.UserActivity
    |> Ash.Query.filter(inserted_at: [less_than: get_expired_at()])
    |> Ash.bulk_destroy!(:archive, %{}, batch_size: 100)

    Logger.info(fn -> "Audit arhived" end)
    :ok
  end

  def get_activity_query(map_id, period, activity) do
    {from, to} = period |> get_period()

    query =
      WandererApp.Api.UserActivity
      |> Ash.Query.filter(
        and: [
          [entity_id: map_id],
          [inserted_at: [greater_than_or_equal: from]],
          [inserted_at: [less_than_or_equal: to]]
        ]
      )

    query =
      activity
      |> case do
        "all" ->
          query

        activity ->
          query
          |> Ash.Query.filter(event_type: activity)
      end

    query
    |> Ash.Query.sort(inserted_at: :desc)
  end

  @doc """
  Get combined activity including security events for a map.
  """
  def get_combined_activity_query(map_id, period, activity) do
    {from, to} = period |> get_period()

    # Get regular map activity
    map_query = get_activity_query(map_id, period, activity)

    # Get security events related to this map
    security_query =
      WandererApp.Api.UserActivity
      |> Ash.Query.filter(entity_type: :security_event)
      |> Ash.Query.filter(inserted_at: [greater_than_or_equal: from])
      |> Ash.Query.filter(inserted_at: [less_than_or_equal: to])
      |> Ash.Query.sort(inserted_at: :desc)

    # For now, return the regular map query
    # In a full implementation, you might want to union these queries
    map_query
  end

  @doc """
  Get security events for a specific map.
  """
  def get_security_events_for_map(map_id, period \\ "1D") do
    {from, to} = period |> get_period()

    # Get security events that might be related to this map
    # This could include data access events, permission denied events, etc.
    SecurityAudit.get_events_in_range(from, to)
    |> Enum.filter(fn event ->
      case Jason.decode(event.event_data || "{}") do
        {:ok, data} ->
          # Check if the event data contains references to this map
          data["resource_id"] == map_id ||
            data["entity_id"] == map_id ||
            data["map_id"] == map_id

        _ ->
          false
      end
    end)
  end

  def track_acl_event(
        event_type,
        %{user_id: user_id, acl_id: acl_id} = metadata
      )
      when not is_nil(user_id) and not is_nil(acl_id),
      do:
        WandererApp.Api.UserActivity.new(%{
          user_id: user_id,
          entity_type: :access_list,
          entity_id: acl_id,
          event_type: event_type,
          event_data: metadata |> Map.drop([:user_id, :acl_id]) |> Jason.encode!()
        })

  def track_acl_event(_event_type, _metadata), do: {:ok, nil}

  def track_map_event(
        event_type,
        %{character_id: character_id, user_id: user_id, map_id: map_id} = metadata
      )
      when not is_nil(character_id) and not is_nil(user_id) and not is_nil(map_id) do
    # Log regular map activity
    result =
      WandererApp.Api.UserActivity.new(%{
        character_id: character_id,
        user_id: user_id,
        entity_type: :map,
        entity_id: map_id,
        event_type: event_type,
        event_data: metadata |> Map.drop([:character_id, :user_id, :map_id]) |> Jason.encode!()
      })

    # Also log security-relevant map events
    if security_relevant_event?(event_type) do
      SecurityAudit.log_data_access(
        "map",
        map_id,
        user_id,
        event_type,
        metadata
      )
    end

    result
  end

  def track_map_event(_event_type, _metadata), do: {:ok, nil}

  defp get_period("1H") do
    now = DateTime.utc_now()
    start_date = now |> DateTime.add(-1 * 3600, :second)
    {start_date, now}
  end

  defp get_period("1D") do
    now = DateTime.utc_now()
    start_date = now |> DateTime.add(-24 * 3600, :second)
    {start_date, now}
  end

  defp get_period("1W") do
    now = DateTime.utc_now()
    start_date = now |> DateTime.add(-24 * 3600 * 7, :second)
    {start_date, now}
  end

  defp get_period("1M") do
    now = DateTime.utc_now()
    start_date = now |> DateTime.add(-24 * 3600 * 31, :second)
    {start_date, now}
  end

  defp get_period("2M") do
    now = DateTime.utc_now()
    start_date = now |> DateTime.add(-24 * 3600 * 31 * 2, :second)
    {start_date, now}
  end

  defp get_period("3M") do
    now = DateTime.utc_now()
    start_date = now |> DateTime.add(-24 * 3600 * 31 * 3, :second)
    {start_date, now}
  end

  defp get_period(_), do: get_period("1H")

  defp get_expired_at(), do: DateTime.utc_now() |> DateTime.add(-@audit_expired_seconds, :second)

  defp security_relevant_event?(event_type) do
    # Define which map events should also be logged as security events
    event_type in [
      :map_acl_added,
      :map_acl_removed,
      :map_acl_updated,
      :map_acl_member_added,
      :map_acl_member_removed,
      :map_acl_member_updated,
      :map_removed,
      :character_added,
      :character_removed
    ]
  end
end
