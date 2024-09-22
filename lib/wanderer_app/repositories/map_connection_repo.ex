defmodule WandererApp.MapConnectionRepo do
  use WandererApp, :repository

  def get_by_map(map_id),
    do: WandererApp.Api.MapConnection.read_by_map(%{map_id: map_id})

  def create!(connection), do: connection |> WandererApp.Api.MapConnection.create!()

  def destroy!(connection), do: connection |> WandererApp.Api.MapConnection.destroy!()

  def update_time_status(connection, update),
    do:
      connection
      |> WandererApp.Api.MapConnection.update_time_status(update)

  def update_mass_status(connection, update),
    do:
      connection
      |> WandererApp.Api.MapConnection.update_mass_status(update)

  def update_ship_size_type(connection, update),
    do:
      connection
      |> WandererApp.Api.MapConnection.update_ship_size_type(update)

  def update_locked(connection, update),
    do:
      connection
      |> WandererApp.Api.MapConnection.update_locked(update)

  def update_custom_info(connection, update),
    do:
      connection
      |> WandererApp.Api.MapConnection.update_custom_info(update)
end
