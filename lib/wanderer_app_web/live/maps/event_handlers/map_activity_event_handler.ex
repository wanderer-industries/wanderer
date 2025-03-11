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
          event: :character_activity_data,
          payload: activity_data
        },
        socket
      ) do
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

  def handle_ui_event(
        "show_activity",
        _,
        %{assigns: %{map_id: map_id, current_user: current_user}} = socket
      ) do
    Task.async(fn ->
      try do
        result =
          WandererApp.Character.Activity.process_character_activity(map_id, current_user)

        {:activity_data,
         result
         |> Enum.map(fn activity ->
           activity
           |> Map.take([:passages, :connections, :signatures, :timestamp])
           |> Map.put(:character, activity.character |> MapEventHandler.map_ui_character_stat())
         end)}
      rescue
        e ->
          Logger.error("Error processing character activity: #{inspect(e)}")
          Logger.error("#{Exception.format_stacktrace()}")
          {:activity_data, []}
      end
    end)

    {:noreply,
     socket
     |> MapEventHandler.push_map_event(
       "character_activity_data",
       %{activity: [], loading: true}
     )}
  end

  def handle_ui_event("hide_activity", _, socket),
    do: {:noreply, socket |> assign(show_activity?: false)}

  def handle_ui_event(event, body, socket),
    do: MapCoreEventHandler.handle_ui_event(event, body, socket)
end
