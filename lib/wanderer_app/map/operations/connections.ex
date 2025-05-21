defmodule WandererApp.Map.Operations.Connections do
  @moduledoc """
  CRUD and batch upsert for map connections.
  """

  alias Ash.Error.Invalid
  alias WandererApp.MapConnectionRepo
  alias WandererApp.Map.Server
  require Logger

  @c1_system_class 1
  @medium_ship_size 1

  @spec list_connections(String.t()) :: [map()] | {:error, atom()}
  def list_connections(map_id) do
    with {:ok, conns} <- MapConnectionRepo.get_by_map(map_id) do
      conns
    else
      {:error, err} ->
        Logger.warning("[list_connections] Repo error: #{inspect(err)}")
        {:error, :repo_error}
      other ->
        Logger.error("[list_connections] Unexpected repo result: #{inspect(other)}")
        {:error, :unexpected_repo_result}
    end
  end

  @spec list_connections(String.t(), integer()) :: [map()]
  def list_connections(map_id, system_id) do
    list_connections(map_id)
    |> Enum.filter(fn c ->
      c.solar_system_source == system_id or c.solar_system_target == system_id
    end)
  end

  @spec get_connection(String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def get_connection(map_id, conn_id) do
    case MapConnectionRepo.get_by_id(map_id, conn_id) do
      {:ok, conn} -> {:ok, conn}
      _ -> {:error, "Connection not found"}
    end
  end

  @spec create_connection(Plug.Conn.t(), map()) :: {:ok, map()} | {:skip, :exists} | {:error, atom()}
  def create_connection(%{assigns: %{map_id: map_id, owner_character_id: char_id}} = _conn, attrs) do
    do_create(attrs, map_id, char_id)
  end

  def create_connection(map_id, attrs, char_id) do
    do_create(attrs, map_id, char_id)
  end

  defp do_create(attrs, map_id, char_id) do
    with {:ok, source} <- parse_int(attrs["solar_system_source"], "solar_system_source"),
         {:ok, target} <- parse_int(attrs["solar_system_target"], "solar_system_target") do
      # Check if either system is C1 before creating the connection
      {:ok, source_system_info} = WandererApp.Map.Server.ConnectionsImpl.get_system_static_info(source)
      {:ok, target_system_info} = WandererApp.Map.Server.ConnectionsImpl.get_system_static_info(target)

      # Set ship size type to medium if either system is C1
      ship_size_type = if source_system_info.system_class == @c1_system_class or target_system_info.system_class == @c1_system_class do
        @medium_ship_size
      else
        Map.get(attrs, "ship_size_type", 2) |> parse_type()
      end

      info = %{
        solar_system_source_id: source,
        solar_system_target_id: target,
        character_id: char_id,
        type: parse_type(attrs["type"]),
        ship_size_type: ship_size_type
      }
      add_result = Server.add_connection(map_id, info)
      case add_result do
        :ok -> {:ok, :created}
        {:ok, []} ->
          Logger.warning("[do_create] Server.add_connection returned :ok, [] for map_id=#{inspect(map_id)}, source=#{inspect(source)}, target=#{inspect(target)}")
          {:error, :inconsistent_state}
        {:error, %Invalid{errors: errors}} = err ->
          if Enum.any?(errors, &is_unique_constraint_error?/1), do: {:skip, :exists}, else: err
        {:error, _} = err ->
          Logger.error("[do_create] Server.add_connection error: #{inspect(err)}")
          {:error, :server_error}
        _ ->
          Logger.error("[do_create] Unexpected add_result: #{inspect(add_result)}")
          {:error, :unexpected_error}
      end
    else
      {:ok, []} ->
        Logger.warning("[do_create] Source or target system not found: attrs=#{inspect(attrs)}")
        {:error, :inconsistent_state}
      {:error, _} = err ->
        Logger.error("[do_create] parse_int error: #{inspect(err)}, attrs=#{inspect(attrs)}")
        {:error, :parse_error}
      _ ->
        Logger.error("[do_create] Unexpected error in preconditions: attrs=#{inspect(attrs)}")
        {:error, :unexpected_precondition_error}
    end
  end

  @spec update_connection(Plug.Conn.t(), String.t(), map()) :: {:ok, map()} | {:error, atom()}
  def update_connection(%{assigns: %{map_id: map_id, owner_character_id: char_id}} = _conn, conn_id, attrs) do
    with {:ok, conn_struct} <- MapConnectionRepo.get_by_id(map_id, conn_id),
         result <- (
           try do
             _allowed_keys = [
               :mass_status,
               :ship_size_type,
               :type
             ]
             _update_map =
               attrs
               |> Enum.filter(fn {k, _v} -> k in ["mass_status", "ship_size_type", "type"] end)
               |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
               |> Enum.into(%{})
             res = apply_connection_updates(map_id, conn_struct, attrs, char_id)
             res
           rescue
             error ->
               Logger.error("[update_connection] Exception: #{inspect(error)}")
               {:error, :exception}
           end
         ),
         :ok <- result,
         {:ok, updated_conn} <- MapConnectionRepo.get_by_id(map_id, conn_id) do
      {:ok, updated_conn}
    else
      {:error, err} -> {:error, err}
      _ -> {:error, :unexpected_error}
    end
  end
  def update_connection(_conn, _conn_id, _attrs), do: {:error, :missing_params}

  @spec delete_connection(Plug.Conn.t(), integer(), integer()) :: :ok | {:error, atom()}
  def delete_connection(%{assigns: %{map_id: map_id}} = _conn, src, tgt) do
    case Server.delete_connection(map_id, %{solar_system_source_id: src, solar_system_target_id: tgt}) do
      :ok -> :ok
      {:error, :not_found} ->
        Logger.warning("[delete_connection] Connection not found: source=#{inspect(src)}, target=#{inspect(tgt)}")
        {:error, :not_found}
      {:error, _} = err ->
        Logger.error("[delete_connection] Server error: #{inspect(err)}")
        {:error, :server_error}
      _ ->
        Logger.error("[delete_connection] Unknown error")
        {:error, :unknown}
    end
  end
  def delete_connection(_conn, _src, _tgt), do: {:error, :missing_params}

  @doc "Batch upsert for connections"
  @spec upsert_batch(Plug.Conn.t(), [map()]) :: %{created: integer(), updated: integer(), skipped: integer()}
  def upsert_batch(%{assigns: %{map_id: map_id, owner_character_id: char_id}} = conn, conns) do
    _assigns = %{map_id: map_id, char_id: char_id}
    Enum.reduce(conns, %{created: 0, updated: 0, skipped: 0}, fn conn_attrs, acc ->
      case upsert_single(conn, conn_attrs) do
        {:ok, :created} -> %{acc | created: acc.created + 1}
        {:ok, :updated} -> %{acc | updated: acc.updated + 1}
        _ -> %{acc | skipped: acc.skipped + 1}
      end
    end)
  end
  def upsert_batch(_conn, _conns), do: %{created: 0, updated: 0, skipped: 0}

  @doc "Upsert a single connection"
  @spec upsert_single(Plug.Conn.t(), map()) :: {:ok, :created | :updated} | {:error, atom()}
  def upsert_single(%{assigns: %{map_id: map_id, owner_character_id: char_id}} = conn, conn_data) do
    source = conn_data["solar_system_source"] || conn_data[:solar_system_source]
    target = conn_data["solar_system_target"] || conn_data[:solar_system_target]
    with {:ok, %{} = existing_conn} <- get_connection_by_systems(map_id, source, target),
         {:ok, _} <- update_connection(conn, existing_conn.id, conn_data) do
      {:ok, :updated}
    else
      {:ok, nil} ->
        case create_connection(map_id, conn_data, char_id) do
          {:ok, _} -> {:ok, :created}
          {:skip, :exists} -> {:ok, :updated}
          err -> {:error, err}
        end
      {:error, _} = err ->
        Logger.warning("[upsert_single] Connection lookup error: #{inspect(err)}")
        {:error, :lookup_error}
      err ->
        Logger.error("[upsert_single] Update failed: #{inspect(err)}")
        {:error, :unexpected_error}
    end
  end
  def upsert_single(_conn, _conn_data), do: {:error, :missing_params}

  @doc "Get a connection by source and target system IDs"
  @spec get_connection_by_systems(String.t(), integer(), integer()) :: {:ok, map()} | {:error, String.t()}
  def get_connection_by_systems(map_id, source, target) do
    with {:ok, conn} <- WandererApp.Map.find_connection(map_id, source, target) do
      if conn, do: {:ok, conn}, else: WandererApp.Map.find_connection(map_id, target, source)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # -- Helpers ---------------------------------------------------------------

  defp parse_int(val, _field) when is_integer(val), do: {:ok, val}
  defp parse_int(val, field) when is_binary(val) do
    case Integer.parse(val) do
      {i, _} -> {:ok, i}
      _ -> {:error, "Invalid #{field}: #{val}"}
    end
  end
  defp parse_int(nil, field), do: {:error, "Missing #{field}"}
  defp parse_int(val, field), do: {:error, "Invalid #{field} type: #{inspect(val)}"}

  defp parse_type(val) when is_integer(val), do: val
  defp parse_type(val) when is_binary(val) do
    case Integer.parse(val) do
      {i, _} -> i
      _ -> 0
    end
  end
  defp parse_type(_), do: 0

  defp is_unique_constraint_error?(%{constraint: :unique}), do: true
  defp is_unique_constraint_error?(%{constraint: :unique_constraint}), do: true
  defp is_unique_constraint_error?(_), do: false

  defp apply_connection_updates(map_id, conn, attrs, _char_id) do
    Enum.reduce_while(attrs, :ok, fn {key, val}, _acc ->
      result =
        case key do
          "mass_status" -> maybe_update_mass_status(map_id, conn, val)
          "ship_size_type" -> maybe_update_ship_size_type(map_id, conn, val)
          "type" -> maybe_update_type(map_id, conn, val)
          _ -> :ok
        end
      if result == :ok do
        {:cont, :ok}
      else
        {:halt, result}
      end
    end)
    |> case do
      :ok -> :ok
      err -> err
    end
  end

  defp maybe_update_mass_status(_map_id, _conn, nil), do: :ok
  defp maybe_update_mass_status(map_id, conn, value) do
    Server.update_connection_mass_status(map_id, %{
      solar_system_source_id: conn.solar_system_source,
      solar_system_target_id: conn.solar_system_target,
      mass_status: value
    })
  end

  defp maybe_update_ship_size_type(_map_id, _conn, nil), do: :ok
  defp maybe_update_ship_size_type(map_id, conn, value) do
    Server.update_connection_ship_size_type(map_id, %{
      solar_system_source_id: conn.solar_system_source,
      solar_system_target_id: conn.solar_system_target,
      ship_size_type: value
    })
  end

  defp maybe_update_type(_map_id, _conn, nil), do: :ok
  defp maybe_update_type(map_id, conn, value) do
    Server.update_connection_type(map_id, %{
      solar_system_source_id: conn.solar_system_source,
      solar_system_target_id: conn.solar_system_target,
      type: value
    })
  end

end
