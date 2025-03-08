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
      ) do
    socket
    |> MapEventHandler.push_map_event(
      "character_activity_data",
      %{activity: character_activity}
    )
  end

  def handle_server_event(
        %{event: :character_activity_data, payload: activity_data},
        socket
      ) do
    socket
    |> MapEventHandler.push_map_event(
      "character_activity_data",
      %{activity: activity_data, loading: false}
    )
  end

  def handle_server_event(event, socket),
    do: MapCoreEventHandler.handle_server_event(event, socket)

  def handle_ui_event("hide_activity", _, socket),
    do: {:noreply, socket |> assign(show_activity?: false)}

  def handle_ui_event(event, body, socket),
    do: MapCoreEventHandler.handle_ui_event(event, body, socket)
end
