defmodule WandererAppWeb.MapStructuresEventHandler do
  use WandererAppWeb, :live_component
  use Phoenix.Component
  require Logger

  alias WandererApp.Api.MapSystem
  alias WandererApp.Structure

  def handle_ui_event("get_structures", %{"system_id" => solar_system_id}, %{assigns: %{map_id: map_id}} = socket) do
    case MapSystem.read_by_map_and_solar_system(%{
           map_id: map_id,
           solar_system_id: String.to_integer(solar_system_id)
         }) do
      {:ok, system} ->
        {:reply, %{structures: get_system_structures(system.id)}, socket}

      _ ->
        {:reply, %{structures: []}, socket}
    end
  end

  def handle_ui_event(
        "update_structures",
        %{
          "system_id" => solar_system_id,
          "added" => added_structures,
          "updated" => updated_structures,
          "removed" => removed_structures
        },
        %{
          assigns: %{
            map_id: map_id,
            user_characters: user_characters,
            user_permissions: %{update_system: true}
          }
        } = socket
      ) do
    with {:ok, system} <- get_map_system(map_id, solar_system_id),
         :ok <- ensure_user_has_tracked_character(user_characters) do
      Logger.debug(fn ->
        "[handle_ui_event:update_structures] loaded map_system =>\n" <>
          inspect(system, pretty: true)
      end)

      Structure.update_structures(
        system,
        added_structures,
        updated_structures,
        removed_structures,
        user_characters
      )

      broadcast_structures_updated(system, map_id)

      {:reply, %{structures: get_system_structures(system.id)}, socket}
    else
      :no_tracked_character ->
        {:reply,
         %{structures: []},
         put_flash(socket, :error, "You must have at least one tracked character to work with structures.")}

      _ ->
        {:noreply, socket}
    end
  end

  defp get_map_system(map_id, solar_system_id) do
    case MapSystem.read_by_map_and_solar_system(%{
           map_id: map_id,
           solar_system_id: String.to_integer(solar_system_id)
         }) do
      {:ok, system} -> {:ok, system}
      _ -> :error
    end
  end

  defp ensure_user_has_tracked_character(user_characters) do
    if Enum.empty?(user_characters) or is_nil(List.first(user_characters)) do
      :no_tracked_character
    else
      :ok
    end
  end

  defp broadcast_structures_updated(system, map_id) do
    Phoenix.PubSub.broadcast!(
      WandererApp.PubSub,
      map_id,
      %{event: :structures_updated, payload: system.solar_system_id}
    )
  end

  def get_system_structures(system_id) do
    results =
      WandererApp.Api.MapSystemStructure.by_system_id!(system_id)
      |> Enum.map(fn record ->
        record
        |> Map.take([
          :id,
          :system_id,
          :solar_system_id,
          :solar_system_name,
          :structure_type_id,
          :character_eve_id,
          :name,
          :notes,
          :owner_name,
          :owner_ticker,
          :owner_id,
          :status,
          :end_time,
          :inserted_at,
          :updated_at,
          :structure_type
        ])
        |> Map.update!(:inserted_at, &Calendar.strftime(&1, "%Y/%m/%d %H:%M:%S"))
        |> Map.update!(:updated_at, &Calendar.strftime(&1, "%Y/%m/%d %H:%M:%S"))
      end)

    Logger.debug(fn ->
      "[get_system_structures] => returning:\n" <> inspect(results, pretty: true)
    end)

    results
  end
end
