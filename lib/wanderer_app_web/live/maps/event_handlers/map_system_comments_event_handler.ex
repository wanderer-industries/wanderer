defmodule WandererAppWeb.MapSystemCommentsEventHandler do
  use WandererAppWeb, :live_component
  use Phoenix.Component
  require Logger

  alias WandererAppWeb.{MapEventHandler, MapCoreEventHandler}

  def handle_server_event(
        %{
          event: :system_comment_added,
          payload: %{solar_system_id: solar_system_id, comment: comment}
        },
        socket
      ),
      do:
        socket
        |> MapEventHandler.push_map_event("system_comment_added", %{
          solarSystemId: solar_system_id,
          comment: comment |> map_system_comment()
        })

  def handle_server_event(
        %{
          event: :system_comment_removed,
          payload: %{solar_system_id: solar_system_id, comment_id: comment_id}
        },
        socket
      ),
      do:
        socket
        |> MapEventHandler.push_map_event("system_comment_removed", %{
          solarSystemId: solar_system_id,
          commentId: comment_id
        })

  def handle_server_event(event, socket),
    do: MapCoreEventHandler.handle_server_event(event, socket)

  def handle_ui_event(
        "addSystemComment",
        %{"solarSystemId" => solar_system_id, "value" => text} = _event,
        %{
          assigns: %{
            current_user: current_user,
            has_tracked_characters?: true,
            map_id: map_id,
            tracked_character_ids: tracked_character_ids,
            user_permissions: %{add_system: true}
          }
        } =
          socket
      ) do
    map_id
    |> WandererApp.Map.Server.add_system_comment(
      %{
        solar_system_id: solar_system_id,
        text: text
      },
      current_user.id,
      tracked_character_ids |> List.first()
    )

    {:noreply, socket}
  end

  def handle_ui_event(
        "getSystemComments",
        %{"solarSystemId" => solar_system_id} = _event,
        %{
          assigns: %{
            current_user: current_user,
            has_tracked_characters?: true,
            map_id: map_id,
            tracked_character_ids: tracked_character_ids,
            user_permissions: %{add_system: true}
          }
        } =
          socket
      ) do
    system =
      WandererApp.Map.find_system_by_location(map_id, %{
        solar_system_id: solar_system_id |> String.to_integer()
      })

    {:ok, comments} = WandererApp.MapSystemCommentRepo.get_by_system(system.id)

    comments =
      comments
      |> Enum.map(fn c -> c |> Ash.load!([:character, :system]) end)
      |> Enum.map(&map_system_comment/1)

    {:reply, %{comments: comments}, socket}
  end

  def handle_ui_event(
        "deleteSystemComment",
        comment_id,
        %{
          assigns: %{
            map_id: map_id,
            current_user: current_user,
            tracked_character_ids: tracked_character_ids,
            has_tracked_characters?: true,
            user_permissions: %{update_system: true}
          }
        } =
          socket
      ) do
    map_id
    |> WandererApp.Map.Server.remove_system_comment(
      comment_id,
      current_user.id,
      tracked_character_ids |> List.first()
    )

    {:noreply, socket}
  end

  def map_system_comment(nil), do: nil

  def map_system_comment(
        %{
          id: id,
          character: character,
          system: system,
          text: text,
          updated_at: updated_at
        } = _comment
      ) do
    %{
      id: id,
      characterEveId: character.eve_id,
      solarSystemId: system.solar_system_id,
      text: text,
      updated_at: updated_at
    }
  end
end
