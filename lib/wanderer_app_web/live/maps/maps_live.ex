defmodule WandererAppWeb.MapsLive do
  use WandererAppWeb, :live_view

  require Logger

  alias BetterNumber, as: Number

  @pubsub_client Application.compile_env(:wanderer_app, :pubsub_client)

  @impl true
  def mount(
        _params,
        %{"user_id" => user_id} = _session,
        %{assigns: %{current_user: current_user}} = socket
      )
      when not is_nil(user_id) do
    {:ok, active_characters} = WandererApp.Api.Character.active_by_user(%{user_id: user_id})

    user_characters =
      active_characters
      |> Enum.map(&map_character/1)

    {:ok,
     socket
     |> assign(
       characters: user_characters,
       importing: false,
       map_subscriptions_enabled?: WandererApp.Env.map_subscriptions_enabled?(),
       acls: [],
       location: nil
     )
     |> assign_async(:maps, fn ->
       _load_maps(current_user)
     end)}
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(maps: [], characters: [], location: nil)}
  end

  @impl true
  def handle_params(params, url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params, url)}
  end

  defp apply_action(socket, :index, _params, _url) do
    socket
    |> assign(:active_page, :maps)
    |> assign(:page_title, "Maps")
  end

  defp apply_action(socket, :create, _params, url) do
    socket
    |> assign(:active_page, :maps)
    |> assign(:uri, URI.parse(url) |> Map.put(:path, ~p"/"))
    |> assign(:page_title, "Maps - Create")
    |> assign(:scopes, ["wormholes", "stargates", "none", "all"])
    |> assign(
      :form,
      AshPhoenix.Form.for_create(WandererApp.Api.Map, :new,
        forms: [
          auto?: true
        ],
        prepare_source: fn form ->
          form
          |> Map.put("scope", "wormholes")
        end
      )
    )
    |> load_access_lists()
  end

  defp apply_action(socket, :edit, %{"slug" => map_slug} = _params, url) do
    map =
      map_slug
      |> WandererApp.Api.Map.get_map_by_slug!()
      |> Ash.load!([:owner, :acls])
      |> map_map()

    socket
    |> assign(:active_page, :maps)
    |> assign(:uri, URI.parse(url) |> Map.put(:path, ~p"/"))
    |> assign(:page_title, "Maps - Edit")
    |> assign(:scopes, ["wormholes", "stargates", "none", "all"])
    |> assign(:map_slug, map_slug)
    |> assign(
      :characters,
      [map.owner |> map_character() | socket.assigns.characters] |> Enum.uniq()
    )
    |> assign(
      :form,
      map |> AshPhoenix.Form.for_update(:update, forms: [auto?: true])
    )
    |> load_access_lists()
  end

  defp apply_action(socket, :settings, %{"slug" => map_slug} = _params, _url) do
    map =
      map_slug
      |> WandererApp.Api.Map.get_map_by_slug!()
      |> Ash.load!([:owner, :acls])

    {:ok, export_settings} =
      map
      |> WandererApp.Map.Server.get_export_settings()

    {:ok, map_balance} = WandererApp.Map.SubscriptionManager.get_balance(map)

    {:ok, map_subscriptions} = WandererApp.Map.SubscriptionManager.get_map_subscriptions(map.id)

    subscription_form = %{
      "plan" => "omega",
      "period" => "1",
      "characters_limit" => "300",
      "hubs_limit" => "10",
      "auto_renew?" => true
    }

    {:ok, options_form_data} = WandererApp.MapRepo.options_to_form_data(map)

    {:ok, estimated_price, discount} =
      WandererApp.Map.SubscriptionManager.estimate_price(subscription_form, false)

    socket
    |> assign(:active_page, :maps)
    |> assign(:page_title, "Maps - Settings")
    |> assign(:map_slug, map_slug)
    |> assign(:map_id, map.id)
    |> assign(:public_api_key, map.public_api_key)
    |> assign(:map, map)
    |> assign(
      export_settings: export_settings |> _get_export_map_data(),
      import_form: to_form(%{}),
      importing: false,
      show_settings?: true,
      is_topping_up?: false,
      active_settings_tab: "general",
      is_adding_subscription?: false,
      selected_subscription: nil,
      options_form: options_form_data |> to_form(),
      map_subscriptions: map_subscriptions,
      subscription_form: subscription_form |> to_form(),
      estimated_price: estimated_price,
      discount: discount,
      map_balance: map_balance,
      topup_form: %{} |> to_form(),
      subscription_plans: ["omega", "advanced"],
      subscription_periods: [
        {"1 Month", "1"},
        {"3 Months", "3"},
        {"6 Months", "6"},
        {"1 Year", "12"}
      ],
      layout_options: [
        {"Left To Right", "left_to_right"},
        {"Top To Bottom", "top_to_bottom"}
      ]
    )
    |> allow_upload(:settings,
      accept: ~w(.json),
      max_entries: 1,
      max_file_size: 10_000_000,
      auto_upload: true,
      progress: &handle_progress/3
    )
  end

  @impl true
  def handle_event("set-default", %{"id" => id}, socket) do
    send_update(LiveSelect.Component, options: socket.assigns.characters, id: id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("set-default-scope", %{"id" => id}, socket) do
    send_update(LiveSelect.Component, options: ["wormholes", "stargates", "none", "all"], id: id)

    {:noreply, socket}
  end

  def handle_event("generate-map-api-key", _params, socket) do
    new_api_key = UUID.uuid4()

    map = WandererApp.Api.Map.by_id!(socket.assigns.map_id)

    {:ok, _updated_map} =
      WandererApp.Api.Map.update_api_key(map, %{public_api_key: new_api_key})

    {:noreply, assign(socket, public_api_key: new_api_key)}
  end

  @impl true
  def handle_event(
        "live_select_change",
        %{"id" => id, "text" => text} = _change_event,
        socket
      ) do
    options =
      if text == "" do
        socket.assigns.scopes
      else
        socket.assigns.scopes
      end

    send_update(LiveSelect.Component, options: options, id: id)

    {:noreply, socket}
  end

  def handle_event("validate", %{"form" => form} = _params, socket) do
    form =
      AshPhoenix.Form.validate(
        socket.assigns.form,
        form
        |> Map.put("acls", form["acls"] || [])
        |> Map.put(
          "only_tracked_characters",
          (form["only_tracked_characters"] || "false") |> String.to_existing_atom()
        )
      )

    {:noreply, socket |> assign(form: form)}
  end

  def handle_event("create", %{"form" => form}, socket) do
    scope =
      form
      |> Map.get("scope")
      |> case do
        "" -> "wormholes"
        scope -> scope
      end

    form = form |> Map.put("scope", scope)

    case WandererApp.Api.Map.new(form) do
      {:ok, new_map} ->
        :telemetry.execute([:wanderer_app, :map, :created], %{count: 1})
        maybe_create_default_acl(form, new_map)

        current_user = socket.assigns.current_user

        {:noreply,
         socket
         |> assign_async(:maps, fn ->
           _load_maps(current_user)
         end)
         |> push_patch(to: ~p"/maps")}

      {:error, %{errors: errors}} ->
        error_message =
          errors
          |> Enum.map(fn %{field: _field} = error ->
            "#{Map.get(error, :message, "Field validation error")}"
          end)
          |> Enum.join(", ")

        {:noreply,
         socket
         |> put_flash(:error, "Failed to create map: #{error_message}")
         |> assign(error: error_message)}

      {:error, error} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create map")
         |> assign(error: error)}
    end
  end

  def handle_event("edit_map", %{"data" => slug}, socket) do
    {:noreply,
     socket
     |> push_patch(to: ~p"/maps/#{slug}/edit")}
  end

  def handle_event("open_audit", %{"data" => slug}, socket) do
    {:noreply,
     socket
     |> push_navigate(to: ~p"/#{slug}/audit?period=1H&activity=all")}
  end

  def handle_event("open_settings", %{"data" => slug}, socket) do
    {:noreply,
     socket
     |> push_patch(to: ~p"/maps/#{slug}/settings")}
  end

  @impl true
  def handle_event("change_settings_tab", %{"tab" => tab}, socket),
    do: {:noreply, socket |> assign(active_settings_tab: tab)}

  @impl true
  def handle_event("show_topup", _, socket),
    do:
      {:noreply,
       socket
       |> assign(
         :amounts,
         [
           {"150M", 150_000_000},
           {"300M", 300_000_000},
           {"600M", 600_000_000},
           {"1.2B", 1_200_000_000},
           {"2.4B", 2_400_000_000},
           {"5B", 5_000_000_000}
         ]
       )
       |> assign(is_topping_up?: true)}

  @impl true
  def handle_event("hide_topup", _, socket),
    do: {:noreply, socket |> assign(is_topping_up?: false)}

  @impl true
  def handle_event("add_subscription", _, socket),
    do: {:noreply, socket |> assign(is_adding_subscription?: true)}

  @impl true
  def handle_event(
        "topup",
        %{"amount" => amount} = _event,
        %{assigns: %{current_user: current_user, map: map, map_id: map_id}} = socket
      ) do
    amount = amount |> Decimal.new() |> Decimal.to_float()

    user =
      current_user.id
      |> WandererApp.User.load()

    {:ok, user_balance} =
      user
      |> WandererApp.User.get_balance()

    case amount <= user_balance do
      true ->
        {:ok, _t} =
          WandererApp.Api.MapTransaction.create(%{
            map_id: map_id,
            user_id: current_user.id,
            amount: amount,
            type: :in
          })

        {:ok, _user} =
          user
          |> WandererApp.Api.User.update_balance(%{
            balance: (user_balance || 0.0) - amount
          })

        {:ok, map_balance} = WandererApp.Map.SubscriptionManager.get_balance(map)

        {:noreply, socket |> assign(is_topping_up?: false, map_balance: map_balance)}

      _ ->
        {:noreply,
         socket |> put_flash(:error, "You don't have enough ISK on your account balance!")}
    end
  end

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

    {:noreply,
     socket
     |> assign(
       is_adding_subscription?: true,
       selected_subscription: selected_subscription,
       additional_price: _additional_price(subscription_form, selected_subscription),
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

    {:noreply,
     socket
     |> assign(is_adding_subscription?: false, map_subscriptions: map_subscriptions)
     |> put_flash(:info, "Subscription cancelled!")}
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
          socket |> assign(additional_price: _additional_price(params, selected_subscription))
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

        {:ok, map_balance} = WandererApp.Map.SubscriptionManager.get_balance(map)

        Phoenix.PubSub.broadcast(
          WandererApp.PubSub,
          "maps:#{map_id}",
          :subscription_settings_updated
        )

        :telemetry.execute([:wanderer_app, :map, :subscription, :new], %{count: 1}, %{
          map_id: map_id,
          amount: estimated_price - discount
        })

        {:noreply,
         socket
         |> assign(
           is_adding_subscription?: false,
           map_subscriptions: map_subscriptions,
           map_balance: map_balance
         )
         |> put_flash(:info, "Subscription added!")}

      _ ->
        {:noreply, socket |> put_flash(:error, "You have not enough ISK on Map Balance!")}
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
    additional_price = _additional_price(subscription_form, selected_subscription)
    {:ok, map_balance} = WandererApp.Map.SubscriptionManager.get_balance(map)

    case map_balance >= additional_price do
      true ->
        {:ok, _t} =
          WandererApp.Api.MapTransaction.create(%{
            map_id: map_id,
            user_id: current_user.id,
            amount: additional_price,
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

        {:ok, map_balance} = WandererApp.Map.SubscriptionManager.get_balance(map)

        Phoenix.PubSub.broadcast(
          WandererApp.PubSub,
          "maps:#{map_id}",
          :subscription_settings_updated
        )

        :telemetry.execute([:wanderer_app, :map, :subscription, :update], %{count: 1}, %{
          map_id: map_id,
          amount: additional_price
        })

        {:noreply,
         socket
         |> assign(
           is_adding_subscription?: false,
           selected_subscription: nil,
           map_balance: map_balance,
           map_subscriptions: map_subscriptions
         )
         |> put_flash(:info, "Subscription updated!")}

      _ ->
        {:noreply, socket |> put_flash(:error, "You have not enough ISK on Map Balance!")}
    end
  end

  @impl true
  def handle_event("cancel_edit_subscription", _event, socket) do
    {:noreply, socket |> assign(is_adding_subscription?: false, selected_subscription: nil)}
  end

  def handle_event("open_acl", %{"data" => id}, socket) do
    {:noreply,
     socket
     |> push_navigate(to: ~p"/access-lists/#{id}")}
  end

  def handle_event(
        "edit",
        %{"form" => form} = _params,
        %{assigns: %{map_slug: map_slug, current_user: current_user}} = socket
      ) do
    {:ok, map} =
      map_slug
      |> WandererApp.Api.Map.get_map_by_slug!()
      |> Ash.load(:acls)

    scope =
      form
      |> Map.get("scope")
      |> case do
        "" -> "wormholes"
        scope -> scope
      end

    form =
      form
      |> Map.put("scope", scope)
      |> Map.put(
        "only_tracked_characters",
        (form["only_tracked_characters"] || "false") |> String.to_existing_atom()
      )

    map
    |> WandererApp.Api.Map.update(form)
    |> case do
      {:ok, updated_map} ->
        case form["acls"] do
          nil ->
            {:ok, _} = WandererApp.Api.Map.update_acls(updated_map, %{acls: []})

          acls when is_list(acls) ->
            {:ok, _} = WandererApp.Api.Map.update_acls(updated_map, %{acls: acls})
        end

        {added_acls, removed_acls} = map.acls |> Enum.map(& &1.id) |> _get_acls_diff(form["acls"])

        Phoenix.PubSub.broadcast(
          WandererApp.PubSub,
          "maps:#{map.id}",
          {:map_acl_updated, added_acls, removed_acls}
        )

        {:noreply,
         socket
         |> assign_async(:maps, fn ->
           _load_maps(current_user)
         end)
         |> push_patch(to: ~p"/maps")}

      {:error, error} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update map")
         |> assign(error: error)}
    end
  end

  def handle_event("delete", %{"data" => map_slug} = _params, socket) do
    map =
      map_slug
      |> WandererApp.Api.Map.get_map_by_slug!()
      |> WandererApp.Api.Map.mark_as_deleted!()

    Phoenix.PubSub.broadcast(
      WandererApp.PubSub,
      "maps:#{map.id}",
      :map_deleted
    )

    current_user = socket.assigns.current_user

    {:noreply,
     socket
     |> assign_async(:maps, fn ->
       _load_maps(current_user)
     end)
     |> push_patch(to: ~p"/maps")}
  end

  def handle_event(
        "update_options",
        options_form,
        %{assigns: %{map_id: map_id, map: map}} = socket
      ) do
    options =
      options_form
      |> Map.take([
        "layout",
        "store_custom_labels",
        "show_linked_signature_id",
        "show_linked_signature_id_temp_name",
        "show_temp_system_name",
        "restrict_offline_showing"
      ])

    {:ok, updated_map} = WandererApp.MapRepo.update_options(map, options)

    @pubsub_client.broadcast(
      WandererApp.PubSub,
      "maps:#{map_id}",
      {:options_updated, options}
    )

    {:noreply, socket |> assign(map: updated_map, options_form: options_form)}
  end

  @impl true
  def handle_event("noop", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("import", _form, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event(_event, _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {ref, result},
        socket
      ) do
    Process.demonitor(ref, [:flush])

    case result do
      :imported ->
        {:noreply,
         socket
         |> assign(importing: false)
         |> put_flash(:info, "Map settings imported successfully!")}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_progress(
        :settings,
        entry,
        %{assigns: %{current_user: current_user, map_id: map_id}} = socket
      ) do
    if entry.done? do
      [uploaded_file_path] =
        consume_uploaded_entries(socket, :settings, fn %{path: path}, _entry ->
          tmp_file_path =
            System.tmp_dir!()
            |> Path.join("map_settings_" <> to_string(:rand.uniform(256)) <> ".json")

          File.cp!(path, tmp_file_path)
          {:ok, tmp_file_path}
        end)

      Task.async(fn ->
        {:ok, data} =
          WandererApp.Utils.JSONUtil.read_json(uploaded_file_path)

        WandererApp.Map.Manager.start_map(map_id)

        :timer.sleep(1000)

        map_id
        |> WandererApp.Map.Server.import_settings(data, current_user.id)

        :imported
      end)

      {:noreply,
       socket
       |> assign(importing: true)
       |> put_flash(:loading, "Importing map settings...")}
    else
      {:noreply, socket}
    end
  end

  defp _additional_price(
         %{"characters_limit" => characters_limit, "hubs_limit" => hubs_limit},
         selected_subscription
       ) do
    %{
      extra_characters_100: extra_characters_100,
      extra_hubs_10: extra_hubs_10
    } = WandererApp.Env.subscription_settings()

    additional_price = 0

    characters_limit = characters_limit |> String.to_integer()
    hubs_limit = hubs_limit |> String.to_integer()
    sub_characters_limit = selected_subscription.characters_limit
    sub_hubs_limit = selected_subscription.hubs_limit

    additional_price =
      case characters_limit > sub_characters_limit do
        true ->
          additional_price +
            (characters_limit - sub_characters_limit) / 100 * extra_characters_100

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

    additional_price
  end

  defp _get_export_map_data(map) do
    %{
      systems: map.systems |> Enum.map(&_map_ui_system/1),
      hubs: map.hubs,
      connections: map.connections |> Enum.map(&_map_ui_connection/1)
    }
  end

  defp _map_ui_system(
         %{
           solar_system_id: solar_system_id,
           name: name,
           description: description,
           position_x: position_x,
           position_y: position_y,
           locked: locked,
           tag: tag,
           labels: labels,
           status: status,
           visible: visible
         } = _system
       ) do
    %{
      id: "#{solar_system_id}",
      position: %{x: position_x, y: position_y},
      description: description,
      name: name,
      labels: labels,
      locked: locked,
      status: status,
      tag: tag,
      visible: visible
    }
  end

  defp _map_ui_connection(
         %{
           solar_system_source: solar_system_source,
           solar_system_target: solar_system_target,
           mass_status: mass_status,
           time_status: time_status,
           ship_size_type: ship_size_type,
           locked: locked
         } = _connection
       ),
       do: %{
         id: "#{solar_system_source}_#{solar_system_target}",
         mass_status: mass_status,
         time_status: time_status,
         ship_size_type: ship_size_type,
         locked: locked,
         source: "#{solar_system_source}",
         target: "#{solar_system_target}"
       }

  defp _load_maps(current_user) do
    {:ok, maps} = WandererApp.Maps.get_available_maps(current_user)

    maps =
      maps
      |> Enum.sort_by(& &1.name, :asc)
      |> Enum.map(fn map ->
        map |> Ash.load!(:user_permissions, actor: current_user)
      end)
      |> Enum.map(fn map ->
        acls =
          map.acls
          |> Enum.map(fn acl -> acl |> Ash.load!(:members) end)

        {:ok, characters_count} =
          map.id
          |> WandererApp.MapCharacterSettingsRepo.get_tracked_by_map_all()
          |> case do
            {:ok, settings} ->
              {:ok,
               settings
               |> Enum.count()}

            _ ->
              {:ok, 0}
          end

        %{map | acls: acls} |> Map.put(:characters_count, characters_count)
      end)

    {:ok, %{maps: maps}}
  end

  defp _get_acls_diff(acls, nil) do
    {[], acls}
  end

  defp _get_acls_diff(acls, new_acls) do
    removed_acls = acls -- new_acls
    added_acls = new_acls -- acls

    {added_acls, removed_acls}
  end

  defp maybe_create_default_acl(%{"create_default_acl" => "true"} = _form, new_map) do
    {:ok, acl} =
      WandererApp.Api.AccessList.new(%{
        name: "#{new_map.name} ACL",
        description: "Default ACL for #{new_map.name}",
        owner_id: new_map.owner_id
      })

    {:ok, _} = WandererApp.Api.Map.update_acls(new_map, %{acls: [acl.id]})
  end

  defp maybe_create_default_acl(_form, _new_map), do: :ok

  defp load_access_lists(socket) do
    {:ok, access_lists} = WandererApp.Acls.get_available_acls(socket.assigns.current_user)

    socket |> assign(acls: access_lists |> Enum.map(&map_acl/1))
  end

  defp map_acl(%{name: name, id: id} = _acl) do
    %{label: name, value: id, id: id}
  end

  defp map_acl_value(acl) do
    acl
  end

  defp map_character(%{name: name, id: id, eve_id: eve_id} = _character) do
    %{label: name, value: id, id: id, eve_id: eve_id}
  end

  defp map_character(_character), do: nil

  defp map_map(%{acls: acls} = map) do
    map
    |> Map.put(:acls, acls |> Enum.map(&map_acl/1))
  end
end
