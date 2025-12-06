defmodule WandererAppWeb.MapsLive do
  use WandererAppWeb, :live_view

  alias Phoenix.LiveView.AsyncResult

  require Logger

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
      |> Enum.reject(&is_nil/1)

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
        |> assign(:available_scopes, available_scopes())
        |> assign(
          :form,
          AshPhoenix.Form.for_create(WandererApp.Api.Map, :new,
            forms: [
              auto?: true
            ],
            prepare_source: fn form ->
              form
              # Default to wormholes scope for new maps
              |> Map.put("scopes", [:wormholes])
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
        # Load the owner association to get character details
        map =
          case Ash.load(map, :owner) do
            {:ok, loaded_map} -> loaded_map |> map_map()
            _ -> map |> map_map()
          end

        # Auto-initialize scopes from legacy scope if scopes is empty/nil
        map = maybe_initialize_scopes_from_legacy(map)

        # Add owner to characters list, filtering out nil values
        characters =
          [map.owner |> map_character() | socket.assigns.characters]
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()

        socket
        |> assign(:active_page, :maps)
        |> assign(:uri, URI.parse(url) |> Map.put(:path, ~p"/"))
        |> assign(:page_title, "Maps - Edit")
        |> assign(:available_scopes, available_scopes())
        |> assign(:map_slug, map_slug)
        |> assign(:characters, characters)
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
        |> assign(:sse_enabled, map.sse_enabled)
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
          ],
          allowed_copy_for_options: [
            {"Administrators", "admin_map"},
            {"Managers", "manage_map"},
            {"Members", "add_system"}
          ],
          allowed_paste_for_options: [
            {"Members", "add_system"},
            {"Administrators", "admin_map"},
            {"Managers", "manage_map"}
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

  def handle_event("generate-map-api-key", _params, socket) do
    new_api_key = UUID.uuid4()

    map = WandererApp.Api.Map.by_id!(socket.assigns.map_id)

    {:ok, _updated_map} =
      WandererApp.Api.Map.update_api_key(map, %{public_api_key: new_api_key})

    {:noreply, assign(socket, public_api_key: new_api_key)}
  end

  def handle_event("toggle-sse", _params, socket) do
    new_sse_enabled = not socket.assigns.sse_enabled
    map = socket.assigns.map

    case WandererApp.Api.Map.toggle_sse(map, %{sse_enabled: new_sse_enabled}) do
      {:ok, updated_map} ->
        {:noreply, assign(socket, sse_enabled: new_sse_enabled, map: updated_map)}

      {:error, %Ash.Error.Invalid{errors: errors}} ->
        error_message =
          errors
          |> Enum.map(fn error -> Map.get(error, :message, "Unknown error") end)
          |> Enum.join(", ")

        {:noreply, put_flash(socket, :error, error_message)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update SSE setting")}
    end
  end

  @impl true
  def handle_event(
        "live_select_change",
        %{"id" => id, "text" => _text} = _change_event,
        socket
      ) do
    # This handler is for ACL live_select component
    send_update(LiveSelect.Component, options: socket.assigns.acls, id: id)

    {:noreply, socket}
  end

  def handle_event("validate", %{"form" => form} = _params, socket) do
    # Process scopes from checkbox form data
    scopes = parse_scopes_from_form(form)

    form =
      AshPhoenix.Form.validate(
        socket.assigns.form,
        form
        |> Map.put("acls", form["acls"] || [])
        |> Map.put("scopes", scopes)
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
    # Process scopes from checkbox form data
    scopes = parse_scopes_from_form(form)

    form = form |> Map.put("scopes", scopes)

    case WandererApp.Api.Map.new(form) do
      {:ok, new_map} ->
        :telemetry.execute([:wanderer_app, :map, :created], %{count: 1})
        maybe_create_default_acl(form, new_map)

        # Reload maps synchronously to avoid timing issues with flash messages
        {:ok, %{maps: maps}} = load_maps(current_user)

        {:noreply,
         socket
         |> put_flash(
           :info,
           "Map '#{new_map.name}' created successfully with slug '#{new_map.slug}'"
         )
         |> assign(:maps, AsyncResult.ok(maps))
         |> push_patch(to: ~p"/maps")}

      {:error, %Ash.Error.Invalid{errors: errors}} ->
        # Check for slug uniqueness constraint violation
        slug_error =
          Enum.find(errors, fn error ->
            case error do
              %{field: :slug} -> true
              %{message: message} when is_binary(message) -> String.contains?(message, "unique")
              _ -> false
            end
          end)

        error_message =
          if slug_error do
            "A map with this name already exists. The system will automatically adjust the name if needed. Please try again."
          else
            errors
            |> Enum.map(fn error ->
              field = Map.get(error, :field, "field")
              message = Map.get(error, :message, "validation error")
              "#{field}: #{message}"
            end)
            |> Enum.join(", ")
          end

        Logger.warning("Map creation failed",
          form: form,
          errors: inspect(errors),
          slug_error: slug_error != nil
        )

        {:noreply,
         socket
         |> put_flash(:error, "Failed to create map: #{error_message}")
         |> assign(error: error_message)}

      {:error, %{errors: errors}} ->
        error_message =
          errors
          |> Enum.map(fn error ->
            "#{Map.get(error, :message, "Field validation error")}"
          end)
          |> Enum.join(", ")

        {:noreply,
         socket
         |> put_flash(:error, "Failed to create map: #{error_message}")
         |> assign(error: error_message)}

      {:error, error} ->
        Logger.error("Unexpected error creating map",
          form: form,
          error: inspect(error)
        )

        {:noreply,
         socket
         |> put_flash(:error, "Failed to create map. Please try again.")
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
    WandererApp.MapRepo.get_map_by_slug_safely(map_slug)
    |> case do
      {:ok, map} ->
        # Successfully found the map, proceed with loading and updating
        {:ok, map_with_acls} = Ash.load(map, :acls)

        # Process scopes from checkbox form data
        scopes = parse_scopes_from_form(form)

        form =
          form
          |> Map.put("acls", form["acls"] || [])
          |> Map.put("scopes", scopes)
          |> Map.put(
            "only_tracked_characters",
            (form["only_tracked_characters"] || "false") |> String.to_existing_atom()
          )

        map_with_acls
        |> WandererApp.Api.Map.update(form)
        |> case do
          {:ok, _updated_map} ->
            {added_acls, removed_acls} =
              map_with_acls.acls |> Enum.map(& &1.id) |> _get_acls_diff(form["acls"])

            Phoenix.PubSub.broadcast(
              WandererApp.PubSub,
              "maps:#{map_with_acls.id}",
              {:map_acl_updated, map_with_acls.id, added_acls, removed_acls}
            )

            {:ok, tracked_characters} =
              WandererApp.Maps.get_tracked_map_characters(map_with_acls.id, current_user)

            first_tracked_character_id = Enum.map(tracked_characters, & &1.id) |> List.first()

            added_acls
            |> Enum.each(fn acl_id ->
              WandererApp.User.ActivityTracker.track_map_event(:map_acl_added, %{
                character_id: first_tracked_character_id,
                user_id: current_user.id,
                map_id: map_with_acls.id,
                acl_id: acl_id
              })
            end)

            removed_acls
            |> Enum.each(fn acl_id ->
              WandererApp.User.ActivityTracker.track_map_event(:map_acl_removed, %{
                character_id: first_tracked_character_id,
                user_id: current_user.id,
                map_id: map_with_acls.id,
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

      {:error, :multiple_results} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "Multiple maps found with this identifier. Please contact support to resolve this issue."
         )
         |> push_navigate(to: ~p"/maps")}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Map not found")
         |> push_navigate(to: ~p"/maps")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to load map. Please try again.")
         |> push_navigate(to: ~p"/maps")}
    end
  end

  def handle_event("delete", %{"data" => map_slug} = _params, socket) do
    WandererApp.MapRepo.get_map_by_slug_safely(map_slug)
    |> case do
      {:ok, map} ->
        # Successfully found the map, proceed with deletion
        deleted_map = WandererApp.Api.Map.mark_as_deleted!(map)

        Phoenix.PubSub.broadcast(
          WandererApp.PubSub,
          "maps:#{deleted_map.id}",
          :map_deleted
        )

        current_user = socket.assigns.current_user

        # Reload maps synchronously to avoid timing issues with flash messages
        {:ok, %{maps: maps}} = load_maps(current_user)

        {:noreply,
         socket
         |> assign(:maps, AsyncResult.ok(maps))
         |> push_patch(to: ~p"/maps")}

      {:error, :multiple_results} ->
        # Multiple maps found with this slug - data integrity issue
        # Reload maps synchronously
        {:ok, %{maps: maps}} = load_maps(socket.assigns.current_user)

        {:noreply,
         socket
         |> put_flash(
           :error,
           "Multiple maps found with this identifier. Please contact support to resolve this issue."
         )
         |> assign(:maps, AsyncResult.ok(maps))}

      {:error, :not_found} ->
        # Map not found
        # Reload maps synchronously
        {:ok, %{maps: maps}} = load_maps(socket.assigns.current_user)

        {:noreply,
         socket
         |> put_flash(:error, "Map not found or already deleted")
         |> assign(:maps, AsyncResult.ok(maps))
         |> push_patch(to: ~p"/maps")}

      {:error, _reason} ->
        # Other error
        # Reload maps synchronously
        {:ok, %{maps: maps}} = load_maps(socket.assigns.current_user)

        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete map. Please try again.")
         |> assign(:maps, AsyncResult.ok(maps))}
    end
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
        "restrict_offline_showing",
        "allowed_copy_for",
        "allowed_paste_for"
      ])

    {:ok, updated_map} = WandererApp.MapRepo.update_options(map, options)

    @pubsub_client.broadcast(
      WandererApp.PubSub,
      "maps:#{map_id}",
      {:options_updated, map_id, options}
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
        %{assigns: %{current_user: _current_user, map_id: _map_id}} = socket
      ) do
    if entry.done? do
      [_uploaded_file_path] =
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

  defp available_scopes do
    [
      %{value: "wormholes", label: "Wormholes", description: "J-space systems"},
      %{value: "hi", label: "High-Sec", description: "Security 0.5 - 1.0"},
      %{value: "low", label: "Low-Sec", description: "Security 0.1 - 0.4"},
      %{value: "null", label: "Null-Sec", description: "Security 0.0 and below"},
      %{value: "pochven", label: "Pochven", description: "Triglavian space"}
    ]
  end

  # Auto-initialize scopes from legacy scope setting if scopes is empty/nil
  defp maybe_initialize_scopes_from_legacy(%{scopes: scopes} = map)
       when is_list(scopes) and scopes != [] do
    # Scopes already set, don't override
    map
  end

  defp maybe_initialize_scopes_from_legacy(%{scope: scope} = map) do
    # Convert legacy scope to new scopes format
    scopes = legacy_scope_to_scopes(scope)
    Map.put(map, :scopes, scopes)
  end

  defp maybe_initialize_scopes_from_legacy(map) do
    # No scope field, default to wormholes
    Map.put(map, :scopes, [:wormholes])
  end

  # Convert legacy scope atom to new scopes list
  defp legacy_scope_to_scopes(:wormholes), do: [:wormholes]
  defp legacy_scope_to_scopes(:stargates), do: [:hi, :low, :null]
  defp legacy_scope_to_scopes(:none), do: []
  defp legacy_scope_to_scopes(:all), do: [:wormholes, :hi, :low, :null, :pochven]
  defp legacy_scope_to_scopes(_), do: [:wormholes]

  defp parse_scopes_from_form(form) do
    # Extract selected scopes from form data
    # Form sends scopes as "scopes" => %{"wormholes" => "true", "hi" => "true", ...}
    form
    |> Map.get("scopes", %{})
    |> case do
      scopes when is_map(scopes) ->
        scopes
        |> Enum.filter(fn {_key, value} -> value == "true" end)
        |> Enum.map(fn {key, _value} -> String.to_existing_atom(key) end)

      scopes when is_list(scopes) ->
        # Already a list of atoms/strings
        scopes
        |> Enum.map(fn
          scope when is_atom(scope) -> scope
          scope when is_binary(scope) -> String.to_existing_atom(scope)
        end)

      _ ->
        []
    end
  end

  # Helper function to get current scopes from form for checkbox state
  def get_current_scopes(form) do
    scopes = Phoenix.HTML.Form.input_value(form, :scopes) || []

    scopes
    |> Enum.map(fn
      scope when is_atom(scope) -> Atom.to_string(scope)
      scope when is_binary(scope) -> scope
    end)
  end
end
