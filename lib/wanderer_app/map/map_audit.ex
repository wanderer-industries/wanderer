defmodule WandererApp.Map.Audit do
  @moduledoc """
  Manager map subscription plans
  """

  require Ash.Query
  require Logger

  @logger Application.compile_env(:wanderer_app, :logger)

  @week_seconds :timer.hours(24 * 7)

  def archive() do
    @logger.info("Start map audit arhiving...")

    WandererApp.Api.UserActivity
    |> Ash.Query.filter(inserted_at: [less_than: _get_expired_at()])
    |> Ash.bulk_destroy!(:archive, %{}, batch_size: 100)

    @logger.info(fn -> "Audit arhived" end)
    :ok
  end

  def get_activity_page(map_id, page, per_page, period, activity) do
    {from, to} = period |> _get_period()

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
    |> WandererApp.Api.read(
      page: [limit: per_page, offset: (page - 1) * per_page],
      load: [:character]
    )
  end

  def track_acl_event(
        event_type,
        %{user_id: user_id, acl_id: acl_id} = metadata
      ),
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
      ),
      do:
        WandererApp.Api.UserActivity.new(%{
          character_id: character_id,
          user_id: user_id,
          entity_type: :map,
          entity_id: map_id,
          event_type: event_type,
          event_data: metadata |> Map.drop([:character_id, :user_id, :map_id]) |> Jason.encode!()
        })

  def track_map_event(_event_type, _metadata), do: {:ok, nil}

  defp _get_period("1H") do
    now = DateTime.utc_now()
    start_date = now |> DateTime.add(-1 * 3600, :second)
    {start_date, now}
  end

  defp _get_period("1D") do
    now = DateTime.utc_now()
    start_date = now |> DateTime.add(-24 * 3600, :second)
    {start_date, now}
  end

  defp _get_period("1W") do
    now = DateTime.utc_now()
    start_date = now |> DateTime.add(-24 * 3600 * 7, :second)
    {start_date, now}
  end

  # defp _get_period("1M") do
  #   now = DateTime.utc_now()
  #   start_date = now |> DateTime.add(-24 * 3600 * 31, :second)
  #   {start_date, now}
  # end

  # defp _get_period("ALL") do
  #   now = DateTime.utc_now()

  #   start_date = %{
  #     now
  #     | year: 2000,
  #       month: 1,
  #       day: 1,
  #       hour: 00,
  #       minute: 00,
  #       second: 00,
  #       microsecond: {0, 0}
  #   }

  #   {start_date, now}
  # end

  defp _get_period(_) do
    now = DateTime.utc_now()
    start_date = now |> DateTime.add(-1 * 3600, :second)
    {start_date, now}
  end

  defp _get_expired_at(), do: DateTime.utc_now() |> DateTime.add(-@week_seconds, :second)
end
