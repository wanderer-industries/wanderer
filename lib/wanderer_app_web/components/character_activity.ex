defmodule WandererAppWeb.CharacterActivity do
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

  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.table class="!max-h-[80vh] !overflow-y-auto" id="activity-tbl" rows={@activity}>
        <:col :let={row} label="Character">
          <.character_item character={row.character} />
        </:col>
        <:col :let={row} label="Passages">
          <%= row.count %>
        </:col>
      </.table>
    </div>
    """
  end

  def character_item(assigns) do
    ~H"""
    <div class="flex items-center gap-3">
      <div class="avatar">
        <div class="rounded-md w-12 h-12">
          <img src={member_icon_url(@character.eve_id)} alt={@character.name} />
        </div>
      </div>
      <%= @character.name %>
    </div>
    """
  end
end
