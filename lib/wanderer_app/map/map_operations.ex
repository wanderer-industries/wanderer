defmodule WandererApp.Map.Operations do
  @moduledoc """
  Orchestrates map systems and connections.
  Centralizes cross-repo logic for controllers, templates, and batch operations.
  """

  # Cache TTL in milliseconds (24 hours)
  @owner_info_cache_ttl 86_400_000

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
    case WandererApp.Cache.lookup!("map_#{map_id}:owner_info") do
      nil ->
        with {:ok, owner} <- fetch_map_owner(map_id),
             {:ok, char_ids} <- fetch_character_ids(map_id),
             {:ok, characters} <- load_characters(char_ids),
             {:ok, user_settings} <- MapUserSettingsRepo.get(map_id, owner.id),
             {:ok, main} <- TrackingUtils.get_main_character(user_settings, characters, characters) do
          result = %{id: main.id, user_id: main.user_id}
          WandererApp.Cache.insert("map_#{map_id}:owner_info", result, ttl: @owner_info_cache_ttl)
          {:ok, result}
        else
          {:error, msg} ->
            {:error, msg}
          _ ->
            {:error, "Failed to resolve main character"}
        end
      cached ->
        {:ok, cached}
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
      {:ok, settings} when is_list(settings) and settings != [] -> {:ok, Enum.map(settings, & &1.character_id)}
      {:ok, []} -> {:error, "No character settings found"}
      {:error, _} -> {:error, "Failed to fetch character settings"}
    end
  end

  defp load_characters(ids) when is_list(ids) do
    ids
    |> Enum.map(&Character.get_character/1)
    |> Enum.flat_map(fn
      {:ok, ch} -> [ch]
      _         -> []
    end)
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
      _ ->
        {:error, "Unable to create system"}
    end
  end

  @doc "Update attributes of an existing system"
  @spec update_system(String.t(), integer(), map()) :: {:ok, any()} | {:error, String.t()}
  def update_system(map_id, system_id, attrs) do
    # Fetch current system to get its position if not provided
    with {:ok, current_system} <- MapSystemRepo.get_by_map_and_solar_system_id(map_id, system_id),
         x_raw <- Map.get(attrs, "position_x", Map.get(attrs, :position_x, current_system.position_x)),
         y_raw <- Map.get(attrs, "position_y", Map.get(attrs, :position_y, current_system.position_y)),
         {:ok, x} <- parse_int(x_raw, "position_x"),
         {:ok, y} <- parse_int(y_raw, "position_y"),
         coords = %{x: x, y: y},
         :ok <- apply_system_updates(map_id, system_id, attrs, coords),
         {:ok, system} <- MapSystemRepo.get_by_map_and_solar_system_id(map_id, system_id) do
      {:ok, system}
    else
      {:error, reason} when is_binary(reason) ->
        {:error, reason}
      _ ->
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
      _ ->
        {:error, "Failed to delete system"}
    end
  end

  @doc """
  Create a new connection if missing

  Returns :ok on success
  Returns {:skip, :exists} if connection already exists
  Returns {:error, reason} on failure
  """
  @spec create_connection(map(), String.t()) :: {:ok, any()} | {:skip, :exists} | {:error, String.t()}
  def create_connection(attrs, map_id) when is_map(attrs) do
    with {:ok, %{id: char_id}} <- get_owner_character_id(map_id) do
      do_create_connection(attrs, map_id, char_id)
    end
  end

  @doc """
  Create a new connection if missing with explicit character ID

  Returns :ok on success
  Returns {:skip, :exists} if connection already exists
  Returns {:error, reason} on failure
  """
  @spec create_connection(map(), String.t(), integer()) :: {:ok, any()} | {:skip, :exists} | {:error, String.t()}
  def create_connection(attrs, map_id, char_id) when is_map(attrs), do: do_create_connection(attrs, map_id, char_id)

  defp do_create_connection(attrs, map_id, char_id) do
    with {:ok, source} <- parse_int(attrs["solar_system_source"], "solar_system_source"),
         {:ok, target} <- parse_int(attrs["solar_system_target"], "solar_system_target"),
         info = build_connection_info(source, target, char_id, attrs["type"]),
         :ok <- Server.add_connection(map_id, info),
         {:ok, [conn | _]} <- MapConnectionRepo.get_by_locations(map_id, source, target) do
      {:ok, conn}
    else
      {:ok, []} ->
        {:ok, :created}
      {:error, %Ash.Error.Invalid{errors: errors}} = err ->
        if Enum.any?(errors, &is_unique_constraint_error?/1) do
          {:skip, :exists}
        else
          err
        end
      {:error, _reason} = err ->
        err
      _ ->
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
  @spec delete_connection(String.t(), integer(), integer()) :: :ok | {:error, term()}
  def delete_connection(map_id, src, tgt) do
    case Server.delete_connection(map_id, %{solar_system_source_id: src, solar_system_target_id: tgt}) do
      :ok -> :ok
      {:error, :not_found} -> {:error, :not_found}
      {:error, _reason} = err -> err
      _ -> {:error, :unknown}
    end
  end

  # Helper to detect Ash 'not found' errors
  defp is_not_found_error({:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{} | _]}}), do: true
  defp is_not_found_error({:error, %Ash.Error.Invalid{errors: errors}}) when is_list(errors), do: Enum.any?(errors, &match?(%Ash.Error.Query.NotFound{}, &1))
  defp is_not_found_error(_), do: false

  @spec upsert_systems_and_connections(String.t(), [map()], [map()]) :: {:ok, map()} | {:error, String.t()}
  def upsert_systems_and_connections(map_id, systems, connections) do
    with {:ok, %{id: char_id}} <- get_owner_character_id(map_id) do
      system_results = upsert_each(systems, fn sys -> create_system(map_id, sys) end, 0, 0)
      connection_results = Enum.reduce(connections, %{created: 0, updated: 0, skipped: 0}, fn conn, acc ->
        upsert_connection_branch(map_id, conn, char_id, acc)
      end)
      {:ok, format_upsert_results(system_results, {connection_results.created, connection_results.updated})}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Private: Handles a single connection upsert branch for batch upsert
  defp upsert_connection_branch(map_id, conn, char_id, acc) do
    with {:ok, source} <- parse_int(conn["solar_system_source"], "solar_system_source"),
         {:ok, target} <- parse_int(conn["solar_system_target"], "solar_system_target") do
      case get_connection_by_systems(map_id, source, target) do
        {:ok, existing_conn} when is_map(existing_conn) and not is_nil(existing_conn) ->
          case update_connection(map_id, existing_conn.id, conn) do
            {:ok, _} -> %{acc | updated: acc.updated + 1}
            error ->
              if is_not_found_error(error) do
                case create_connection(conn, map_id, char_id) do
                  {:ok, _} -> %{acc | created: acc.created + 1}
                  {:skip, :exists} -> %{acc | updated: acc.updated + 1}
                  {:error, _} -> %{acc | skipped: acc.skipped + 1}
                end
              else
                %{acc | skipped: acc.skipped + 1}
              end
          end
        {:ok, _} ->
          case create_connection(conn, map_id, char_id) do
            {:ok, _} -> %{acc | created: acc.created + 1}
            {:skip, :exists} -> %{acc | updated: acc.updated + 1}
            {:error, _} -> %{acc | skipped: acc.skipped + 1}
          end
        {:error, :not_found} ->
          case create_connection(conn, map_id, char_id) do
            {:ok, _} -> %{acc | created: acc.created + 1}
            {:skip, :exists} -> %{acc | updated: acc.updated + 1}
            {:error, _} -> %{acc | skipped: acc.skipped + 1}
          end
        _ ->
          %{acc | skipped: acc.skipped + 1}
      end
    else
      {:error, _} ->
        %{acc | skipped: acc.skipped + 1}
    end
  end

  # Helper to get a connection by source/target system IDs
  def get_connection_by_systems(map_id, source, target) do
    case WandererApp.Map.find_connection(map_id, source, target) do
      {:ok, nil} ->
        WandererApp.Map.find_connection(map_id, target, source)
      {:ok, conn} ->
        {:ok, conn}
    end
  end

  defp format_upsert_results({created_s, updated_s, _}, {created_c, updated_c}) do
    %{
      systems: %{created: created_s, updated: updated_s},
      connections: %{created: created_c, updated: updated_c}
    }
  end

  @doc "Get connection by ID"
  @spec get_connection(String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def get_connection(map_id, id) do
    case MapConnectionRepo.get_by_id(map_id, id) do
      {:ok, %{} = conn} -> {:ok, conn}
      {:error, _} -> {:error, "Connection not found"}
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
      {:ok, _} ->
        {:error, "Invalid system name: #{name}"}
      {:error, reason} ->
        {:error, "Failed to find system by name '#{name}': #{reason}"}
      _ ->
        {:error, "Unknown system name: #{name}"}
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
      |> Map.drop([:coordinates, :position_x, :position_y, :solar_system_id,
                   "coordinates", "position_x", "position_y", "solar_system_id"])
      |> Enum.reduce_while(:ok, fn {key, val}, _acc ->
        case update_system_field(map_id, system_id, to_string(key), val) do
          :ok -> {:cont, :ok}
          {:error, _} = err -> {:halt, err}
        end
      end)
    end
  end

  defp update_system_field(map_id, system_id, field, val) do
    case field do
      "status" -> Server.update_system_status(map_id, %{solar_system_id: system_id, status: convert_status(val)})
      "description" -> Server.update_system_description(map_id, %{solar_system_id: system_id, description: val})
      "tag" -> Server.update_system_tag(map_id, %{solar_system_id: system_id, tag: val})
      "locked" ->
        bool = val in [true, "true", 1, "1"]
        Server.update_system_locked(map_id, %{solar_system_id: system_id, locked: bool})
      f when f in ["label", "labels"] ->
        labels =
          cond do
            is_list(val) -> val
            is_binary(val) -> String.split(val, ",", trim: true)
            true -> []
          end
        Server.update_system_labels(map_id, %{solar_system_id: system_id, labels: Enum.join(labels, ",")})
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

  @doc "Update an existing connection"
  @spec update_connection(String.t(), String.t(), map()) :: {:ok, any()} | {:error, String.t()}
  def update_connection(map_id, connection_id, attrs) do
    with {:ok, conn} <- MapConnectionRepo.get_by_id(map_id, connection_id),
         {:ok, %{id: char_id}} <- get_owner_character_id(map_id),
         :ok <- validate_connection_update(conn, attrs),
         :ok <- apply_connection_updates(map_id, conn, attrs, char_id),
         {:ok, updated_conn} <- MapConnectionRepo.get_by_id(map_id, connection_id) do
      {:ok, updated_conn}
    else
      {:error, reason} when is_binary(reason) ->
        {:error, reason}
      {:error, %Ash.Error.Invalid{} = ash_error} ->
        {:error, ash_error}
      _error ->
        {:error, "Failed to update connection"}
    end
  end

  defp validate_connection_update(_conn, _attrs), do: :ok

  defp apply_connection_updates(map_id, conn, attrs, _char_id) do
    with :ok <- maybe_update_mass_status(map_id, conn, Map.get(attrs, "mass_status", conn.mass_status)),
         :ok <- maybe_update_ship_size_type(map_id, conn, Map.get(attrs, "ship_size_type", conn.ship_size_type)),
         :ok <- maybe_update_type(map_id, conn, Map.get(attrs, "type", conn.type)) do
      :ok
    else
      error ->
        error
    end
  end

  defp maybe_update_mass_status(map_id, conn, value) when not is_nil(value) do
    Server.update_connection_mass_status(map_id, %{
      solar_system_source_id: conn.solar_system_source,
      solar_system_target_id: conn.solar_system_target,
      mass_status: value
    })
  end
  defp maybe_update_mass_status(_map_id, _conn, nil), do: :ok

  defp maybe_update_ship_size_type(map_id, conn, value) when not is_nil(value) do
    Server.update_connection_ship_size_type(map_id, %{
      solar_system_source_id: conn.solar_system_source,
      solar_system_target_id: conn.solar_system_target,
      ship_size_type: value
    })
  end
  defp maybe_update_ship_size_type(_map_id, _conn, nil), do: :ok

  defp maybe_update_type(map_id, conn, value) when not is_nil(value) do
    Server.update_connection_type(map_id, %{
      solar_system_source_id: conn.solar_system_source,
      solar_system_target_id: conn.solar_system_target,
      type: value
    })
  end
  defp maybe_update_type(_map_id, _conn, nil), do: :ok

  @doc "List all connections for a map"
  @spec list_connections(String.t()) :: [map()]
  def list_connections(map_id) do
    case MapConnectionRepo.get_by_map(map_id) do
      {:ok, connections} -> connections
      _ -> []
    end
  end

  @doc "List connections for a map involving a specific system (source or target)"
  @spec list_connections(String.t(), integer()) :: [map()]
  def list_connections(map_id, system_id) do
    list_connections(map_id)
    |> Enum.filter(fn conn ->
      conn.solar_system_source == system_id or conn.solar_system_target == system_id
    end)
  end

  # Helper to detect unique constraint errors in Ash error lists
  defp is_unique_constraint_error?(%{constraint: :unique}), do: true
  defp is_unique_constraint_error?(%{constraint: :unique_constraint}), do: true
  defp is_unique_constraint_error?(_), do: false
end
