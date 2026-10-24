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

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <ul :for={group <- @groups} class="border-t border-b border-gray-200 py-0">
        <li :for={character <- group.characters} id={"map-character-#{character.id}"}>
          <div class="flex items-center justify-between w-full space-x-2 p-1 hover:bg-gray-900">
            <.character_entry character={character} />
            <button
              :if={character.tracked}
              phx-click="untrack"
              phx-value-event-data={character.id}
              class="btn btn-sm btn-icon py-1"
            >
              <.icon name="hero-eye-slash" class="h-5 w-5" /> Untrack
            </button>

            <span :if={not character.tracked} class="text-white rounded-full px-2">
              Viewer
            </span>
          </div>
        </li>
      </ul>
    </div>
    """
  end

  attr(:character, :any, required: true)

  defp character_entry(assigns) do
    assigns = assign(assigns, :eve_status, eve_status(assigns.character.id))

    ~H"""
    <div class="flex flex-wrap items-center gap-3 text-sm">
      <div :if={@character.from} class="flex flex-col p-4 items-center gap-2">
        <span class="text-gray-400 text-xs">Mapper session since</span>
        <span class="text-green-500 rounded-full px-2 py-1 whitespace-nowrap">
          <.local_time id={@character.id} at={@character.from} />
        </span>
      </div>
      <span :if={is_nil(@character.from)} class="text-gray-400 px-2 py-1 whitespace-nowrap">
        No active session
      </span>

      <div class="avatar">
        <div class="rounded-md w-8 h-8">
          <img src={member_icon_url(@character.eve_id)} alt={@character.name} />
        </div>
      </div>
      <span class="whitespace-nowrap">{@character.name}</span>
      <span :if={@character.alliance_ticker} class="whitespace-nowrap">
        [{@character.alliance_ticker}]
      </span>
      <span :if={@character.corporation_ticker} class="whitespace-nowrap">
        [{@character.corporation_ticker}]
      </span>

      <span :if={@eve_status == :online} class="text-green-500 rounded-full px-2 py-1">
        EVE online
      </span>
      <span :if={@eve_status == :offline} class="text-red-500 rounded-full px-2 py-1">
        EVE offline
      </span>
      <span :if={@eve_status == :unknown} class="text-gray-400 rounded-full px-2 py-1">
        EVE status unknown
      </span>

      <span :if={@character.tracked} class="text-green-500 rounded-full px-2 py-1">
        Tracking enabled
      </span>

      <span
        :if={not @character.tracked}
        class="text-gray-400 rounded-full px-2 py-1 whitespace-nowrap"
      >
        Viewer (not tracked)
      </span>
    </div>
    """
  end

  @impl true
  def handle_event("undo", %{"event-data" => _event_data} = _params, socket),
    do: {:noreply, socket}

  defp eve_status(character_id) do
    case WandererApp.Character.get_character_state(character_id, false) do
      {:ok, %{is_online: true}} -> :online
      {:ok, %{is_online: false}} -> :offline
      _ -> :unknown
    end
  end
end
