defmodule WandererAppWeb.Maps.MapBalanceComponent do
  use WandererAppWeb, :live_component
  use LiveViewEvents

  require Logger

  alias BetterNumber, as: Number
  alias WandererApp.License.LicenseManager

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       is_topping_up?: false,
       error: nil
     )}
  end

  @impl true
  def update(%{map_id: map_id, current_user: current_user} = assigns, socket) do
    socket = handle_info_or_assign(socket, assigns)

    {:ok, map} = WandererApp.MapRepo.get(map_id)

    {:ok, map_balance} = WandererApp.Map.SubscriptionManager.get_balance(map)

    {:ok, user_balance} =
      current_user.id
      |> WandererApp.User.load()
      |> WandererApp.User.get_balance()

    socket =
      socket
      |> assign(assigns)
      |> assign(
        map_id: map_id,
        map: map,
        map_balance: map_balance,
        user_balance: user_balance,
        topup_form: %{} |> to_form()
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("show_topup", _, socket),
    do:
      {:noreply,
       socket
       |> assign(
         :amounts,
         [
           {"50M", 50_000_000},
           {"100M", 100_000_000},
           {"250M", 250_000_000},
           {"500M", 500_000_000},
           {"1B", 1_000_000_000},
           {"2.5B", 2_500_000_000},
           {"5B", 5_000_000_000},
           {"10B", 10_000_000_000},
           {"ALL", nil}
         ]
       )
       |> assign(is_topping_up?: true)}

  @impl true
  def handle_event("hide_topup", _, socket),
    do: {:noreply, socket |> assign(is_topping_up?: false)}

  @impl true
  def handle_event(
        "topup",
        %{"amount" => amount} = _event,
        %{assigns: %{current_user: current_user, map: map, map_id: map_id}} = socket
      ) do
    user =
      current_user.id
      |> WandererApp.User.load()

    {:ok, user_balance} =
      user
      |> WandererApp.User.get_balance()

    amount =
      if amount == "" do
        user_balance
      else
        amount |> Decimal.new() |> Decimal.to_float()
      end

    case amount <= user_balance do
      true ->
        {:ok, _t} =
          WandererApp.Api.MapTransaction.create(%{
            map_id: map_id,
            user_id: current_user.id,
            amount: amount,
            type: :in
          })

        {:ok, user} =
          user
          |> WandererApp.Api.User.update_balance(%{
            balance: (user_balance || 0.0) - amount
          })

        {:ok, user_balance} =
          current_user.id
          |> WandererApp.User.load()
          |> WandererApp.User.get_balance()

        {:ok, map_balance} = WandererApp.Map.SubscriptionManager.get_balance(map)

        {:noreply,
         socket
         |> assign(is_topping_up?: false, map_balance: map_balance, user_balance: user_balance)}

      _ ->
        notify_to(
          socket.assigns.notify_to,
          socket.assigns.event_name,
          {:flash, :error, "You don't have enough ISK on your account balance!"}
        )

        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="map-balance-info">
      <div class="stats w-full bg-primary text-primary-content">
        <div class="stat">
          <div class="stat-title">Account balance</div>
          <div class="stat-value text-white">
            ISK {@user_balance
            |> Number.to_human(units: ["", "K", "M", "B", "T", "P"])}
          </div>
          <div class="stat-actions text-end"></div>
        </div>
        <div class="stat">
          <div class="stat-figure text-primary">
            <.button
              :if={not @is_topping_up?}
              class="mt-2"
              type="button"
              phx-click="show_topup"
              phx-target={@myself}
            >
              Top Up
            </.button>
          </div>
          <div class="stat-title">Map balance</div>
          <div class="stat-value text-white">
            ISK {@map_balance
            |> Number.to_human(units: ["", "K", "M", "B", "T", "P"])}
          </div>
          <div class="stat-actions text-end"></div>
        </div>
      </div>

      <div class="w-full bg-primary">
        <h3 class="mt-2 text-2xl font-semibold mb-4 text-white">
          How to top up map balance?
        </h3>
        <ol class="list-decimal list-inside mb-4">
          <li class="mb-2">
            <strong>Top Up your account balance:</strong>
            Click on 'Deposit ISK' button on <a href={~p"/profile"} class="text-purple-400">user profile page</a>.
          </li>
          <li class="mb-2">
            <strong>Wait for account balance updated:</strong>
            Check transactions section on
            <a href={~p"/profile"} class="text-purple-400">user profile page</a>
          </li>
          <li class="mb-2">
            <strong>Use 'Top Up' button:</strong>
            Click on the 'Top Up' button & select the amount you wish to transfer to the map balance.
          </li>
          <li class="mb-2">
            <strong>Accept the transfer:</strong>
            Finish the transaction by clicking on the 'Top Up' button.
          </li>
        </ol>
      </div>

      <.form
        :let={f}
        :if={@is_topping_up?}
        for={@topup_form}
        class="mt-2"
        phx-submit="topup"
        phx-target={@myself}
      >
        <.input
          type="select"
          field={f[:amount]}
          class="select h-8 min-h-[10px] !pt-1 !pb-1 text-sm bg-neutral-900"
          label="Topup amount"
          placeholder="Select topup amount"
          options={@amounts}
        />
        <div class="modal-action">
          <.button class="mt-2" type="button" phx-click="hide_topup" phx-target={@myself}>
            Cancel
          </.button>
          <.button class="mt-2" type="submit">
            Top Up
          </.button>
        </div>
      </.form>
    </div>
    """
  end
end
