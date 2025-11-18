defmodule WandererApp.MapRepo do
  use WandererApp, :repository

  @default_map_options %{
    "layout" => "left_to_right",
    "store_custom_labels" => "false",
    "show_linked_signature_id" => "false",
    "show_linked_signature_id_temp_name" => "false",
    "show_temp_system_name" => "false",
    "restrict_offline_showing" => "false",
    "allowed_copy_for" => "admin_map",
    "allowed_paste_for" => "add_system"
  }

  def get(map_id, relationships \\ []) do
    map_id
    |> WandererApp.Api.Map.by_id()
    |> case do
      {:ok, map} ->
        map |> load_relationships(relationships)

      _ ->
        {:error, :not_found}
    end
  end

  def get_by_slug_with_permissions(map_slug, current_user),
    do:
      map_slug
      |> WandererApp.Api.Map.get_map_by_slug()
      |> load_user_permissions(current_user)

  @doc """
  Safely retrieves a map by slug, handling the case where multiple maps
  with the same slug exist (database integrity issue).

  Returns:
  - `{:ok, map}` - Single map found
  - `{:error, :multiple_results}` - Multiple maps found (logs error)
  - `{:error, :not_found}` - No map found
  - `{:error, reason}` - Other error
  """
  def get_map_by_slug_safely(slug) do
    try do
      map = WandererApp.Api.Map.get_map_by_slug!(slug)
      {:ok, map}
    rescue
      error in Ash.Error.Invalid.MultipleResults ->
        Logger.error("Multiple maps found with slug '#{slug}' - database integrity issue",
          slug: slug,
          error: inspect(error)
        )

        # Emit telemetry for monitoring
        :telemetry.execute(
          [:wanderer_app, :map, :duplicate_slug_detected],
          %{count: 1},
          %{slug: slug, operation: :get_by_slug}
        )

        # Return error - caller should handle this appropriately
        {:error, :multiple_results}

      error in Ash.Error.Query.NotFound ->
        Logger.debug("Map not found with slug: #{slug}")
        {:error, :not_found}

      error ->
        Logger.error("Error retrieving map by slug",
          slug: slug,
          error: inspect(error)
        )

        {:error, :unknown_error}
    end
  end

  def load_relationships(map, []), do: {:ok, map}

  def load_relationships(map, relationships), do: map |> Ash.load(relationships)

  defp load_user_permissions({:ok, map}, current_user),
    do:
      map
      |> Ash.load([:acls, :user_permissions], actor: current_user)

  defp load_user_permissions(error, _current_user), do: error

  def update_hubs(map_id, hubs) do
    map_id
    |> WandererApp.Api.Map.by_id()
    |> case do
      {:ok, map} ->
        map |> WandererApp.Api.Map.update_hubs(%{hubs: hubs})

      _ ->
        {:error, :map_not_found}
    end
  end

  def update_options(map, options),
    do:
      map
      |> WandererApp.Api.Map.update_options(%{options: Jason.encode!(options)})

  def options_to_form_data(%{options: options} = _map_options) when not is_nil(options),
    do: {:ok, @default_map_options |> Map.merge(Jason.decode!(options))}

  def options_to_form_data(_), do: {:ok, @default_map_options}

  def options_to_form_data!(options) do
    {:ok, data} = options_to_form_data(options)
    data
  end
end
