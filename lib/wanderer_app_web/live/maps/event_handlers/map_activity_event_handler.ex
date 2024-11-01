defmodule WandererAppWeb.MapActivityEventHandler do
  use WandererAppWeb, :live_component
  use Phoenix.Component
  require Logger

  alias WandererAppWeb.{MapEventHandler, MapCoreEventHandler}

  def handle_server_event(
        %{
          event: :character_activity,
          payload: character_activity
        },
        socket
      ),
      do: socket |> assign(:character_activity, character_activity)

  def handle_server_event(event, socket),
    do: MapCoreEventHandler.handle_server_event(event, socket)

  def handle_ui_event("show_activity", _, %{assigns: %{map_id: map_id}} = socket) do
    Task.async(fn ->
      {:ok, character_activity} = map_id |> get_character_activity()

      {:character_activity, character_activity}
    end)

    {:noreply,
     socket
     |> assign(:show_activity?, true)}
  end

  def handle_ui_event("hide_activity", _, socket),
    do: {:noreply, socket |> assign(show_activity?: false)}

  def handle_ui_event(event, body, socket),
    do: MapCoreEventHandler.handle_ui_event(event, body, socket)

  defp get_character_activity(map_id) do
    {:ok, jumps} = WandererApp.Api.MapChainPassages.by_map_id(%{map_id: map_id})

    jumps =
      jumps
      |> Enum.map(fn p ->
        %{p | character: p.character |> MapEventHandler.map_ui_character_stat()}
      end)

    {:ok, %{jumps: jumps}}
  end
end
