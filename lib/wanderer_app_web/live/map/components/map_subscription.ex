defmodule WandererAppWeb.MapSubscription do
  use WandererAppWeb, :live_component

  use LiveViewEvents

  alias BetterNumber, as: Number

  @impl true
  def mount(socket) do
    socket =
      socket
      |> assign(title: "")
      |> assign(status: :alpha)
      |> assign(balance: 0)

    {:ok, socket}
  end

  @impl true
  def update(
        %{
          current_user: current_user,
          map_slug: map_slug
        } = assigns,
        socket
      ) do
    socket = handle_info_or_assign(socket, assigns)

    with {:ok, %{id: map_id} = map} <-
           WandererApp.MapRepo.get_by_slug_with_permissions(map_slug, current_user),
         {:ok, %{plan: plan} = subscription} <-
           WandererApp.Map.SubscriptionManager.get_active_map_subscription(map_id),
         {:ok, map_balance} <- WandererApp.Map.SubscriptionManager.get_balance(map) do
      {:ok,
       socket
       |> assign(status: plan)
       |> assign(title: get_title(subscription))
       |> assign(balance: map_balance)}
    else
      _error ->
        {:ok, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id={@id}
      class="cursor-pointer flex gap-1 px-1 rounded-md items-center justify-center transition-all hover:bg-stone-700/90"
      title={@title}
      phx-click="show_topup"
      phx-target={@myself}
    >
      <div>
        <span class="text-md">
          <%= case @status do %>
            <% :alpha -> %>
              &alpha;
            <% :omega -> %>
              &Omega;
          <% end %>
        </span>
      </div>
      <div class="ml-auto text-right">
        <span class="text-md font-semibold text-green-600">
          ISK {@balance
          |> Number.to_human(units: ["", "K", "M", "B", "T", "P"])}
        </span>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("show_topup", _params, socket) do
    notify_to(socket.assigns.notify_to, socket.assigns.event_name, socket.assigns.map_slug)

    {:noreply, socket}
  end

  defp get_title(%{plan: plan, auto_renew?: auto_renew?, active_till: active_till} = subscription) do
    if plan != :alpha do
      "Active subscription: omega \nActive till: #{Calendar.strftime(active_till, "%m/%d/%Y")} \nAuto renew: #{auto_renew?}"
    else
      "Active subscription: alpha"
    end
  end
end
