defmodule WandererAppWeb.MapAuditLive do
  use WandererAppWeb, :live_view

  require Logger

  alias WandererAppWeb.UserActivity

  @active_subscription_periods ["2M", "3M"]

  def mount(
        %{"slug" => map_slug, "period" => period, "activity" => activity} = _params,
        _session,
        %{assigns: %{current_user: current_user}} = socket
      ) do
    WandererApp.Maps.check_user_can_delete_map(map_slug, current_user)
    |> case do
      {:ok,
       %{
         id: map_id,
         name: map_name
       } = _map} ->
        {:ok, is_subscription_active} = map_id |> WandererApp.Map.is_subscription_active?()

        {:ok,
         socket
         |> assign(
           map_id: map_id,
           map_name: map_name,
           map_slug: map_slug,
           map_subscription_active: is_subscription_active,
           activity: activity,
           can_undo_types: [:systems_removed],
           period: period || "1H",
           page: 1,
           per_page: 25,
           end_of_stream?: false
         )
         |> stream(:activity, [])}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "You don't have an access.")
         |> push_navigate(to: ~p"/maps")}
    end
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(user_id: nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    apply_action(socket, socket.assigns.live_action, params)
  end

  @impl true
  def handle_info(
        _event,
        socket
      ) do
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "set_period",
        %{"period" => period},
        %{assigns: %{map_slug: map_slug, activity: activity}} = socket
      ) do
    {:noreply,
     socket
     |> push_navigate(to: ~p"/#{map_slug}/audit?period=#{period}&activity=#{activity}")}
  end

  def handle_event("update_filters", %{"activity" => activity}, socket) do
    %{period: period, map_slug: map_slug} =
      socket.assigns

    {:noreply,
     socket
     |> push_navigate(to: ~p"/#{map_slug}/audit?period=#{period}&activity=#{activity}")}
  end

  def handle_event(
        "undo",
        %{"event-data" => event_data, "event-type" => "systems_removed"},
        %{assigns: %{map_id: map_id, current_user: current_user}} = socket
      ) do
    {:ok, %{"solar_system_ids" => solar_system_ids}} = Jason.decode(event_data)

    solar_system_ids
    |> Enum.each(fn solar_system_id ->
      WandererApp.Map.Server.add_system(
        map_id,
        %{
          solar_system_id: solar_system_id,
          coordinates: nil,
          use_old_coordinates: true
        },
        current_user.id,
        nil
      )
    end)

    {:noreply, socket |> put_flash(:info, "Systems restored!")}
  end

  @impl true
  def handle_event("noop", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event(event, body, socket) do
    Logger.warning(fn -> "unhandled event: #{event} #{inspect(body)}" end)
    {:noreply, socket}
  end

  defp apply_action(socket, :index, params) do
    socket
    |> assign(:active_page, :audit)
    |> assign(:page_title, "Map - Audit")
    |> assign(:form, to_form(%{"activity" => socket.assigns.activity}))
    |> assign(:activities, [
      {"All Events", :all},
      {"System Added", :system_added},
      {"System Updated", :system_updated},
      {"System(s) Removed", :systems_removed},
      {"Hub Added", :hub_added},
      {"Hub Removed", :hub_removed},
      {"ACL Added", :map_acl_added},
      {"ACL Removed", :map_acl_removed},
      {"Connection Added", :map_connection_added},
      {"Connection Updated", :map_connection_updated},
      {"Connection Removed", :map_connection_removed},
      {"Rally Point Added", :map_rally_added},
      {"Rally Point Cancelled", :map_rally_cancelled},
      {"Signatures Added", :signatures_added},
      {"Signatures Removed", :signatures_removed}
    ])
    |> list_activity(params)
  end

  defp list_activity(socket, params, opts \\ []) do
    %{
      activity: activity,
      map_id: map_id,
      map_slug: map_slug,
      map_subscription_active: map_subscription_active,
      period: period
    } =
      socket.assigns

    query = WandererApp.Map.Audit.get_map_activity_query(map_id, period, activity)

    AshPagify.validate_and_run(query, params, opts)
    |> case do
      {:ok, {activity, meta}} ->
        {:noreply, socket |> assign(:meta, meta) |> stream(:activity, activity, reset: true)}

      {:error, meta} ->
        valid_path = AshPagify.Components.build_path(~p"/#{map_slug}/audit", meta.params)
        {:noreply, socket |> push_navigate(to: valid_path)}
    end
  end

  defp get_valid_period(period, true), do: period

  defp get_valid_period(period, _map_subscription_active) do
    if period in @active_subscription_periods do
      "1H"
    else
      period
    end
  end
end
