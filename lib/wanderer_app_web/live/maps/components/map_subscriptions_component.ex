defmodule WandererAppWeb.Maps.MapSubscriptionsComponent do
  use WandererAppWeb, :live_component
  use LiveViewEvents

  require Logger

  alias BetterNumber, as: Number
  alias WandererApp.License.LicenseManager

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       is_adding_subscription?: false,
       map_subscriptions: [],
       selected_subscription: nil,
       subscription_periods: [
         {"1 Month", "1"},
         {"3 Months", "3"},
         {"6 Months", "6"},
         {"1 Year", "12"}
       ],
       error: nil
     )}
  end

  @impl true
  def update(%{map_id: map_id} = assigns, socket) do
    socket = handle_info_or_assign(socket, assigns)

    subscription_form = %{
      "plan" => "omega",
      "period" => "1",
      "characters_limit" => "50",
      "hubs_limit" => "20",
      "auto_renew?" => true
    }

    {:ok, map} = WandererApp.MapRepo.get(map_id)

    {:ok, estimated_price, discount} =
      WandererApp.Map.SubscriptionManager.estimate_price(subscription_form, false)

    {:ok, map_subscriptions} =
      WandererApp.Map.SubscriptionManager.get_map_subscriptions(map_id)

    socket =
      socket
      |> assign(assigns)
      |> assign(
        map: map,
        map_subscriptions: map_subscriptions,
        subscription_form: subscription_form |> to_form(),
        estimated_price: estimated_price,
        discount: discount
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("add_subscription", _, socket),
    do: {:noreply, socket |> assign(is_adding_subscription?: true)}

  @impl true
  def handle_event("edit-subscription", %{"id" => subscription_id} = _event, socket) do
    {:ok, selected_subscription} =
      subscription_id
      |> WandererApp.Api.MapSubscription.by_id()

    subscription_form = %{
      "plan" => "omega",
      "characters_limit" => "#{selected_subscription.characters_limit}",
      "hubs_limit" => "#{selected_subscription.hubs_limit}",
      "auto_renew?" => selected_subscription.auto_renew?
    }

    {:ok, additional_price, discount} =
      WandererApp.Map.SubscriptionManager.calc_additional_price(
        subscription_form,
        selected_subscription
      )

    {:noreply,
     socket
     |> assign(
       is_adding_subscription?: true,
       selected_subscription: selected_subscription,
       additional_price: additional_price,
       discount: discount,
       subscription_form: subscription_form |> to_form()
     )}
  end

  @impl true
  def handle_event(
        "cancel-subscription",
        %{"id" => subscription_id} = _event,
        %{assigns: %{map_id: map_id}} = socket
      ) do
    {:ok, _subscription} =
      subscription_id
      |> WandererApp.Api.MapSubscription.by_id!()
      |> WandererApp.Api.MapSubscription.cancel()

    {:ok, map_subscriptions} = WandererApp.Map.SubscriptionManager.get_map_subscriptions(map_id)

    Phoenix.PubSub.broadcast(
      WandererApp.PubSub,
      "maps:#{map_id}",
      :subscription_settings_updated
    )

    :telemetry.execute([:wanderer_app, :map, :subscription, :cancel], %{count: 1}, %{
      map_id: map_id
    })

    case WandererApp.License.LicenseManager.get_license_by_map_id(map_id) do
      {:ok, license} ->
        WandererApp.License.LicenseManager.invalidate_license(license.id)
        Logger.info("Cancelled license for map #{map_id}")

      {:error, reason} ->
        Logger.error("Failed to cancel license for map #{map_id}: #{inspect(reason)}")
    end

    notify_to(
      socket.assigns.notify_to,
      socket.assigns.event_name,
      {:flash, :info, "Subscription cancelled!"}
    )

    {:noreply,
     socket
     |> assign(is_adding_subscription?: false, map_subscriptions: map_subscriptions)}
  end

  @impl true
  def handle_event(
        "validate_subscription",
        params,
        %{assigns: %{selected_subscription: selected_subscription}} = socket
      ) do
    socket =
      case is_nil(selected_subscription) do
        true ->
          {:ok, estimated_price, discount} =
            WandererApp.Map.SubscriptionManager.estimate_price(params, false)

          socket
          |> assign(estimated_price: estimated_price, discount: discount)

        _ ->
          {:ok, additional_price, discount} =
            WandererApp.Map.SubscriptionManager.calc_additional_price(
              params,
              selected_subscription
            )

          socket |> assign(additional_price: additional_price, discount: discount)
      end

    {:noreply, assign(socket, subscription_form: params)}
  end

  @impl true
  def handle_event(
        "subscribe",
        %{
          "period" => period,
          "characters_limit" => characters_limit,
          "hubs_limit" => hubs_limit,
          "auto_renew?" => auto_renew?
        } = subscription_form,
        %{assigns: %{map_id: map_id, map: map, current_user: current_user}} = socket
      ) do
    period = period |> String.to_integer()

    {:ok, estimated_price, discount} =
      WandererApp.Map.SubscriptionManager.estimate_price(subscription_form, false)

    active_till =
      DateTime.utc_now()
      |> DateTime.to_date()
      |> Date.add(period * 30)
      |> WandererApp.Map.SubscriptionManager.convert_date_to_datetime()

    {:ok, map_balance} = WandererApp.Map.SubscriptionManager.get_balance(map)

    case map_balance >= estimated_price - discount do
      true ->
        {:ok, _t} =
          WandererApp.Api.MapTransaction.create(%{
            map_id: map_id,
            user_id: current_user.id,
            amount: estimated_price - discount,
            type: :out
          })

        {:ok, _sub} =
          WandererApp.Api.MapSubscription.create(%{
            map_id: map_id,
            plan: :omega,
            active_till: active_till,
            characters_limit: characters_limit |> String.to_integer(),
            hubs_limit: hubs_limit |> String.to_integer(),
            auto_renew?: auto_renew?
          })

        {:ok, map_subscriptions} =
          WandererApp.Map.SubscriptionManager.get_map_subscriptions(map_id)

        Phoenix.PubSub.broadcast(
          WandererApp.PubSub,
          "maps:#{map_id}",
          :subscription_settings_updated
        )

        :telemetry.execute([:wanderer_app, :map, :subscription, :new], %{count: 1}, %{
          map_id: map_id,
          amount: estimated_price - discount
        })

        # Automatically create a license for the map
        create_map_license(socket, map_id)

        notify_to(
          socket.assigns.notify_to,
          socket.assigns.event_name,
          {:flash, :info, "Subscription added!"}
        )

        {:noreply,
         socket
         |> assign(
           is_adding_subscription?: false,
           map_subscriptions: map_subscriptions
         )}

      _ ->
        notify_to(
          socket.assigns.notify_to,
          socket.assigns.event_name,
          {:flash, :error, "You have not enough ISK on Map Balance!"}
        )

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "update_subscription",
        %{
          "characters_limit" => characters_limit,
          "hubs_limit" => hubs_limit,
          "auto_renew?" => auto_renew?
        } = subscription_form,
        %{
          assigns: %{
            map_id: map_id,
            map: map,
            current_user: current_user,
            selected_subscription: selected_subscription
          }
        } = socket
      ) do
    {:ok, additional_price, discount} =
      WandererApp.Map.SubscriptionManager.calc_additional_price(
        subscription_form,
        selected_subscription
      )

    {:ok, map_balance} = WandererApp.Map.SubscriptionManager.get_balance(map)

    case map_balance >= additional_price - discount do
      true ->
        {:ok, _t} =
          WandererApp.Api.MapTransaction.create(%{
            map_id: map_id,
            user_id: current_user.id,
            amount: additional_price - discount,
            type: :out
          })

        {:ok, _} =
          selected_subscription
          |> WandererApp.Api.MapSubscription.update_characters_limit!(%{
            characters_limit: characters_limit |> String.to_integer()
          })
          |> WandererApp.Api.MapSubscription.update_hubs_limit!(%{
            hubs_limit: hubs_limit |> String.to_integer()
          })
          |> WandererApp.Api.MapSubscription.update_auto_renew(%{auto_renew?: auto_renew?})

        {:ok, map_subscriptions} =
          WandererApp.Map.SubscriptionManager.get_map_subscriptions(map_id)

        Phoenix.PubSub.broadcast(
          WandererApp.PubSub,
          "maps:#{map_id}",
          :subscription_settings_updated
        )

        :telemetry.execute([:wanderer_app, :map, :subscription, :update], %{count: 1}, %{
          map_id: map_id,
          amount: additional_price - discount
        })

        # Check if a license exists, if not create one, otherwise update its expiration
        # The License Manager service will verify the subscription is active
        case WandererApp.License.LicenseManager.get_license_by_map_id(map_id) do
          {:ok, _license} ->
            # License exists, update its expiration date
            case WandererApp.License.LicenseManager.update_license_expiration_from_subscription(
                   map_id
                 ) do
              {:ok, updated_license} ->
                Logger.info(
                  "Updated license expiration for map #{map_id} to #{updated_license.expire_at}"
                )

              {:error, "License not found"} ->
                create_map_license(socket, map_id)

              {:error, reason} ->
                Logger.error(
                  "Failed to update license expiration for map #{map_id}: #{inspect(reason)}"
                )

                notify_to(
                  socket.assigns.notify_to,
                  socket.assigns.event_name,
                  {:flash, :error, "Failed to update license expiration for map #{map_id}!"}
                )
            end

          {:error, :license_not_found} ->
            # No license found, create one
            create_map_license(socket, map_id)

          _ ->
            # Error occurred, do nothing
            :ok
        end

        notify_to(
          socket.assigns.notify_to,
          socket.assigns.event_name,
          {:flash, :info, "Subscription updated!"}
        )

        {:noreply,
         socket
         |> assign(
           is_adding_subscription?: false,
           selected_subscription: nil,
           map_subscriptions: map_subscriptions
         )}

      _ ->
        notify_to(
          socket.assigns.notify_to,
          socket.assigns.event_name,
          {:flash, :error, "You have not enough ISK on Map Balance!"}
        )

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_edit_subscription", _event, socket) do
    {:noreply, socket |> assign(is_adding_subscription?: false, selected_subscription: nil)}
  end

  defp create_map_license(socket, map_id) do
    # No license found, create one
    case WandererApp.License.LicenseManager.create_license_for_map(map_id) do
      {:ok, license} ->
        Logger.debug(fn ->
          "Automatically created license #{license.license_key} for map #{map_id} during subscription update"
        end)

        notify_to(
          socket.assigns.notify_to,
          socket.assigns.event_name,
          {:flash, :info, "Automatically created license for map"}
        )

        {:ok, license}

      {:error, reason} ->
        Logger.error(
          "Failed to create license for map #{map_id} during subscription update: #{inspect(reason)}"
        )

        notify_to(
          socket.assigns.notify_to,
          socket.assigns.event_name,
          {:flash, :error,
           "Failed to create license for map #{map_id} during subscription update: #{inspect(reason)}"}
        )

        {:error, reason}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="subscriptions-info">
      <div
        class="tooltip"
        data-tip={
          if @map_subscriptions |> Enum.at(0) |> Map.get(:status) == :active,
            do: "You can have only one active subscription plan",
            else: ""
        }
      >
        <.button
          :if={not @readonly && not @is_adding_subscription?}
          type="button"
          disabled={
            @map_subscriptions |> Enum.at(0) |> Map.get(:status) == :active &&
              @map_subscriptions |> Enum.at(0) |> Map.get(:plan) != :alpha
          }
          phx-click="add_subscription"
          phx-target={@myself}
        >
          Add subscription
        </.button>
      </div>
      <.table
        class="!max-h-[200px] !overflow-y-auto"
        empty_label="No active subscriptions, using alpha plan by default."
        id="active-subscriptions-tbl"
        rows={@map_subscriptions}
      >
        <:col :let={subscription} label="Subscription Plan">
          {subscription.plan}
        </:col>
        <:col :let={subscription} label="Status">
          {subscription.status}
        </:col>
        <:col :let={subscription} label="Characters Limit">
          {subscription.characters_limit}
        </:col>
        <:col :let={subscription} label="Hubs Limit">
          {subscription.hubs_limit}
        </:col>
        <:col :let={subscription} label="Active Till">
          <.local_time
            :if={subscription.active_till}
            id={"subscription-active-till-#{subscription.id}"}
            at={subscription.active_till}
          >
            {subscription.active_till}
          </.local_time>
        </:col>
        <:col :let={subscription} label="Auto Renew">
          {if subscription.auto_renew?, do: "Yes", else: "No"}
        </:col>
        <:action :let={subscription}>
          <div :if={not @readonly} class="tooltip tooltip-left" data-tip="Edit subscription">
            <button
              :if={subscription.status == :active && subscription.plan != :alpha}
              phx-click="edit-subscription"
              phx-value-id={subscription.id}
              phx-target={@myself}
            >
              <.icon name="hero-pencil-square-solid" class="w-4 h-4 hover:text-white" />
            </button>
          </div>
        </:action>
        <:action :let={subscription}>
          <div :if={not @readonly} class="tooltip tooltip-left" data-tip="Cancel subscription">
            <button
              :if={subscription.status == :active && subscription.plan != :alpha}
              phx-click="cancel-subscription"
              phx-value-id={subscription.id}
              phx-target={@myself}
              data={[confirm: "Please confirm to cancel subscription!"]}
            >
              <.icon name="hero-trash-solid" class="w-4 h-4 hover:text-white" />
            </button>
          </div>
        </:action>
      </.table>

      <.header
        :if={not @readonly && @is_adding_subscription?}
        class="bordered border-1 flex flex-col gap-4"
      >
        <div :if={is_nil(@selected_subscription)}>
          Add subscription
        </div>
        <div :if={not is_nil(@selected_subscription)}>
          Edit subscription
        </div>
        <.form
          :let={f}
          for={@subscription_form}
          phx-change="validate_subscription"
          phx-target={@myself}
          phx-submit={
            if is_nil(@selected_subscription),
              do: "subscribe",
              else: "update_subscription"
          }
        >
          <.input
            :if={is_nil(@selected_subscription)}
            type="select"
            field={f[:period]}
            class="select h-8 min-h-[10px] !pt-1 !pb-1 text-sm bg-neutral-900"
            label="Subscription period"
            options={@subscription_periods}
          />
          <.input
            field={f[:characters_limit]}
            label="Characters limit"
            show_value={true}
            type="range"
            min="50"
            max="5000"
            step="50"
            class="range range-xs"
          />
          <.input
            field={f[:hubs_limit]}
            label="Hubs limit"
            show_value={true}
            type="range"
            min="20"
            max="50"
            step="10"
            class="range range-xs"
          />
          <.input field={f[:auto_renew?]} label="Auto Renew" type="checkbox" />
          <div
            :if={is_nil(@selected_subscription)}
            class="stats w-full bg-primary text-primary-content mt-2"
          >
            <div class="stat">
              <div class="stat-figure text-primary">
                <.button type="submit">
                  Subscribe
                </.button>
              </div>
              <div class="flex gap-8">
                <div>
                  <div class="stat-title">Estimated price</div>
                  <div class="stat-value text-white">
                    ISK {(@estimated_price - @discount)
                    |> Number.to_human(units: ["", "K", "M", "B", "T", "P"])}
                  </div>
                </div>
                <div>
                  <div class="stat-title">Discount</div>
                  <div class="stat-value text-white relative">
                    ISK {@discount
                    |> Number.to_human(units: ["", "K", "M", "B", "T", "P"])}
                    <span class="absolute top-0 right-0 text-xs text-white discount" />
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div
            :if={not is_nil(@selected_subscription)}
            class="stats w-full bg-primary text-primary-content"
          >
            <div class="stat">
              <div class="stat-figure text-primary">
                <.button type="button" phx-click="cancel_edit_subscription" phx-target={@myself}>
                  Cancel
                </.button>
                <.button type="submit">
                  Update
                </.button>
              </div>
              <div class="flex gap-8">
                <div>
                  <div class="stat-title">Additional price</div>
                  <div class="stat-value text-white">
                    ISK {(@additional_price - @discount)
                    |> Number.to_human(units: ["", "K", "M", "B", "T", "P"])}
                  </div>
                </div>
                <div :if={@discount > 0}>
                  <div class="stat-title">Discount</div>
                  <div class="stat-value text-white relative">
                    ISK {@discount
                    |> Number.to_human(units: ["", "K", "M", "B", "T", "P"])}
                    <span class="absolute top-0 right-0 text-xs text-white discount" />
                  </div>
                </div>
              </div>
            </div>
          </div>
        </.form>
      </.header>
    </div>
    """
  end
end
