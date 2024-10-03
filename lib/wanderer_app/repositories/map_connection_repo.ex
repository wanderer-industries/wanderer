defmodule WandererApp.MapConnectionRepo do
  use WandererApp, :repository

  require Logger

  @logger Application.compile_env(:wanderer_app, :logger)

  def get_by_map(map_id),
    do: WandererApp.Api.MapConnection.read_by_map(%{map_id: map_id})

  def get_by_locations(map_id, solar_system_source, solar_system_target) do
    WandererApp.Api.MapConnection.by_locations(%{map_id: map_id, solar_system_source: solar_system_source, solar_system_target: solar_system_target})
    |> case do
      {:ok, connections} ->
        {:ok, connections}

      {:error, %Ash.Error.Query.NotFound{}} ->
        {:ok, []}

      {:error, error} ->
        @logger.error("Failed to get connections: #{inspect(error, pretty: true)}")
        {:error, error}
    end
  end

  def create!(connection), do: connection |> WandererApp.Api.MapConnection.create!()

  def destroy!(connection), do:
    connection |> WandererApp.Api.MapConnection.destroy!()

  def bulk_destroy!(connections) do
    connections
    |> WandererApp.Api.MapConnection.destroy!()
    |> case do
      %Ash.BulkResult{status: :success} ->
        :ok
      error ->
        error
    end
  end

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
end
