defmodule WandererAppWeb.AccessListsLive do
  use WandererAppWeb, :live_view

  alias WandererApp.ExternalEvents.AclEventBroadcaster
  require Logger

  @impl true
  def mount(_params, %{"user_id" => user_id} = _session, socket) when not is_nil(user_id) do
    {:ok, characters} = WandererApp.Api.Character.active_by_user(%{user_id: user_id})

    characters =
      characters
      |> Enum.sort_by(& &1.name, :asc)
      |> Enum.map(&map_character/1)

    {:ok, access_lists} = WandererApp.Acls.get_available_acls(socket.assigns.current_user)

    {:ok,
     socket
     |> assign(
       selected_acl: nil,
       selected_acl_id: "",
       allow_acl_creation: not WandererApp.Env.restrict_acls_creation?(),
       user_id: user_id,
       access_lists: access_lists |> Enum.map(fn acl -> map_ui_acl(acl, nil) end),
       characters: characters,
       members: []
     )}
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       selected_acl: nil,
       selected_acl_id: "",
       allow_acl_creation: false,
       access_lists: [],
       characters: [],
       members: []
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:active_page, :access_lists)
    |> assign(:page_title, "Access Lists")
  end

  defp apply_action(socket, :create, _params) do
    socket
    |> assign(:active_page, :access_lists)
    |> assign(:page_title, "Access Lists - New")
    |> assign(
      :form,
      AshPhoenix.Form.for_create(WandererApp.Api.AccessList, :new,
        forms: [
          auto?: true
        ]
      )
      |> to_form()
    )
  end

  defp apply_action(socket, :edit, %{"id" => acl_id} = _params) do
    access_list = socket.assigns.access_lists |> Enum.find(&(&1.id == acl_id))

    socket
    |> assign(:active_page, :access_lists)
    |> assign(:page_title, "Access Lists - Edit")
    |> assign(:acl_id, acl_id)
    |> assign(
      :form,
      access_list |> AshPhoenix.Form.for_update(:update, forms: [auto?: true]) |> to_form()
    )
  end

  defp apply_action(socket, :members, %{"id" => acl_id} = _params) do
    with access_list when not is_nil(access_list) <-
           socket.assigns.access_lists |> Enum.find(&(&1.id == acl_id)),
         {:ok, access_list} <- access_list |> Ash.load(:owner),
         {:ok, members} <-
           WandererApp.Api.AccessListMember.read_by_access_list(%{access_list_id: acl_id}) do
      socket
      |> assign(:active_page, :access_lists)
      |> assign(:page_title, "Access Lists - Members")
      |> assign(:selected_acl_id, acl_id)
      |> assign(:access_list, access_list)
      |> assign(
        :members,
        members
      )
    else
      _ ->
        socket
        |> put_flash(:error, "You don't have an access to this access list.")
        |> push_navigate(to: ~p"/access-lists")
    end
  end

  defp apply_action(socket, :add_members, %{"id" => acl_id} = _params) do
    with {:ok, %{owner: %{id: _character_id}} = access_list} <-
           socket.assigns.access_lists |> Enum.find(&(&1.id == acl_id)) |> Ash.load(:owner),
         user_character_ids <- socket.assigns.current_user.characters |> Enum.map(& &1.id) do
      user_character_ids
      |> Enum.each(fn user_character_id ->
        :ok = WandererApp.Character.TrackerManager.start_tracking(user_character_id)
      end)

      socket
      |> assign(:active_page, :access_lists)
      |> assign(:page_title, "Access Lists - Add Members")
      |> assign(:selected_acl_id, acl_id)
      |> assign(:user_character_ids, user_character_ids)
      |> assign(
        member_search_options: socket.assigns.characters |> Enum.map(&map_user_character_info/1)
      )
      |> assign(:access_list, access_list)
      |> assign(
        :members,
        WandererApp.Api.AccessListMember.read_by_access_list!(%{access_list_id: acl_id})
      )
      |> assign(
        :member_form,
        %{} |> to_form()
      )
    else
      _ ->
        socket
    end
  end

  @impl true
  def handle_event(
        "live_select_change",
        %{"id" => "_member_id_live_select_component" = id, "text" => text} = _change_event,
        socket
      ) do
    options =
      if text == "" do
        socket.assigns.characters
      else
        DebounceAndThrottle.Debounce.apply(
          Process,
          :send_after,
          [self(), {:search, text}, 100],
          "member_search_#{socket.assigns.selected_acl_id}",
          250
        )

        [%{label: "Loading...", value: :loading, disabled: true}]
      end

    send_update(LiveSelect.Component, options: options, id: id)

    {:noreply,
     socket
     |> assign(member_search_options: options, member_search_text: text, member_search_id: id)}
  end

  @impl true
  def handle_event("live_select_change", %{"id" => id, "text" => text} = _change_event, socket) do
    options =
      if text == "" do
        socket.assigns.characters
      else
        socket.assigns.characters
      end

    send_update(LiveSelect.Component, options: options, id: id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_acl_" <> acl_id, _, socket) do
    {:noreply,
     socket
     |> push_patch(to: ~p"/access-lists/#{acl_id}")}
  end

  def handle_event("validate", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, form: form)}
  end

  def handle_event(
        "create",
        %{"form" => form},
        %{assigns: %{allow_acl_creation: true}} = socket
      ) do
    case WandererApp.Api.AccessList.new(form) do
      {:ok, _acl} ->
        {:ok, access_lists} = WandererApp.Acls.get_available_acls(socket.assigns.current_user)

        {:noreply,
         socket
         |> assign(
           selected_acl: nil,
           access_lists: access_lists |> Enum.map(fn acl -> map_ui_acl(acl, nil) end)
         )
         |> push_patch(to: ~p"/access-lists")}

      _ ->
        {:noreply, socket |> put_flash(:error, "Failed to create access list. Try again.")}
    end
  end

  def handle_event("edit", %{"form" => form} = _params, socket) do
    {:ok, _} =
      socket.assigns.access_lists
      |> Enum.find(&(&1.id == socket.assigns.acl_id))
      |> WandererApp.Api.AccessList.update(form)

    {:ok, access_lists} = WandererApp.Acls.get_available_acls(socket.assigns.current_user)

    {:noreply,
     socket
     |> assign(access_lists: access_lists |> Enum.map(fn acl -> map_ui_acl(acl, nil) end))
     |> push_patch(to: ~p"/access-lists")}
  end

  def handle_event(
        "add_members",
        %{"member_id" => [member_id]} = _params,
        %{assigns: assigns} = socket
      )
      when is_binary(member_id) and member_id != "" do
    member_option =
      assigns.member_search_options
      |> Enum.find(&(&1.value == member_id))

    add_member(socket, assigns.access_list.id, member_option)

    {:noreply, socket |> push_patch(to: ~p"/access-lists/#{assigns.access_list.id}")}
  end

  def handle_event("delete-acl", %{"id" => acl_id} = _params, socket) do
    case socket.assigns.access_lists
         |> Enum.find(&(&1.id == acl_id))
         |> WandererApp.Api.AccessList.destroy!() do
      :ok ->
        Phoenix.PubSub.broadcast(
          WandererApp.PubSub,
          "acls:#{acl_id}",
          {:acl_deleted, %{acl_id: acl_id}}
        )

        {:ok, access_lists} = WandererApp.Acls.get_available_acls(socket.assigns.current_user)

        {:noreply,
         socket
         |> assign(access_lists: access_lists |> Enum.map(fn acl -> map_ui_acl(acl, nil) end))}

      _error ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "You can't delete this access list. Plese remove it from the map first."
         )}
    end
  rescue
    _error ->
      {:noreply,
       socket
       |> put_flash(
         :error,
         "You can't delete this access list. Plese remove it from the map first."
       )}
  end

  def handle_event("delete-member", %{"id" => member_id} = _params, socket) do
    socket.assigns.members
    |> Enum.find(&(&1.id == member_id))
    |> WandererApp.Api.AccessListMember.destroy!()

    Phoenix.PubSub.broadcast(
      WandererApp.PubSub,
      "acls:#{socket.assigns.selected_acl_id}",
      {:acl_updated, %{acl_id: socket.assigns.selected_acl_id}}
    )

    {:noreply,
     socket
     |> assign(
       members:
         WandererApp.Api.AccessListMember.read_by_access_list!(%{
           access_list_id: socket.assigns.selected_acl_id
         })
     )}
  end

  @impl true
  def handle_event(
        "dropped",
        %{"draggedId" => dragged_id, "dropzoneId" => dropzone_id},
        %{assigns: %{access_list: access_list, members: members}} = socket
      ) do
    role_atom =
      [:admin, :manager, :member, :viewer, :blocked]
      |> Enum.find(fn role_atom -> to_string(role_atom) == dropzone_id end)

    case role_atom do
      nil ->
        {:noreply, socket}

      role_atom ->
        member =
          members
          |> Enum.find(&(&1.id == dragged_id))

        {:noreply, socket |> maybe_update_role(member, role_atom, access_list)}
    end
  end

  def handle_event("generate-api-key", _params, socket) do
    new_api_key = UUID.uuid4()
    new_params = Map.put(socket.assigns.form.params || %{}, "api_key", new_api_key)
    form = AshPhoenix.Form.validate(socket.assigns.form, new_params)
    {:noreply, assign(socket, form: form)}
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

  @impl true
  def handle_info(
        {"update_role", %{member_id: member_id, role: role}},
        %{assigns: %{access_list: access_list, members: members}} = socket
      ) do
    role_atom = role |> String.to_existing_atom()

    member =
      members
      |> Enum.find(&(&1.id == member_id))

    {:noreply, socket |> maybe_update_role(member, role_atom, access_list)}
  end

  @impl true
  def handle_info({:search, text}, socket) do
    active_character_id =
      socket.assigns.current_user.characters
      |> Enum.filter(fn character -> not is_nil(character.refresh_token) end)
      |> Enum.map(& &1.id)
      |> Enum.at(0)

    uniq_search_req_id = UUID.uuid4(:default)

    Task.async(fn ->
      {:ok, options} = search(active_character_id, text)

      {:search_results, uniq_search_req_id, options}
    end)

    {:noreply, socket |> assign(uniq_search_req_id: uniq_search_req_id)}
  end

  def handle_info(
        {ref, result},
        %{assigns: %{member_search_id: member_search_id, uniq_search_req_id: uniq_search_req_id}} =
          socket
      )
      when is_reference(ref) do
    Process.demonitor(ref, [:flush])

    case result do
      {:search_results, ^uniq_search_req_id, options} ->
        send_update(LiveSelect.Component, options: options, id: member_search_id)
        {:noreply, socket |> assign(member_search_options: options)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info(_event, socket), do: {:noreply, socket}

  defp maybe_update_role(
         socket,
         %{
           id: member_id,
           eve_character_id: eve_character_id,
           eve_corporation_id: eve_corporation_id,
           eve_alliance_id: eve_alliance_id
         } = member,
         role_atom,
         access_list
       )
       when not is_nil(eve_character_id) or
              ((not is_nil(eve_corporation_id) or not is_nil(eve_alliance_id)) and
                 role_atom not in [:admin, :manager]) do
    can_assign_role =
      cond do
        current_user_is_owner?(socket.assigns.current_user, access_list) ->
          true

        current_user_has_role?(socket.assigns.current_user, access_list, :admin) ->
          true

        not is_nil(eve_character_id) &&
          characters_has_roles?([eve_character_id], access_list, [:admin, :manager]) &&
            not current_user_has_role?(socket.assigns.current_user, access_list, :admin) ->
          false

        current_user_has_role?(socket.assigns.current_user, access_list, :manager) and
            role_atom in [:member, :viewer, :blocked] ->
          true

        true ->
          false
      end

    case can_assign_role do
      true ->
        member =
          member
          |> WandererApp.Api.AccessListMember.update_role!(%{role: role_atom})

        {:ok, _} =
          WandererApp.User.ActivityTracker.track_acl_event(:map_acl_member_updated, %{
            user_id: socket.assigns.current_user.id,
            acl_id: socket.assigns.selected_acl_id,
            member:
              member
              |> Map.take([:eve_character_id, :eve_corporation_id, :eve_alliance_id, :role])
          })

        :telemetry.execute([:wanderer_app, :acl, :member, :update], %{count: 1})

        Phoenix.PubSub.broadcast(
          WandererApp.PubSub,
          "acls:#{socket.assigns.selected_acl_id}",
          {:acl_updated, %{acl_id: socket.assigns.selected_acl_id}}
        )

        socket
        |> assign(
          :members,
          socket.assigns.members
          |> Enum.map(fn m -> if m.id == member_id, do: member, else: m end)
        )

      _ ->
        socket
        |> put_flash(:error, "You're not allowed to assign this role")
        |> push_navigate(to: ~p"/access-lists/#{socket.assigns.selected_acl_id}")
    end
  end

  defp maybe_update_role(
         socket,
         _member,
         _role_atom,
         _access_list
       ),
       do:
         socket
         |> put_flash(:info, "Only Characters can have Admin or Manager roles")
         |> push_navigate(to: ~p"/access-lists/#{socket.assigns.selected_acl_id}")

  defp characters_has_roles?(character_eve_ids, %{members: members} = _access_list, role_atoms),
    do:
      members
      |> Enum.any?(fn %{eve_character_id: eve_character_id, role: role} = _member ->
        eve_character_id in character_eve_ids and role in role_atoms
      end)

  defp current_user_is_owner?(current_user, access_list) do
    character_ids = current_user.characters |> Enum.map(& &1.id)

    access_list.owner_id in character_ids
  end

  defp current_user_has_role?(current_user, access_list, role_atom) do
    character_eve_ids = current_user.characters |> Enum.map(& &1.eve_id)

    characters_has_roles?(character_eve_ids, access_list, [role_atom])
  end

  defp can_add_members?(nil, _current_user), do: false

  defp can_add_members?(access_list, current_user) do
    user_character_eve_ids = current_user.characters |> Enum.map(& &1.eve_id)

    current_user_is_owner?(current_user, access_list) ||
      characters_has_roles?(user_character_eve_ids, access_list, [:admin, :manager])
  end

  defp can_delete_member?(
         %{eve_character_id: eve_character_id, role: role_atom} = _member,
         access_list,
         current_user
       ) do
    cond do
      current_user_is_owner?(current_user, access_list) ->
        true

      current_user_has_role?(current_user, access_list, :admin) ->
        true

      not is_nil(eve_character_id) &&
        characters_has_roles?([eve_character_id], access_list, [:admin, :manager]) &&
          not current_user_has_role?(current_user, access_list, :admin) ->
        false

      current_user_has_role?(current_user, access_list, :manager) and
          role_atom in [:member, :viewer, :blocked] ->
        true

      true ->
        false
    end
  end

  defp can_edit?(access_list, current_user) do
    character_eve_ids = current_user.characters |> Enum.map(& &1.eve_id)

    member = access_list.members |> Enum.find(&(&1.eve_character_id in character_eve_ids))

    current_user_is_owner?(current_user, access_list) or
      (not is_nil(member) and member.role == :admin)
  end

  defp broadcast_member_added_event(access_list_id, member) do
    case AclEventBroadcaster.broadcast_member_event(access_list_id, member, :acl_member_added) do
      :ok ->
        :ok

      {:error, broadcast_error} ->
        Logger.warning("Failed to broadcast ACL member added event: #{inspect(broadcast_error)}")
    end
  end

  defp add_member(
         socket,
         access_list_id,
         %{label: name, value: eve_id, character: true} = _member_option
       ) do
    case WandererApp.Api.AccessListMember.create(%{
           access_list_id: access_list_id,
           name: name,
           eve_character_id: eve_id,
           eve_alliance_id: nil,
           eve_corporation_id: nil
         }) do
      {:ok, member} ->
        broadcast_member_added_event(access_list_id, member)

        {:ok, _} =
          WandererApp.User.ActivityTracker.track_acl_event(:map_acl_member_added, %{
            user_id: socket.assigns.current_user.id,
            acl_id: access_list_id,
            member:
              member
              |> Map.take([:eve_character_id, :eve_corporation_id, :eve_alliance_id, :role])
          })

        :telemetry.execute([:wanderer_app, :acl, :member, :add], %{count: 1})

        {:ok, member}

      _ ->
        {:ok, nil}
    end
  end

  defp add_member(
         socket,
         access_list_id,
         %{label: name, value: eve_id, corporation: true} = _member_option
       ) do
    case WandererApp.Api.AccessListMember.create(%{
           access_list_id: access_list_id,
           name: name,
           eve_character_id: nil,
           eve_alliance_id: nil,
           eve_corporation_id: eve_id
         }) do
      {:ok, member} ->
        broadcast_member_added_event(access_list_id, member)

        {:ok, _} =
          WandererApp.User.ActivityTracker.track_acl_event(:map_acl_member_added, %{
            user_id: socket.assigns.current_user.id,
            acl_id: access_list_id,
            member:
              member
              |> Map.take([:eve_character_id, :eve_corporation_id, :eve_alliance_id, :role])
          })

        :telemetry.execute([:wanderer_app, :acl, :member, :add], %{count: 1})

        {:ok, member}

      _ ->
        {:ok, nil}
    end
  end

  defp add_member(
         socket,
         access_list_id,
         %{label: name, value: eve_id, alliance: true} = _member_option
       ) do
    case WandererApp.Api.AccessListMember.create(%{
           access_list_id: access_list_id,
           name: name,
           eve_character_id: nil,
           eve_corporation_id: nil,
           eve_alliance_id: eve_id,
           role: :viewer
         }) do
      {:ok, member} ->
        broadcast_member_added_event(access_list_id, member)

        {:ok, _} =
          WandererApp.User.ActivityTracker.track_acl_event(:map_acl_member_added, %{
            user_id: socket.assigns.current_user.id,
            acl_id: access_list_id,
            member:
              member
              |> Map.take([:eve_character_id, :eve_corporation_id, :eve_alliance_id, :role])
          })

        :telemetry.execute([:wanderer_app, :acl, :member, :add], %{count: 1})

        {:ok, member}

      error ->
        Logger.error(error)
        {:ok, nil}
    end
  end

  attr :disabled, :boolean, default: true
  attr :name, :string
  attr :icon, :string
  attr :title, :string

  def dropzone(assigns) do
    ~H"""
    <div
      class={[
        "dropzone stat text-center flex flex-1 items-center justify-center border-gray-500",
        classes("bg-grey-800": @disabled, "hover:bg-orange-600 hover:bg-opacity-30": not @disabled)
      ]}
      id={@name}
      data-dropzone={@name}
      title={@title}
    >
      <.icon name={@icon} class="w-6 h-6" />
    </div>
    """
  end

  slot(:option)

  def search_member_item(assigns) do
    ~H"""
    <div class="flex items-center">
      <div :if={@option.value != :loading} class="avatar">
        <div class="rounded-md w-12 h-12">
          <img src={search_member_icon_url(@option)} alt={@option.label} />
        </div>
      </div>
      <span :if={@option.value == :loading} <span class="loading loading-spinner loading-xs"></span>
      &nbsp; {@option.label}
    </div>
    """
  end

  def search_member_icon_url(%{character: true} = option),
    do: member_icon_url(%{eve_character_id: option.value})

  def search_member_icon_url(%{corporation: true} = option),
    do: member_icon_url(%{eve_corporation_id: option.value})

  def search_member_icon_url(%{alliance: true} = option),
    do: member_icon_url(%{eve_alliance_id: option.value})

  def search_member_icon_url(%{eve_id: eve_id} = _option),
    do: member_icon_url(%{eve_character_id: eve_id})

  defp search(character_id, search),
    do:
      WandererApp.Character.search(character_id,
        params: [search: search, categories: "character,alliance,corporation"]
      )

  defp map_user_character_info(%{eve_id: eve_id, label: label} = _character) do
    %{
      label: label,
      value: eve_id,
      character: true
    }
  end

  defp map_character(%{name: name, id: id, eve_id: eve_id} = _character) do
    %{label: name, value: id, id: id, eve_id: eve_id}
  end

  defp map_ui_acl(acl, selected_id) do
    acl |> Map.put(:selected, acl.id == selected_id)
  end
end
