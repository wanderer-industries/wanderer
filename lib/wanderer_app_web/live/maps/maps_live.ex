defmodule WandererAppWeb.MapsLive do
  use WandererAppWeb, :live_view

  require Logger

  alias BetterNumber, as: Number
  alias WandererAppWeb.Maps.LicenseComponent

  @pubsub_client Application.compile_env(:wanderer_app, :pubsub_client)

  @impl true
  def mount(
        _params,
        _session,
        %{assigns: %{current_user: current_user}} = socket
      )
      when not is_nil(current_user) and is_connected?(socket) do
    {:ok, active_characters} =
      WandererApp.Api.Character.active_by_user(%{user_id: current_user.id})

    user_characters =
      active_characters
      |> Enum.map(&map_character/1)

    {:ok,
     socket
     |> assign(
       characters: user_characters,
       importing: false,
       map_subscriptions_enabled?: WandererApp.Env.map_subscriptions_enabled?(),
       restrict_maps_creation?: WandererApp.Env.restrict_maps_creation?(),
       acls: [],
       location: nil,
       is_version_valid?: false
     )
     |> assign_async(:maps, fn ->
       load_maps(current_user)
     end)}
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       characters: [],
       location: nil,
       is_version_valid?: false,
       restrict_maps_creation?: WandererApp.Env.restrict_maps_creation?()
     )}
  end

  @impl true
  def handle_params(params, url, socket) when is_connected?(socket) do
    {:noreply,
     socket
     |> assign(:is_connected?, true)
     |> apply_action(socket.assigns.live_action, params, url)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket |> assign(:is_connected?, false)}
  end

  defp apply_action(socket, :index, _params, _url) do
    socket
    |> assign(:active_page, :maps)
    |> assign(:page_title, "Maps")
  end

  defp apply_action(socket, :create, _params, url) do
    allow_map_creation()
    |> case do
      true ->
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

      _ ->
        socket
        |> push_patch(to: ~p"/maps")
    end
  end

  defp apply_action(
         %{assigns: %{current_user: current_user}} = socket,
         :edit,
         %{"slug" => map_slug} = _params,
         url
       )
       when not is_nil(current_user) do
    WandererApp.Maps.check_user_can_delete_map(map_slug, current_user)
    |> case do
      {:ok, map} ->
        map = map |> map_map()

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

      _ ->
        socket
        |> put_flash(:error, "You don't have an access.")
        |> push_navigate(to: ~p"/maps")
    end
  end

  defp apply_action(
         %{assigns: %{current_user: current_user}} = socket,
         :settings,
         %{"slug" => map_slug} = _params,
         _url
       )
       when not is_nil(current_user) do
    WandererApp.Maps.check_user_can_delete_map(map_slug, current_user)
    |> case do
      {:ok, map} ->
        {:ok, export_settings} =
          map
          |> WandererApp.Map.Server.get_export_settings()

        {:ok, options_form_data} = WandererApp.MapRepo.options_to_form_data(map)

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

      _ ->
        socket
        |> put_flash(:error, "You don't have an access.")
        |> push_navigate(to: ~p"/maps")
    end
  end

  defp allow_map_creation(),
    do: not WandererApp.Env.restrict_maps_creation?() || WandererApp.Cache.take("create_map_once")

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

  def handle_event(
        "create",
        %{"form" => form},
        %{assigns: %{current_user: current_user}} = socket
      )
      when not is_nil(current_user) do
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

        {:noreply,
         socket
         |> assign_async(:maps, fn ->
           load_maps(current_user)
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

  def handle_event("open_audit", %{"data" => slug}, socket),
    do:
      {:noreply,
       socket
       |> push_navigate(to: ~p"/#{slug}/audit?period=1H&activity=all")}

  def handle_event("open_characters", %{"data" => slug}, socket),
    do:
      {:noreply,
       socket
       |> push_navigate(to: ~p"/#{slug}/characters")}

  def handle_event("open_settings", %{"data" => slug}, socket) do
    {:noreply,
     socket
     |> push_patch(to: ~p"/maps/#{slug}/settings")}
  end

  @impl true
  def handle_event("change_settings_tab", %{"tab" => tab}, socket),
    do: {:noreply, socket |> assign(active_settings_tab: tab)}

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
      |> Map.put("acls", form["acls"] || [])
      |> Map.put("scope", scope)
      |> Map.put(
        "only_tracked_characters",
        (form["only_tracked_characters"] || "false") |> String.to_existing_atom()
      )

    map
    |> WandererApp.Api.Map.update(form)
    |> case do
      {:ok, _updated_map} ->
        {added_acls, removed_acls} = map.acls |> Enum.map(& &1.id) |> _get_acls_diff(form["acls"])

        Phoenix.PubSub.broadcast(
          WandererApp.PubSub,
          "maps:#{map.id}",
          {:map_acl_updated, added_acls, removed_acls}
        )

        {:ok, tracked_characters} =
          WandererApp.Maps.get_tracked_map_characters(map.id, current_user)

        first_tracked_character_id = Enum.map(tracked_characters, & &1.id) |> List.first()

        added_acls
        |> Enum.each(fn acl_id ->
          {:ok, _} =
            WandererApp.User.ActivityTracker.track_map_event(:map_acl_added, %{
              character_id: first_tracked_character_id,
              user_id: current_user.id,
              map_id: map.id,
              acl_id: acl_id
            })
        end)

        removed_acls
        |> Enum.each(fn acl_id ->
          {:ok, _} =
            WandererApp.User.ActivityTracker.track_map_event(:map_acl_removed, %{
              character_id: first_tracked_character_id,
              user_id: current_user.id,
              map_id: map.id,
              acl_id: acl_id
            })
        end)

        {:noreply,
         socket
         |> push_navigate(to: ~p"/maps")}

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
       load_maps(current_user)
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
        {_event, {:flash, type, message}},
        socket
      ) do
    {:noreply, socket |> put_flash(type, message)}
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

      # Task.async(fn ->
      #   {:ok, data} =
      #     WandererApp.Utils.JSONUtil.read_json(uploaded_file_path)

      #   WandererApp.Map.Manager.start_map(map_id)

      #   :timer.sleep(1000)

      #   map_id
      #   |> WandererApp.Map.Server.import_settings(data, current_user.id)

      #   :imported
      # end)

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
      extra_characters_50: extra_characters_50,
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

  defp load_maps(current_user) do
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
