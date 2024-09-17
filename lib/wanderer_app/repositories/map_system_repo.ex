defmodule WandererApp.MapSystemRepo do
  use WandererApp, :repository

  def create(system) do
    system |> WandererApp.Api.MapSystem.create()
  end

  def get_by_map_and_solar_system_id(map_id, solar_system_id) do
    WandererApp.Api.MapSystem.by_map_id_and_solar_system_id(map_id, solar_system_id)
    |> case do
      {:ok, system} ->
        {:ok, system}

      _ ->
        {:error, :not_found}
    end
  end

  def get_all_by_map(map_id),
    do: WandererApp.Api.MapSystem.read_all_by_map(%{map_id: map_id})

  def get_visible_by_map(map_id),
    do: WandererApp.Api.MapSystem.read_visible_by_map(%{map_id: map_id})

  def remove_from_map(map_id, solar_system_id) do
    WandererApp.Api.MapSystem.read_by_map_and_solar_system!(%{
      map_id: map_id,
      solar_system_id: solar_system_id
    })
    |> WandererApp.Api.MapSystem.update_labels!(%{
      labels: nil
    })
    |> WandererApp.Api.MapSystem.update_tag!(%{
      tag: nil
    })
    |> WandererApp.Api.MapSystem.update_visible(%{visible: false})
  rescue
    error ->
      {:error, error}
  end

  def update_name(system, update),
    do:
      system
      |> WandererApp.Api.MapSystem.update_name(update)

  def update_description(system, update),
    do:
      system
      |> WandererApp.Api.MapSystem.update_description(update)

  def update_locked(system, update),
    do:
      system
      |> WandererApp.Api.MapSystem.update_locked(update)

  def update_status(system, update),
    do:
      system
      |> WandererApp.Api.MapSystem.update_status(update)

  def update_tag(system, update),
    do:
      system
      |> WandererApp.Api.MapSystem.update_tag(update)

  def update_labels(system, update),
    do:
      system
      |> WandererApp.Api.MapSystem.update_labels(update)

  def update_position(system, update),
    do:
      system
      |> WandererApp.Api.MapSystem.update_position(update)
end
