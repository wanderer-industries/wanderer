defmodule WandererApp.Map.Operations do
  @moduledoc """
  Orchestrates map systems and connections.
  Centralizes cross-repo logic for controllers, templates, and batch operations.
  """

  require Logger

  alias WandererApp.{
    MapRepo,
    MapSystemRepo,
    MapConnectionRepo,
    MapCharacterSettingsRepo,
    MapUserSettingsRepo
  }
  alias WandererApp.Map.Server
  alias WandererApp.Character
  alias WandererApp.Character.TrackingUtils

  @doc """
  Fetch main character ID for the map owner.

  Returns {:ok, %{id: character_id, user_id: user_id}} on success
  Returns {:error, reason} on failure
  """
  @spec get_owner_character_id(String.t()) :: {:ok, %{id: term(), user_id: term()}} | {:error, String.t()}
  def get_owner_character_id(map_id) do
    Logger.info("Resolving main character for map #{map_id}")

    with {:ok, owner} <- fetch_map_owner(map_id),
         {:ok, char_ids} <- fetch_character_ids(map_id),
         {:ok, characters} <- load_characters(char_ids),
         {:ok, user_settings} <- MapUserSettingsRepo.get(map_id, owner.id),
         {:ok, main} <- TrackingUtils.get_main_character(user_settings, characters, characters) do
      {:ok, %{id: main.id, user_id: main.user_id}}
    else
      {:error, msg} ->
        Logger.warn("get_owner_character_id failed: #{msg}")
        {:error, msg}

      error ->
        Logger.error("Unexpected error in get_owner_character_id: #{inspect(error)}")
        {:error, "Failed to resolve main character"}
    end
  end

  defp fetch_map_owner(map_id) do
    case MapRepo.get(map_id, [:owner]) do
      {:ok, %{owner: %_{} = owner}} -> {:ok, owner}
      {:ok, %{owner: nil}} -> {:error, "Map has no owner"}
      {:error, _} -> {:error, "Map not found"}
    end
  end

  defp fetch_character_ids(map_id) do
    case MapCharacterSettingsRepo.get_all_by_map(map_id) do
      {:ok, settings} when is_list(settings) and length(settings) > 0 -> {:ok, Enum.map(settings, & &1.character_id)}
      {:ok, []} -> {:error, "No character settings found"}
      {:error, _} -> {:error, "Failed to fetch character settings"}
    end
  end

  defp load_characters(ids) when is_list(ids) do
    ids
    |> Enum.map(&Character.get_character!/1)
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> {:error, "No valid characters found"}
      chars -> {:ok, chars}
    end
  end

  @doc "List visible systems"
  @spec list_systems(String.t()) :: [any()]
  def list_systems(map_id) do
    case MapSystemRepo.get_visible_by_map(map_id) do
      {:ok, systems} -> systems
      _ -> []
    end
  end

  @doc "Get a specific system"
  @spec get_system(String.t(), integer()) :: {:ok, any()} | {:error, :not_found}
  def get_system(map_id, sid) do
    MapSystemRepo.get_by_map_and_solar_system_id(map_id, sid)
  end

  @doc "Create or update a system in a map"
  @spec create_system(String.t(), map()) :: {:ok, any()} | {:error, String.t()}
  def create_system(map_id, params) do
    with {:ok, %{id: char_id, user_id: user_id}} <- get_owner_character_id(map_id),
         {:ok, system_id} <- fetch_system_id(params),
         coords <- normalize_coordinates(params),
         :ok <- Server.add_system(map_id, %{solar_system_id: system_id, coordinates: coords}, user_id, char_id),
         {:ok, system} <- MapSystemRepo.get_by_map_and_solar_system_id(map_id, system_id) do
      {:ok, system}
    else
      {:error, reason} when is_binary(reason) ->
        {:error, reason}
      error ->
        Logger.error("Unable to create system #{inspect(params)}: #{inspect(error)}")
        {:error, "Unable to create system"}
    end
  end

  @doc "Update attributes of an existing system"
  @spec update_system(String.t(), integer(), map()) :: {:ok, any()} | {:error, String.t()}
  def update_system(map_id, system_id, attrs) do
    # Fetch current system to get its position if not provided
    with {:ok, current_system} <- MapSystemRepo.get_by_map_and_solar_system_id(map_id, system_id),
         x <- Map.get(attrs, "position_x", Map.get(attrs, :position_x, current_system.position_x)),
         y <- Map.get(attrs, "position_y", Map.get(attrs, :position_y, current_system.position_y)),
         coords = %{x: x, y: y},
         :ok <- apply_system_updates(map_id, system_id, attrs, coords),
         {:ok, system} <- MapSystemRepo.get_by_map_and_solar_system_id(map_id, system_id) do
      {:ok, system}
    else
      {:error, reason} when is_binary(reason) ->
        {:error, reason}
      error ->
        Logger.error("Error updating system #{system_id} in map #{map_id}: #{inspect(error)}")
        {:error, "Error updating system"}
    end
  end

  @spec delete_system(String.t(), integer()) :: {:ok, integer()} | {:error, term()}
  def delete_system(map_id, system_id) do
    with {:ok, %{id: char_id, user_id: user_id}} <- get_owner_character_id(map_id),
         {:ok, _system} <- MapSystemRepo.get_by_map_and_solar_system_id(map_id, system_id),
         :ok <- Server.delete_systems(map_id, [system_id], user_id, char_id) do
      {:ok, 1}
    else
      {:error, :not_found} -> {:error, :not_found}
      error ->
        Logger.error("Failed to delete system #{system_id} from map #{map_id}: #{inspect(error)}")
        {:error, "Failed to delete system"}
    end
  end

  @doc """
  Create a new connection if missing

  Returns :ok on success
  Returns {:skip, :exists} if connection already exists
  Returns {:error, reason} on failure
  """
  @spec create_connection(map(), String.t()) :: :ok | {:skip, :exists} | {:error, String.t()}
  def create_connection(attrs, map_id) when is_map(attrs) do
    case get_owner_character_id(map_id) do
      {:ok, %{id: char_id}} ->
        do_create_connection(attrs, map_id, char_id)
      {:error, reason} ->
        Logger.error("Failed to get owner character ID: #{inspect(reason)}")
        {:error, reason}
      other ->
        Logger.error("Unexpected error getting owner character ID: #{inspect(other)}")
        {:error, "Failed to get owner character ID"}
    end
  end

  @doc """
  Create a new connection if missing with explicit character ID

  Returns :ok on success
  Returns {:skip, :exists} if connection already exists
  Returns {:error, reason} on failure
  """
  @spec create_connection(map(), String.t(), integer()) :: :ok | {:skip, :exists} | {:error, String.t()}
  def create_connection(attrs, map_id, char_id) when is_map(attrs) do
    do_create_connection(attrs, map_id, char_id)
  end

  defp do_create_connection(attrs, map_id, char_id) do
    with {:ok, source} <- parse_int(attrs["solar_system_source"], "solar_system_source"),
         {:ok, target} <- parse_int(attrs["solar_system_target"], "solar_system_target"),
         false <- connection_exists?(map_id, source, target),
         info <- build_connection_info(source, target, char_id, attrs["type"]),
         :ok <-  Server.add_connection(map_id, info) do
      # Just return :ok on success
      :ok
    else
      true ->
        # Connection already exists
        {:skip, :exists}
      {:error, reason} ->
        # Explicit error with reason
        {:error, reason}
      other ->
        # Any other unexpected condition
        Logger.error("Unexpected result in do_create_connection: #{inspect(other)}")
        {:error, "Failed to create connection"}
    end
  end


  defp build_connection_info(source, target, char_id, type) do
    %{
      solar_system_source_id: source,
      solar_system_target_id: target,
      character_id: char_id,
      type: parse_type(type)
    }
  end

  @doc "Delete an existing connection"
  @spec delete_connection(String.t(), integer(), integer(), integer()) :: :ok | {:error, term()}
  def delete_connection(map_id, src, tgt, _char_id) do
    if connection_exists?(map_id, src, tgt) do
      Server.delete_connection(map_id, %{solar_system_source_id: src, solar_system_target_id: tgt})
    else
      {:error, :not_found}
    end
  end

  @doc "Upsert multiple systems and connections, returning counts"
  @spec upsert_systems_and_connections(String.t(), [map()], [map()]) :: {:ok, map()} | {:error, String.t()}
  def upsert_systems_and_connections(map_id, systems, connections) do
    case get_owner_character_id(map_id) do
      {:ok, %{id: char_id}} ->
        system_results = upsert_each(systems, &create_system(map_id, &1), 0, 0)
        connection_results = upsert_each(connections, &create_connection(&1, map_id, char_id), 0, 0, 0)
        {:ok, format_upsert_results(system_results, connection_results)}
      {:error, reason} ->
        Logger.error("Batch upsert failed for map #{map_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp format_upsert_results({created_s, updated_s, _}, {created_c, skipped_c, deleted_c}) do
    %{
      systems: %{created: created_s, updated: updated_s},
      connections: %{created: created_c, skipped: skipped_c, deleted: deleted_c}
    }
  end

  @doc "Get connection by ID"
  @spec get_connection(String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def get_connection(map_id, id) do
    case MapConnectionRepo.get_by_map(map_id) do
      {:ok, conns} ->
        case Enum.find(conns, &(&1.id == id)) do
          nil -> {:error, :not_found}
          conn -> {:ok, conn}
        end
      {:error, reason} ->
        Logger.error("Failed to fetch connections for map #{map_id}: #{inspect(reason)}")
        {:error, "Connection not found"}
    end
  end

  # -- Helpers ---------------------------------------------------------------

  defp fetch_system_id(%{"solar_system_id" => id}), do: parse_int(id, "solar_system_id")
  defp fetch_system_id(%{solar_system_id: id}) when not is_nil(id), do: parse_int(id, "solar_system_id")
  defp fetch_system_id(%{"name" => name}) when is_binary(name) and name != "", do: find_by_name(name)
  defp fetch_system_id(%{name: name}) when is_binary(name) and name != "", do: find_by_name(name)
  defp fetch_system_id(_), do: {:error, "Missing system identifier (id or name)"}

  @doc """
  Find system ID by name
  Uses EveDataService for lookup
  """
  defp find_by_name(name) do
    case WandererApp.EveDataService.find_system_id_by_name(name) do
      {:ok, id} when is_integer(id) -> {:ok, id}
      {:ok, _} -> {:error, "Invalid system name: #{name}"}
      {:error, reason} -> {:error, "Failed to find system by name '#{name}': #{reason}"}
      _ -> {:error, "Unknown system name: #{name}"}
    end
  end

  defp parse_int(val, _field) when is_integer(val), do: {:ok, val}
  defp parse_int(val, field) when is_binary(val) do
    case Integer.parse(val) do
      {i, _} -> {:ok, i}
      _ -> {:error, "Invalid #{field}: #{val}"}
    end
  end
  defp parse_int(nil, field), do: {:error, "Missing #{field}"}
  defp parse_int(val, field), do: {:error, "Invalid #{field} type: #{inspect(val)}"}

  defp parse_type(val) when is_binary(val) do
    case Integer.parse(val) do
      {i, _} -> i
      _ -> 0
    end
  end
  defp parse_type(val) when is_integer(val), do: val
  defp parse_type(_), do: 0

  defp normalize_coordinates(%{"coordinates" => %{"x" => x, "y" => y}}) when is_number(x) and is_number(y), do: %{x: x, y: y}
  defp normalize_coordinates(%{coordinates: %{x: x, y: y}}) when is_number(x) and is_number(y), do: %{x: x, y: y}
  defp normalize_coordinates(params) do
    %{
      x: params |> Map.get("position_x", Map.get(params, :position_x, 0)),
      y: params |> Map.get("position_y", Map.get(params, :position_y, 0))
    }
  end

  defp apply_system_updates(map_id, system_id, attrs, %{x: x, y: y}) do
    with :ok <- Server.update_system_position(map_id, %{solar_system_id: system_id, position_x: round(x), position_y: round(y)}) do
      attrs
      |> Map.drop([:coordinates, :position_x, :position_y, :solar_system_id])
      |> Enum.each(fn {key, val} -> update_system_field(map_id, system_id, to_string(key), val) end)
      :ok
    end
  end

  defp update_system_field(map_id, system_id, field, val) do
    case field do
      "status" -> Server.update_system_status(map_id, %{solar_system_id: system_id, status: convert_status(val)})
      "description" -> Server.update_system_description(map_id, %{solar_system_id: system_id, description: val})
      "tag" -> Server.update_system_tag(map_id, %{solar_system_id: system_id, tag: val})
      "locked" -> Server.update_system_locked(map_id, %{solar_system_id: system_id, locked: val})
      f when f in ["label", "labels"] ->
        labels = if is_list(val), do: Enum.join(val, ","), else: to_string(val)
        Server.update_system_labels(map_id, %{solar_system_id: system_id, labels: labels})
      "temporary_name" -> Server.update_system_temporary_name(map_id, %{solar_system_id: system_id, temporary_name: val})
      _ -> :ok
    end
  end

  defp convert_status("CLEAR"), do: 0
  defp convert_status("DANGEROUS"), do: 1
  defp convert_status("OCCUPIED"), do: 2
  defp convert_status("MASS_CRITICAL"), do: 3
  defp convert_status("TIME_CRITICAL"), do: 4
  defp convert_status("REINFORCED"), do: 5
  defp convert_status(i) when is_integer(i), do: i
  defp convert_status(s) when is_binary(s) do
    case Integer.parse(s) do
      {i, _} -> i
      _ -> 0
    end
  end
  defp convert_status(_), do: 0

  @spec connection_exists?(String.t(), integer(), integer()) :: boolean()
  def connection_exists?(map_id, src, tgt) do
    forward = WandererApp.Map.get_connection(map_id, src, tgt)
    reverse = WandererApp.Map.get_connection(map_id, tgt, src)
    not is_nil(forward) or not is_nil(reverse)
  end

  defp upsert_each(list, fun, c, u), do: upsert_each(list, fun, c, u, 0)
  defp upsert_each([], _fun, c, u, d), do: {c, u, d}
  defp upsert_each([item | rest], fun, c, u, d) do
    case fun.(item) do
      {:ok, _} -> upsert_each(rest, fun, c + 1, u, d)
      :ok -> upsert_each(rest, fun, c + 1, u, d)
      {:skip, _} -> upsert_each(rest, fun, c, u + 1, d)
      _ -> upsert_each(rest, fun, c, u, d + 1)
    end
  end

  @doc """
  Update a connection's allowed fields (mass_status, ship_size_type, locked, custom_info, type)
  """
  @spec update_connection(String.t(), String.t(), map()) :: {:ok, map()} | {:error, String.t()}
  def update_connection(map_id, id, attrs) do
    case get_connection(map_id, id) do
      {:ok, conn} ->
        allowed_fields = ["mass_status", "ship_size_type", "locked", "custom_info", "type"]
        update_attrs =
          attrs
          |> Map.take(allowed_fields)
          |> Enum.reject(fn {_k, v} -> is_nil(v) end)
          |> Enum.into(%{})

        Enum.each(update_attrs, fn
          {"mass_status", v} ->
            WandererApp.Map.Server.update_connection_mass_status(map_id, %{
              solar_system_source_id: conn.solar_system_source,
              solar_system_target_id: conn.solar_system_target,
              mass_status: v
            })
          {"ship_size_type", v} ->
            WandererApp.Map.Server.update_connection_ship_size_type(map_id, %{
              solar_system_source_id: conn.solar_system_source,
              solar_system_target_id: conn.solar_system_target,
              ship_size_type: v
            })
          {"locked", v} ->
            WandererApp.Map.Server.update_connection_locked(map_id, %{
              solar_system_source_id: conn.solar_system_source,
              solar_system_target_id: conn.solar_system_target,
              locked: v
            })
          {"custom_info", v} ->
            WandererApp.Map.Server.update_connection_custom_info(map_id, %{
              solar_system_source_id: conn.solar_system_source,
              solar_system_target_id: conn.solar_system_target,
              custom_info: v
            })
          {"type", v} ->
            WandererApp.Map.Server.update_connection_type(map_id, %{
              solar_system_source_id: conn.solar_system_source,
              solar_system_target_id: conn.solar_system_target,
              type: v
            })
          _ -> :ok
        end)

        get_connection(map_id, id)
      err -> err
    end
  end
end
