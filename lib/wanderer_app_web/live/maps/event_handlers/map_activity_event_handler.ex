defmodule WandererAppWeb.MapActivityEventHandler do
  @moduledoc """
  Handles map activity events and updates for the live view.
  """
  use WandererAppWeb, :live_component
  use Phoenix.Component
  require Logger

  alias WandererAppWeb.{MapEventHandler, MapCoreEventHandler}

  def handle_server_event(
        %{
          event: event,
          payload: {:activity_data, activity_data}
        } = _full_event,
        socket
      )
      when event in [:character_activity, :character_activity_data] do
    socket
    |> MapEventHandler.push_map_event(
      "character_activity_data",
      %{
        activity: activity_data,
        loading: false
      }
    )
  end

  # Fallback for non-tagged activity data (for backward compatibility)
  def handle_server_event(
        %{
          event: event,
          payload: activity_data
        } = _full_event,
        socket
      )
      when event in [:character_activity, :character_activity_data] do
    socket
    |> MapEventHandler.push_map_event(
      "character_activity_data",
      %{
        activity: activity_data,
        loading: false
      }
    )
  end

  def handle_server_event(event, socket),
    do: MapCoreEventHandler.handle_server_event(event, socket)

  def handle_ui_event("hide_activity", _, socket),
    do: {:noreply, socket |> assign(show_activity?: false)}

  def handle_ui_event(event, body, socket),
    do: MapCoreEventHandler.handle_ui_event(event, body, socket)
end
