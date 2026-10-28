defmodule WandererAppWeb.Maps.MapSubscriptionsComponent do
  use WandererAppWeb, :live_component
  use LiveViewEvents

  require Logger

  alias BetterNumber, as: Number
  alias WandererApp.License.LicenseManager
  alias WandererApp.Map.SubscriptionManager

  @characters_limit_min 50
  @characters_limit_max 5_000
  @characters_limit_step 50
  @hubs_limit_min 20
  @hubs_limit_max 50
  @hubs_limit_step 10
  @subscription_periods [
    {"1 Month", "1"},
    {"3 Months", "3"},
    {"6 Months", "6"},
    {"1 Year", "12"}
  ]

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       is_adding_subscription?: false,
       map_subscriptions: [],
       selected_subscription: nil,
       promo_code: "",
       promo_code_valid?: false,
       promo_code_error: nil,
       subscription_periods: @subscription_periods,
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
      "auto_renew?" => true,
      "promo_code" => ""
    }

    {:ok, map} = WandererApp.MapRepo.get(map_id)

    {:ok, estimated_price, discount, _promo_valid?} =
      SubscriptionManager.estimate_price(subscription_form, false)

    {:ok, map_subscriptions} =
      SubscriptionManager.get_map_subscriptions(map_id)

    socket =
      socket
      |> assign(assigns)
      |> assign(
        map: map,
        map_subscriptions: map_subscriptions,
        subscription_form: subscription_form |> to_form(),
        estimated_price: estimated_price,
        discount: discount,
        promo_code: "",
        promo_code_valid?: false,
        promo_code_error: nil
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("add_subscription", _, socket),
    do: {:noreply, socket |> assign(is_adding_subscription?: true)}

  @impl true
  def handle_event(
        "edit-subscription",
        %{"id" => subscription_id} = _event,
        %{assigns: %{map_id: map_id}} = socket
      ) do
    case WandererAppWeb.HandlerAuth.authorize_subscription(subscription_id, map_id) do
      {:ok, selected_subscription} ->
        subscription_form = %{
          "plan" => "omega",
          "characters_limit" => "#{selected_subscription.characters_limit}",
          "hubs_limit" => "#{selected_subscription.hubs_limit}",
          "auto_renew?" => selected_subscription.auto_renew?,
          "promo_code" => ""
        }

        {:ok, additional_price, discount, _promo_valid?} =
          SubscriptionManager.calc_additional_price(
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
           promo_code: "",
           promo_code_valid?: false,
           promo_code_error: nil,
           subscription_form: subscription_form |> to_form()
         )}

      {:error, :not_found} ->
        notify_to(
          socket.assigns.notify_to,
          socket.assigns.event_name,
          {:flash, :error, "Subscription not found."}
        )

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "cancel-subscription",
        %{"id" => subscription_id} = _event,
        %{assigns: %{map_id: map_id}} = socket
      ) do
    with {:ok, subscription} <-
           WandererAppWeb.HandlerAuth.authorize_subscription(subscription_id, map_id),
         {:ok, _subscription} <- WandererApp.Api.MapSubscription.cancel(subscription) do
      {:ok, map_subscriptions} = SubscriptionManager.get_map_subscriptions(map_id)

      Phoenix.PubSub.broadcast(
        WandererApp.PubSub,
        "maps:#{map_id}",
        {:subscription_settings_updated, map_id}
      )

      :telemetry.execute([:wanderer_app, :map, :subscription, :cancel], %{count: 1}, %{
        map_id: map_id
      })

      case LicenseManager.get_license_by_map_id(map_id) do
        {:ok, license} ->
          LicenseManager.invalidate_license(license.id)
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
    else
      _ ->
        notify_to(
          socket.assigns.notify_to,
          socket.assigns.event_name,
          {:flash, :error, "Subscription not found."}
        )

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "validate_subscription",
        params,
        %{assigns: %{selected_subscription: selected_subscription}} = socket
      ) do
    promo_code = Map.get(params, "promo_code", "")

    # Validate promo code and set error message
    {promo_code_valid?, promo_code_error} =
      case WandererApp.Env.validate_promo_code(promo_code) do
        {:ok, _discount} -> {true, nil}
        {:error, :invalid_code} when promo_code != "" -> {false, "Invalid promo code"}
        _ -> {false, nil}
      end

    socket =
      case is_nil(selected_subscription) do
        true ->
          {:ok, estimated_price, discount, _valid?} =
            WandererApp.Map.SubscriptionManager.estimate_price(params, false)

          socket
          |> assign(
            estimated_price: estimated_price,
            discount: discount,
            promo_code: promo_code,
            promo_code_valid?: promo_code_valid?,
            promo_code_error: promo_code_error
          )

        _ ->
          {:ok, additional_price, discount, _valid?} =
            WandererApp.Map.SubscriptionManager.calc_additional_price(
              params,
              selected_subscription
            )

          socket
          |> assign(
            additional_price: additional_price,
            discount: discount,
            promo_code: promo_code,
            promo_code_valid?: promo_code_valid?,
            promo_code_error: promo_code_error
          )
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
    with {:ok, period} <- WandererAppWeb.HandlerAuth.parse_subscription_period(period),
         {:ok, characters_limit} <-
           WandererAppWeb.HandlerAuth.parse_characters_limit(characters_limit),
         {:ok, hubs_limit} <- WandererAppWeb.HandlerAuth.parse_hubs_limit(hubs_limit) do
      promo_code = Map.get(subscription_form, "promo_code", "")

      {:ok, estimated_price, discount, _promo_valid?} =
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
              characters_limit: characters_limit,
              hubs_limit: hubs_limit,
              auto_renew?: auto_renew?
            })

          {:ok, map_subscriptions} =
            WandererApp.Map.SubscriptionManager.get_map_subscriptions(map_id)

          Phoenix.PubSub.broadcast(
            WandererApp.PubSub,
            "maps:#{map_id}",
            {:subscription_settings_updated, map_id}
          )

          :telemetry.execute([:wanderer_app, :map, :subscription, :new], %{count: 1}, %{
            map_id: map_id,
            amount: estimated_price - discount,
            promo_code: if(promo_code != "", do: String.upcase(promo_code), else: nil)
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
    else
      {:error, message} ->
        notify_to(
          socket.assigns.notify_to,
          socket.assigns.event_name,
          {:flash, :error, message}
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
    with true <- selected_subscription.map_id == map_id,
         {:ok, characters_limit} <-
           WandererAppWeb.HandlerAuth.parse_characters_limit(characters_limit),
         {:ok, hubs_limit} <- WandererAppWeb.HandlerAuth.parse_hubs_limit(hubs_limit) do
      {:ok, additional_price, discount, _promo_valid?} =
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
              characters_limit: characters_limit
            })
            |> WandererApp.Api.MapSubscription.update_hubs_limit!(%{
              hubs_limit: hubs_limit
            })
            |> WandererApp.Api.MapSubscription.update_auto_renew(%{auto_renew?: auto_renew?})

          {:ok, map_subscriptions} =
            WandererApp.Map.SubscriptionManager.get_map_subscriptions(map_id)

          Phoenix.PubSub.broadcast(
            WandererApp.PubSub,
            "maps:#{map_id}",
            {:subscription_settings_updated, map_id}
          )

          :telemetry.execute([:wanderer_app, :map, :subscription, :update], %{count: 1}, %{
            map_id: map_id,
            amount: additional_price - discount
          })

          # Check if a license exists, if not create one, otherwise update its expiration
          # The License Manager service will verify the subscription is active
          case LicenseManager.get_license_by_map_id(map_id) do
            {:ok, _license} ->
              # License exists, update its expiration date
              case LicenseManager.update_license_expiration_from_subscription(map_id) do
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
    else
      {:error, message} ->
        notify_to(
          socket.assigns.notify_to,
          socket.assigns.event_name,
          {:flash, :error, message}
        )

        {:noreply, socket}

      _ ->
        notify_to(
          socket.assigns.notify_to,
          socket.assigns.event_name,
          {:flash, :error, "Subscription not found."}
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
    case LicenseManager.create_license_for_map(map_id) do
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
    assigns =
      assign(assigns,
        characters_limit_min: @characters_limit_min,
        characters_limit_max: @characters_limit_max,
        characters_limit_step: @characters_limit_step,
        hubs_limit_min: @hubs_limit_min,
        hubs_limit_max: @hubs_limit_max,
        hubs_limit_step: @hubs_limit_step
      )

    ~H"""
    <div class="subscriptions-info flex h-full min-h-0 flex-col">
      <div
        class="mb-3 w-fit shrink-0"
        title={
          if @map_subscriptions |> Enum.at(0) |> Map.get(:status) == :active,
            do: "You can have only one active subscription plan",
            else: nil
        }
      >
        <.button
          :if={not @readonly}
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

      <div class="custom-scrollbar min-h-0 flex-1 overflow-x-hidden overflow-y-auto pr-2">
        <table class="w-full border-collapse text-left [&_td]:px-1 [&_th]:px-1">
          <colgroup>
            <col class="w-20" />
            <col class="w-20" />
            <col class="w-24" />
            <col class="w-20" />
            <col class="w-40" />
            <col class="w-24" />
            <col class="w-16" />
          </colgroup>
          <thead class="sticky top-0 z-10 bg-[var(--surface-card)]">
            <tr class="border-b border-neutral-700 text-xs uppercase tracking-wide text-neutral-500/85">
              <th class="h-8 px-1 font-normal">Plan</th>
              <th class="h-8 px-1 font-normal">Status</th>
              <th class="h-8 px-1 font-normal">Characters</th>
              <th class="h-8 px-1 font-normal">Hubs</th>
              <th class="h-8 px-1 font-normal">Expires</th>
              <th class="h-8 px-1 font-normal">Auto-renew</th>
              <th class="h-8 px-1 text-right font-normal">Actions</th>
            </tr>
          </thead>
          <tbody id="active-subscriptions-tbl">
            <tr
              :for={subscription <- @map_subscriptions}
              class={[
                "border-b border-neutral-700/80 transition-colors",
                classes(
                  "bg-green-950/15 hover:bg-green-950/25":
                    subscription.status == :active && subscription.plan != :alpha,
                  "bg-red-950/15 opacity-70 hover:bg-red-950/25": subscription.status == :cancelled,
                  "hover:bg-neutral-800/60":
                    subscription.plan == :alpha or
                      subscription.status not in [:active, :cancelled]
                )
              ]}
            >
              <td class="h-9 whitespace-nowrap !px-3 align-middle text-sm capitalize text-neutral-100/85">
                {subscription.plan}
              </td>
              <td class={[
                "h-9 whitespace-nowrap px-1 align-middle text-sm capitalize",
                classes(
                  "text-green-300/85": subscription.status == :active && subscription.plan != :alpha,
                  "text-neutral-400/85": subscription.status != :active or subscription.plan == :alpha
                )
              ]}>
                {subscription.status}
              </td>
              <td class="h-9 whitespace-nowrap px-1 align-middle text-sm text-neutral-300/85">
                {subscription.characters_limit}
              </td>
              <td class="h-9 whitespace-nowrap px-1 align-middle text-sm text-neutral-300/85">
                {subscription.hubs_limit}
              </td>
              <td class="h-9 whitespace-nowrap px-1 align-middle text-sm text-neutral-300/85">
                <.local_time
                  :if={subscription.active_till}
                  id={"subscription-active-till-#{subscription.id}"}
                  at={subscription.active_till}
                >
                  {subscription.active_till}
                </.local_time>
                <span :if={is_nil(subscription.active_till)} class="text-neutral-600/85">—</span>
              </td>
              <td class="h-9 whitespace-nowrap px-1 align-middle text-sm text-neutral-300/85">
                {if subscription.auto_renew?, do: "Yes", else: "No"}
              </td>
              <td class="h-9 px-1 align-middle">
                <div
                  :if={
                    not @readonly && subscription.status == :active &&
                      subscription.plan != :alpha
                  }
                  class="flex min-h-9 items-center justify-end gap-2 px-2"
                >
                  <button
                    type="button"
                    class="text-neutral-400/85 transition-colors hover:text-sky-400"
                    title="Edit subscription"
                    aria-label="Edit subscription"
                    phx-click="edit-subscription"
                    phx-value-id={subscription.id}
                    phx-target={@myself}
                  >
                    <.icon name="hero-pencil-square" class="size-4" />
                  </button>
                  <button
                    type="button"
                    class="text-neutral-400/85 transition-colors hover:text-rose-400"
                    title="Cancel subscription"
                    aria-label="Cancel subscription"
                    phx-click="cancel-subscription"
                    phx-value-id={subscription.id}
                    phx-target={@myself}
                    data={[confirm: "Please confirm to cancel subscription!"]}
                  >
                    <.icon name="hero-trash" class="size-4" />
                  </button>
                </div>
              </td>
            </tr>
            <tr :if={@map_subscriptions == []}>
              <td colspan="7" class="h-28 text-center text-sm text-neutral-500/85">
                No subscriptions found
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <.modal
        :if={not @readonly && @is_adding_subscription?}
        id={"subscription-form-modal-#{@map_id}"}
        title={if is_nil(@selected_subscription), do: "Add subscription", else: "Edit subscription"}
        class="!w-[760px] [&>.p-dialog-content]:!px-7 [&>.p-dialog-content]:!py-5 [&>.p-dialog-header]:!px-7 [&>.p-dialog-header]:!py-2 [&>.p-dialog-header>.p-dialog-header-close]:relative [&>.p-dialog-header>.p-dialog-header-close]:-right-5"
        show
        on_cancel={JS.push("cancel_edit_subscription", target: @myself)}
      >
        <.form
          :let={f}
          for={@subscription_form}
          phx-change="validate_subscription"
          phx-target={@myself}
          class="flex flex-col gap-2 [&>.form-control]:!mt-0"
          phx-submit={
            if is_nil(@selected_subscription),
              do: "subscribe",
              else: "update_subscription"
          }
        >
          <WandererAppWeb.Maps.MapSettings.SettingsSelect.select
            :if={is_nil(@selected_subscription)}
            field={f[:period]}
            label="Subscription period"
            options={@subscription_periods}
          />
          <.input
            field={f[:characters_limit]}
            label="Characters limit"
            show_value={true}
            type="range"
            min={@characters_limit_min}
            max={@characters_limit_max}
            step={@characters_limit_step}
            class="subscriptionRange"
            style={
              "--subscription-range-progress: #{range_progress(f[:characters_limit].value, @characters_limit_min, @characters_limit_max)}%"
            }
          />
          <.input
            field={f[:hubs_limit]}
            label="Hubs limit"
            show_value={true}
            type="range"
            min={@hubs_limit_min}
            max={@hubs_limit_max}
            step={@hubs_limit_step}
            class="subscriptionRange"
            style={
              "--subscription-range-progress: #{range_progress(f[:hubs_limit].value, @hubs_limit_min, @hubs_limit_max)}%"
            }
          />
          <.input field={f[:auto_renew?]} label="Auto Renew" type="checkbox" />
          <div :if={is_nil(@selected_subscription)} class="[&>label.form-control>.label]:hidden">
            <.input
              field={f[:promo_code]}
              label="Promo Code (optional)"
              type="text"
              placeholder="Enter promo code"
            />
            <div class="mt-0.5 min-h-4 text-xs leading-4">
              <p :if={@promo_code_error} class="text-rose-500">{@promo_code_error}</p>
              <p :if={@promo_code_valid?} class="text-green-500">✓ Promo code applied!</p>
            </div>
          </div>
          <div
            :if={is_nil(@selected_subscription)}
            class="stats my-4 w-full overflow-hidden rounded-sm border border-neutral-700/80 bg-gradient-to-r from-neutral-800/90 via-stone-900 to-orange-950/20 text-neutral-100 shadow-none"
          >
            <div class="stat">
              <div class="stat-figure text-primary">
                <.button type="submit">
                  Subscribe
                </.button>
              </div>
              <div class="flex gap-8">
                <div>
                  <div class="stat-title text-stone-400">Estimated price</div>
                  <div class="stat-value text-stone-100">
                    ISK {(@estimated_price - @discount)
                    |> Number.to_human(units: ["", "K", "M", "B", "T", "P"])}
                  </div>
                </div>
                <div>
                  <div class="stat-title text-stone-400">
                    Discount
                    <span :if={@promo_code_valid?} class="text-xs text-green-400 ml-1">
                      (incl. promo)
                    </span>
                  </div>
                  <div class="stat-value relative text-stone-100">
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
            class="stats my-4 w-full overflow-hidden rounded-sm border border-neutral-700/80 bg-gradient-to-r from-neutral-800/90 via-stone-900 to-orange-950/20 text-neutral-100 shadow-none"
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
                  <div class="stat-title text-stone-400">Additional price</div>
                  <div class="stat-value text-stone-100">
                    ISK {(@additional_price - @discount)
                    |> Number.to_human(units: ["", "K", "M", "B", "T", "P"])}
                  </div>
                </div>
                <div :if={@discount > 0}>
                  <div class="stat-title text-stone-400">Discount</div>
                  <div class="stat-value relative text-stone-100">
                    ISK {@discount
                    |> Number.to_human(units: ["", "K", "M", "B", "T", "P"])}
                    <span class="absolute top-0 right-0 text-xs text-white discount" />
                  </div>
                </div>
              </div>
            </div>
          </div>
        </.form>
      </.modal>
    </div>
    """
  end

  defp range_progress(value, min, max) do
    value =
      case Integer.parse(to_string(value)) do
        {parsed, _remainder} -> parsed
        :error -> min
      end

    value
    |> max(min)
    |> min(max)
    |> Kernel.-(min)
    |> Kernel./(max - min)
    |> Kernel.*(100)
    |> Float.round(2)
  end
end
