defmodule WandererApp.Map.Audit do
  @moduledoc """
  Manager map subscription plans

  This module now delegates to SecurityAudit for consistency.
  It maintains backward compatibility while using the centralized audit system.
  """

  require Ash.Query
  require Logger

  @week_seconds :timer.hours(24 * 7)
  @month_seconds @week_seconds * 4
  @audit_expired_seconds @month_seconds * 3

  def track_map_subscription_event(event_type, metadata) do
    mapped_type =
      case event_type do
        "subscription.created" -> :subscription_created
        "subscription.updated" -> :subscription_updated
        "subscription.deleted" -> :subscription_deleted
        _ -> :subscription_unknown
      end

    track_map_event(mapped_type, metadata)
  end

  def archive() do
    Logger.info("Start map audit arhiving...")

    WandererApp.Api.UserActivity
    |> Ash.Query.filter(inserted_at: [less_than: get_expired_at()])
    |> Ash.bulk_destroy!(:archive, %{}, batch_size: 100)

    Logger.info(fn -> "Audit arhived" end)
    :ok
  end

  defdelegate get_map_activity_query(map_id, period, activity),
    to: WandererApp.SecurityAudit

  defdelegate track_acl_event(event_type, metadata),
    to: WandererApp.SecurityAudit

  defdelegate track_map_event(event_type, metadata),
    to: WandererApp.SecurityAudit

  defp get_expired_at(), do: DateTime.utc_now() |> DateTime.add(-@audit_expired_seconds, :second)
end
