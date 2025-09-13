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

  def get_all_by_map(map_id) do
    WandererApp.Api.MapSystem.read_all_by_map(%{map_id: map_id})
  end

  def get_all_by_maps(map_ids) when is_list(map_ids) do
    # Since there's no bulk query, we need to query each map individually
    map_ids
    |> Enum.flat_map(fn map_id ->
      case get_all_by_map(map_id) do
        {:ok, systems} -> systems
        _ -> []
      end
    end)
    |> Enum.uniq_by(& &1.solar_system_id)
  end

  def get_visible_by_map(map_id) do
    WandererApp.Api.MapSystem.read_visible_by_map(%{map_id: map_id})
  end

  def remove_from_map(map_id, solar_system_id) do
    WandererApp.Api.MapSystem.read_by_map_and_solar_system!(%{
      map_id: map_id,
      solar_system_id: solar_system_id
    })
    |> WandererApp.Api.MapSystem.update_visible(%{visible: false})
  rescue
    error ->
      {:error, error}
  end

  def cleanup_labels!(%{labels: labels} = system, opts) do
    store_custom_labels? =
      Keyword.get(opts, :store_custom_labels)

    labels = get_filtered_labels(labels, store_custom_labels?)

    system
    |> update_labels!(%{
      labels: labels
    })
  end

  def cleanup_tags(system) do
    system
    |> WandererApp.Api.MapSystem.update_tag(%{
      tag: nil
    })
  end

  def cleanup_tags!(system) do
    system
    |> WandererApp.Api.MapSystem.update_tag!(%{
      tag: nil
    })
  end

  def cleanup_temporary_name(system) do
    system
    |> WandererApp.Api.MapSystem.update_temporary_name(%{
      temporary_name: nil
    })
  end

  def cleanup_temporary_name!(system) do
    system
    |> WandererApp.Api.MapSystem.update_temporary_name!(%{
      temporary_name: nil
    })
  end

  def cleanup_linked_sig_eve_id!(system) do
    system
    |> WandererApp.Api.MapSystem.update_linked_sig_eve_id!(%{
      linked_sig_eve_id: nil
    })
  end

  def get_filtered_labels(labels, true) when is_binary(labels) do
    labels
    |> Jason.decode!()
    |> case do
      %{"customLabel" => customLabel} when is_binary(customLabel) ->
        %{"customLabel" => customLabel, "labels" => []}
        |> Jason.encode!()

      _ ->
        nil
    end
  end

  def get_filtered_labels(_, _store_custom_labels), do: nil

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

  def update_temporary_name(system, update) do
    system
    |> WandererApp.Api.MapSystem.update_temporary_name(update)
  end

  def update_labels(system, update),
    do:
      system
      |> WandererApp.Api.MapSystem.update_labels(update)

  def update_labels!(system, update),
    do:
      system
      |> WandererApp.Api.MapSystem.update_labels!(update)

  def update_linked_sig_eve_id(system, update),
    do:
      system
      |> WandererApp.Api.MapSystem.update_linked_sig_eve_id(update)

  def update_linked_sig_eve_id!(system, update),
    do:
      system
      |> WandererApp.Api.MapSystem.update_linked_sig_eve_id!(update)

  def update_position(system, update),
    do:
      system
      |> WandererApp.Api.MapSystem.update_position(update)

  def update_position!(system, update),
    do:
      system
      |> WandererApp.Api.MapSystem.update_position!(update)

  def update_visible(system, update),
    do:
      system
      |> WandererApp.Api.MapSystem.update_visible(update)

  def update_visible!(system, update),
    do:
      system
      |> WandererApp.Api.MapSystem.update_visible!(update)
end
