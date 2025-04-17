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
        # Get raw activity data from the domain logic
        result =
          WandererApp.Character.Activity.process_character_activity(map_id, current_user)

        # Group activities by user_id and summarize
        summarized_result =
          result
          |> Enum.group_by(fn activity ->
            # Get user_id from the character
            activity.character.user_id
          end)
          |> Enum.map(fn {_user_id, user_activities} ->
            # Get the most active or followed character for this user
            representative_activity =
              user_activities
              |> Enum.max_by(fn activity ->
                activity.passages + activity.connections + activity.signatures
              end)

            # Sum up all activities for this user
            total_passages = Enum.sum(Enum.map(user_activities, & &1.passages))
            total_connections = Enum.sum(Enum.map(user_activities, & &1.connections))
            total_signatures = Enum.sum(Enum.map(user_activities, & &1.signatures))

            # Map the character data for the UI here
            mapped_character =
              representative_activity.character
              |> MapEventHandler.map_ui_character_stat()

            # Return summarized activity with the mapped character
            %{
              character: mapped_character,
              passages: total_passages,
              connections: total_connections,
              signatures: total_signatures,
              timestamp: representative_activity.timestamp
            }
          end)

        {:character_activity_data, summarized_result}
      rescue
        e ->
          Logger.error("Error processing character activity: #{inspect(e)}")
          Logger.error("#{Exception.format_stacktrace()}")
          {:character_activity_data, []}
      end
    end)

    {:noreply,
     socket
     |> MapEventHandler.push_map_event(
       "character_activity_data",
       %{activity: [], loading: true}
     )}
  end

  def handle_ui_event(event, body, socket),
    do: MapCoreEventHandler.handle_ui_event(event, body, socket)
end
