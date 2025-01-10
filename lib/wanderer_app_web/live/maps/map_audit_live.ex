defmodule WandererAppWeb.MapAuditLive do
  use WandererAppWeb, :live_view

  require Logger

  alias WandererAppWeb.UserActivity

  @active_subscription_periods ["2M", "3M"]

  def mount(
        %{"slug" => map_slug, "period" => period, "activity" => activity} = _params,
        _session,
        socket
      ) do
    current_user = socket.assigns.current_user

    map_slug
    |> WandererApp.Api.Map.get_map_by_slug()
    |> Ash.load([:acls, :user_permissions], actor: current_user)
    |> case do
      {:ok,
       %{
         id: map_id,
         user_permissions: user_permissions,
         name: map_name,
         owner_id: owner_id
       } = _map} ->
        user_permissions =
          WandererApp.Permissions.get_map_permissions(
            user_permissions,
            owner_id,
            current_user.characters |> Enum.map(& &1.id)
          )

        case user_permissions.delete_map do
          true ->
            {:ok,
             socket
             |> assign(
               map_id: map_id,
               map_name: map_name,
               map_slug: map_slug,
               map_subscription_active: WandererApp.Map.is_subscription_active?(map_id),
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

      _ ->
        {:ok, socket}
    end
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(user_id: nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
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

  def handle_event("top", _, socket) do
    {:noreply, socket |> load_activity(1)}
  end

  def handle_event("next-page", _, socket) do
    {:noreply, load_activity(socket, socket.assigns.page + 1)}
  end

  def handle_event("prev-page", %{"_overran" => true}, socket) do
    {:noreply, load_activity(socket, 1)}
  end

  def handle_event("prev-page", _, socket) do
    if socket.assigns.page > 1 do
      {:noreply, load_activity(socket, socket.assigns.page - 1)}
    else
      {:noreply, socket}
    end
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

  defp apply_action(socket, :index, _params) do
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
      {"Connection Removed", :map_connection_removed}
    ])
    |> load_activity(1)
  end

  defp load_activity(socket, new_page) when new_page >= 1 do
    %{
      activity: activity,
      per_page: per_page,
      page: cur_page,
      map_id: map_id,
      map_subscription_active: map_subscription_active,
      period: period
    } =
      socket.assigns

    period = get_valid_period(period, map_subscription_active)

    with {:ok, page} <-
           WandererApp.Map.Audit.get_activity_page(map_id, new_page, per_page, period, activity) do
      {activity, at, limit} =
        if new_page >= cur_page do
          {page.results, -1, per_page * 3 * -1}
        else
          {Enum.reverse(page.results), 0, per_page * 3}
        end

      case activity do
        [] ->
          socket
          |> assign(end_of_stream?: at == -1)
          |> stream(:activity, [])

        [_ | _] = _ ->
          socket
          |> assign(end_of_stream?: false)
          |> assign(page: if(activity == [], do: cur_page, else: new_page))
          |> stream(:activity, activity, at: at, limit: limit)
      end
    else
      _ -> socket
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
