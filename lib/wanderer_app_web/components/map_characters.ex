defmodule WandererAppWeb.MapCharacters do
  use WandererAppWeb, :live_component
  use LiveViewEvents

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(
        assigns,
        socket
      ) do
    {:ok,
     socket
     |> handle_info_or_assign(assigns)}
  end

  # attr(:groups, :any, required: true)
  # attr(:character_settings, :any, required: true)

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <ul :for={group <- @groups} class="space-y-4 border-t border-b border-gray-200 py-4">
        <li :for={character <- group.characters}>
          <div class="flex items-center justify-between w-full space-x-2 p-1 hover:bg-gray-900">
            <.character_entry character={character} character_settings={@character_settings} />
            <button
              phx-click="untrack"
              phx-value-event-data={character.id}
              class="btn btn-sm btn-icon"
            >
              <.icon name="hero-eye-slash" class="h-5 w-5" /> Untrack
            </button>
          </div>
        </li>
      </ul>
    </div>
    """
  end

  attr(:character, :any, required: true)
  attr(:character_settings, :any, required: true)

  defp character_entry(assigns) do
    ~H"""
    <div class="flex items-center gap-3 text-sm w-[450px]">
      <span
        :if={is_tracked?(@character.id, @character_settings)}
        class="text-green-500 rounded-full px-2 py-1"
      >
        Tracked
      </span>
      <div class="avatar">
        <div class="rounded-md w-8 h-8">
          <img src={member_icon_url(@character.eve_id)} alt={@character.name} />
        </div>
      </div>
      <span><%= @character.name %></span>
      <span :if={@character.alliance_ticker}>[<%= @character.alliance_ticker %>]</span>
      <span :if={@character.corporation_ticker}>[<%= @character.corporation_ticker %>]</span>
    </div>
    """
  end

  @impl true
  def handle_event("undo", %{"event-data" => _event_data} = _params, socket) do
    # notify_to(socket.assigns.notify_to, socket.assigns.event_name, map_slug)

    {:noreply, socket}
  end

  defp is_tracked?(character_id, character_settings) do
    Enum.any?(character_settings, fn setting ->
      setting.character_id == character_id && setting.tracked
    end)
  end

end
