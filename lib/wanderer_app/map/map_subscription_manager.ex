defmodule WandererApp.Map.SubscriptionManager do
  @moduledoc """
  Manager map subscription plans
  """

  require Logger

  @logger Application.compile_env(:wanderer_app, :logger)
  @pubsub_client Application.compile_env(:wanderer_app, :pubsub_client)

  def get_default_subscription_plan() do
    %{plans: plans} = WandererApp.Env.subscription_settings()

    %{
      characters_limit: plan_characters_limit,
      hubs_limit: plan_hubs_limit
    } = plans |> Enum.find(fn p -> p.id == "alpha" end)

    %{
      id: "alpha",
      status: :active,
      plan: :alpha,
      characters_limit: plan_characters_limit,
      hubs_limit: plan_hubs_limit,
      auto_renew?: false,
      active_till: nil
    }
  end

  def get_map_subscriptions(map_id) do
    case WandererApp.MapSubscriptionRepo.get_all_by_map(map_id) do
      {:ok, subscriptions} when subscriptions != [] ->
        case subscriptions |> Enum.any?(fn s -> s.status == :active end) do
          true ->
            {:ok, subscriptions}

          _ ->
            {:ok, [get_default_subscription_plan() | subscriptions] |> List.flatten()}
        end

      _ ->
        {:ok, [get_default_subscription_plan()]}
    end
  end

  def get_active_map_subscription(map_id) do
    case WandererApp.MapSubscriptionRepo.get_active_by_map(map_id) do
      {:ok, [subscription]} when not is_nil(subscription) ->
        {:ok, subscription}

      _ ->
        {:ok, get_default_subscription_plan()}
    end
  end

  def process() do
    Logger.info("Start map subscriptions processing...")

    {:ok, active_map_subscriptions} =
      WandererApp.MapSubscriptionRepo.get_all_active()

    tasks =
      for map_subscription <- active_map_subscriptions do
        Task.async(fn ->
          map_subscription |> process_subscription()
        end)
      end

    Task.await_many(tasks)
    @logger.info(fn -> "All subscriptions processed" end)

    :ok
  end

  def estimate_price(
        %{
          "period" => period,
          "characters_limit" => characters_limit,
          "hubs_limit" => hubs_limit
        },
        renew?
      )
      when is_binary(characters_limit),
      do:
        estimate_price(
          %{
            period: period |> String.to_integer(),
            characters_limit: characters_limit |> String.to_integer(),
            hubs_limit: hubs_limit |> String.to_integer()
          },
          renew?
        )

  def estimate_price(
        %{characters_limit: characters_limit, hubs_limit: hubs_limit} = params,
        renew?
      ) do
    %{
      plans: plans,
      extra_characters_50: extra_characters_50,
      extra_hubs_10: extra_hubs_10
    } = WandererApp.Env.subscription_settings()

    %{
      characters_limit: plan_characters_limit,
      hubs_limit: plan_hubs_limit,
      base_price: plan_base_price
    } = current_plan = plans |> Enum.find(fn p -> p.id == "omega" end)

    estimated_price = plan_base_price

    estimated_price =
      case characters_limit > plan_characters_limit do
        true ->
          estimated_price +
            (characters_limit - plan_characters_limit) / 50 * extra_characters_50

        _ ->
          estimated_price
      end

    estimated_price =
      case hubs_limit > plan_hubs_limit do
        true ->
          estimated_price + (hubs_limit - plan_hubs_limit) / 10 * extra_hubs_10

        _ ->
          estimated_price
      end

    period =
      case renew? do
        true -> 1
        false -> params[:period]
      end

    total_price = estimated_price * period

    {:ok, discount} =
      calc_discount(
        period,
        total_price,
        current_plan,
        renew?
      )

    {:ok, total_price, discount}
  end

  def calc_additional_price(
        %{"characters_limit" => characters_limit, "hubs_limit" => hubs_limit},
        selected_subscription
      ) do
    %{
      plans: plans,
      extra_characters_50: extra_characters_50,
      extra_hubs_10: extra_hubs_10
    } = WandererApp.Env.subscription_settings()

    current_plan = plans |> Enum.find(fn p -> p.id == "omega" end)

    additional_price = 0

    characters_limit = characters_limit |> String.to_integer()
    hubs_limit = hubs_limit |> String.to_integer()
    sub_characters_limit = selected_subscription.characters_limit
    sub_hubs_limit = selected_subscription.hubs_limit

    additional_price =
      case characters_limit > sub_characters_limit do
        true ->
          additional_price +
            (characters_limit - sub_characters_limit) / 50 * extra_characters_50

        _ ->
          additional_price
      end

    additional_price =
      case hubs_limit > sub_hubs_limit do
        true ->
          additional_price + (hubs_limit - sub_hubs_limit) / 10 * extra_hubs_10

        _ ->
          additional_price
      end

    period = get_active_months(selected_subscription)

    total_price = additional_price * period

    {:ok, discount} =
      calc_discount(
        period,
        total_price,
        current_plan,
        false
      )

    {:ok, total_price, discount}
  end

  defp get_active_months(subscription) do
    months =
      subscription.active_till
      |> Timex.shift(days: 5)
      |> Timex.diff(Timex.now(), :months)

    if months == 0 do
      1
    else
      months
    end
  end

  defp calc_discount(
         period,
         _total_price,
         _current_plan,
         renew?
       )
       when period <= 1 or renew?,
       do: {:ok, 0.0}

  defp calc_discount(
         period,
         total_price,
         %{
           month_12_discount: month_12_discount
         },
         _renew?
       )
       when period >= 12,
       do: {:ok, round(total_price * month_12_discount)}

  defp calc_discount(
         period,
         total_price,
         %{
           month_6_discount: month_6_discount
         },
         _renew?
       )
       when period >= 6,
       do: {:ok, round(total_price * month_6_discount)}

  defp calc_discount(
         period,
         total_price,
         %{
           month_3_discount: month_3_discount
         },
         _renew?
       )
       when period >= 3,
       do: {:ok, round(total_price * month_3_discount)}

  def get_balance(map) do
    map
    |> WandererApp.MapRepo.load_relationships([
      :transactions_amount_in,
      :transactions_amount_out
    ])
    |> case do
      {:ok,
       %{
         transactions_amount_in: transactions_amount_in,
         transactions_amount_out: transactions_amount_out
       }} ->
        {:ok, transactions_amount_in - transactions_amount_out}

      _ ->
        @logger.error("Error getting balance for map #{map.id}")
        {:ok, 0}
    end
  end

  def convert_date_to_datetime(%DateTime{} = date), do: date

  def convert_date_to_datetime(%Date{} = date) do
    date
    |> Date.to_gregorian_days()
    |> Kernel.*(86400)
    |> Kernel.+(86399)
    |> DateTime.from_gregorian_seconds()
  end

  defp process_subscription(subscription) when is_map(subscription) do
    subscription
    |> is_expired()
    |> case do
      true ->
        renew_subscription(subscription)

      _ ->
        :ok
    end
  end

  defp is_expired(subscription) when is_map(subscription),
    do: DateTime.compare(DateTime.utc_now(), subscription.active_till) == :gt

  defp renew_subscription(%{auto_renew?: true} = subscription) when is_map(subscription) do
    with {:ok, %{map: map}} <-
           subscription |> WandererApp.MapSubscriptionRepo.load_relationships([:map]),
         {:ok, estimated_price, discount} <- estimate_price(subscription, true),
         {:ok, map_balance} <- get_balance(map) do
      case map_balance >= estimated_price do
        true ->
          {:ok, _t} =
            WandererApp.MapTransactionRepo.create(%{
              map_id: map.id,
              user_id: nil,
              amount: estimated_price - discount,
              type: :out
            })

          active_till =
            DateTime.utc_now()
            |> DateTime.to_date()
            |> Date.add(30)
            |> convert_date_to_datetime()

          {:ok, _} =
            subscription
            |> WandererApp.MapSubscriptionRepo.update_active_till(active_till)

          @pubsub_client.broadcast(
            WandererApp.PubSub,
            "maps:#{map.id}",
            :subscription_settings_updated
          )

          :telemetry.execute([:wanderer_app, :map, :subscription, :renew], %{count: 1}, %{
            map_id: map.id,
            amount: estimated_price - discount
          })

          # Check if a license already exists, if not create one
          case WandererApp.License.LicenseManager.get_license_by_map_id(map.id) do
            {:error, :license_not_found} ->
              # No license found, create one
              # The License Manager service will verify the subscription is active
              case WandererApp.License.LicenseManager.create_license_for_map(map.id) do
                {:ok, license} ->
                  Logger.debug(fn ->
                    "Automatically created license #{license.license_key} for map #{map.id} during renewal"
                  end)

                {:error, :no_active_subscription} ->
                  Logger.warning(
                    "Cannot create license for map #{map.id}: No active subscription found"
                  )

                {:error, reason} ->
                  Logger.error(
                    "Failed to create license for map #{map.id} during renewal: #{inspect(reason)}"
                  )
              end

            {:ok, _license} ->
              # License exists, update its expiration date
              case WandererApp.License.LicenseManager.update_license_expiration_from_subscription(
                     map.id
                   ) do
                {:ok, updated_license} ->
                  Logger.info(
                    "Updated license expiration for map #{map.id} to #{updated_license.expire_at}"
                  )

                {:error, reason} ->
                  Logger.error(
                    "Failed to update license expiration for map #{map.id}: #{inspect(reason)}"
                  )
              end

            _ ->
              # Error occurred, do nothing
              :ok
          end

          :ok

        _ ->
          subscription
          |> WandererApp.MapSubscriptionRepo.cancel()

          @pubsub_client.broadcast(
            WandererApp.PubSub,
            "maps:#{map.id}",
            :subscription_settings_updated
          )

          case WandererApp.License.LicenseManager.get_license_by_map_id(map.id) do
            {:ok, license} ->
              WandererApp.License.LicenseManager.invalidate_license(license.id)
              Logger.info("Cancelled license for map #{map.id}")

            {:error, reason} ->
              Logger.error("Failed to cancel license for map #{map.id}: #{inspect(reason)}")
          end

          :telemetry.execute([:wanderer_app, :map, :subscription, :cancel], %{count: 1}, %{
            map_id: map.id
          })

          :ok
      end
    else
      error ->
        @logger.error(
          "Error renewing subscription for map #{subscription.map_id} #{inspect(error)}"
        )

        :ok
    end
  end

  defp renew_subscription(%{auto_renew?: false} = subscription) when is_map(subscription) do
    subscription
    |> WandererApp.MapSubscriptionRepo.expire()

    @pubsub_client.broadcast(
      WandererApp.PubSub,
      "maps:#{subscription.map_id}",
      :subscription_settings_updated
    )

    case WandererApp.License.LicenseManager.get_license_by_map_id(subscription.map_id) do
      {:ok, license} ->
        WandererApp.License.LicenseManager.invalidate_license(license.id)
        Logger.info("Cancelled license for map #{subscription.map_id}")

      {:error, reason} ->
        Logger.error(
          "Failed to cancel license for map #{subscription.map_id}: #{inspect(reason)}"
        )
    end

    :telemetry.execute([:wanderer_app, :map, :subscription, :expired], %{count: 1}, %{
      map_id: subscription.map_id
    })

    :ok
  end
end
