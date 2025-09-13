defmodule WandererAppWeb.AclMember do
  use WandererAppWeb, :live_component

  use LiveViewEvents

  @roles [
    :admin,
    :manager,
    :member,
    :viewer,
    :blocked
  ]

  @impl true
  def mount(socket) do
    {:ok, socket |> assign(roles: get_roles())}
  end

  @impl true
  def update(
        %{
          member: member
        } = assigns,
        socket
      ) do
    socket = handle_info_or_assign(socket, assigns)

    {:ok,
     socket
     |> assign(member: member, form: to_form(%{"role" => member.role}))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="flex items-center gap-2">
      <.icon :if={not is_nil(@member.role)} name={member_role_icon(@member.role)} class="w-6 h-6" />
      <.form :let={f} id={"role_form_" <> @id} for={@form} phx-change="select" phx-target={@myself}>
        <.input
          type="select"
          field={f[:role]}
          class="select h-8 min-h-[0px] !pt-1 !pb-1 text-sm bg-neutral-900"
          wrapper_class="w-[60px] mr-16"
          placeholder="Select a role..."
          options={Enum.map(@roles, fn role -> {role.label, role.value} end)}
        />
      </.form>
      <div class="avatar">
        <div class="rounded-md w-8 h-8">
          <img src={member_icon_url(@member)} alt={@member.name} />
        </div>
      </div>
      {@member.name}
    </div>
    """
  end

  @impl true
  def handle_event(
        "select",
        %{"role" => role} = _params,
        %{assigns: %{event_name: event_name, member: member, notify_to: notify_to}} = socket
      ) do
    notify_to(notify_to, event_name, %{
      member_id: member.id,
      role: role
    })

    {:noreply, socket}
  end

  def member_role_icon(:admin), do: "hero-user-group-solid"
  def member_role_icon(:manager), do: "hero-academic-cap-solid"
  def member_role_icon(:member), do: "hero-user-solid"
  def member_role_icon(:viewer), do: "hero-eye-solid"
  def member_role_icon(:blocked), do: "hero-no-symbol-solid text-red-500"
  def member_role_icon(_), do: "hero-cake-solid"

  def member_role_title(:admin), do: "Admin"
  def member_role_title(:manager), do: "Manager"
  def member_role_title(:member), do: "Member"
  def member_role_title(:viewer), do: "Viewer"
  def member_role_title(:blocked), do: "-blocked-"
  def member_role_title(_), do: "-"

  defp get_roles(), do: @roles |> Enum.map(&%{label: member_role_title(&1), value: &1})
end
