defmodule WandererAppWeb.MapPicker do
  use WandererAppWeb, :live_component

  use LiveViewEvents

  @impl true
  def mount(socket) do
    socket =
      socket
      |> assign(form: to_form(%{"map_slug" => nil}))

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

    {:ok,
     socket
     |> assign(form: to_form(%{"map_slug" => map_slug}))
     |> assign_async(:maps, fn ->
       get_available_maps(current_user)
     end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.form
        :let={f}
        :if={not is_nil(assigns |> Map.get(:maps))}
        for={@form}
        phx-change="select"
        phx-target={@myself}
      >
        <.async_result :let={maps} assign={@maps}>
          <:loading><span class="loading loading-dots loading-xs" /></:loading>
          <:failed :let={reason}>{reason}</:failed>
          <.input
            :if={maps}
            type="select"
            field={f[:map_slug]}
            class="select h-8 min-h-[10px] !pt-1 !pb-1 text-sm bg-neutral-900"
            placeholder="Select a map..."
            options={Enum.map(@maps.result, fn map -> {map.label, map.value} end)}
          />
        </.async_result>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("select", %{"map_slug" => map_slug} = _params, socket) do
    notify_to(socket.assigns.notify_to, socket.assigns.event_name, map_slug)

    {:noreply, socket}
  end

  defp get_available_maps(current_user) do
    {:ok, maps} =
      current_user
      |> WandererApp.Maps.get_available_maps()

    {:ok, %{maps: maps |> Enum.sort_by(& &1.name, :asc) |> Enum.map(&map_map/1)}}
  end

  defp map_map(%{name: name, slug: slug} = _map),
    do: %{label: name, value: slug}
end
