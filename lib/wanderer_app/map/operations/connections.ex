defmodule WandererApp.Map.Operations.Connections do
  @moduledoc """
  Operations for managing map connections, including creation, updates, and deletions.
  Handles special cases like C1 wormhole sizing rules and unique constraint handling.
  """

  require Logger
  alias WandererApp.Map.Server
  alias Ash.Error.Invalid
  alias WandererApp.MapConnectionRepo
  alias WandererApp.CachedInfo

  # Connection type constants
  @connection_type_wormhole 0
  @connection_type_stargate 1

  # Ship size constants
  @small_ship_size 0
  @medium_ship_size 1
  @large_ship_size 2
  @xlarge_ship_size 3
  @capital_ship_size 4

  # System class constants
  @c1_system_class 1
  @c4_system_class 4
  @c13_system_class 13
  @ns_system_class 9

  @doc """
  Creates a connection between two systems, applying special rules for C1, C13, and C4 wormholes.
  Handles parsing of input parameters, validates system information, and manages
  unique constraint violations gracefully.
  """
  def create(attrs, map_id, char_id) do
    do_create(attrs, map_id, char_id)
  end

  def small_ship_size(), do: @small_ship_size
  def medium_ship_size(), do: @medium_ship_size
  def large_ship_size(), do: @large_ship_size
  def freight_ship_size(), do: @xlarge_ship_size
  def capital_ship_size(), do: @capital_ship_size

  defp do_create(attrs, map_id, char_id) do
    with {:ok, source} <- parse_int(attrs["solar_system_source"], "solar_system_source"),
         {:ok, target} <- parse_int(attrs["solar_system_target"], "solar_system_target"),
         {:ok, src_info} <- CachedInfo.get_system_static_info(source),
         {:ok, tgt_info} <- CachedInfo.get_system_static_info(target) do
      build_and_add_connection(attrs, map_id, char_id, src_info, tgt_info)
    else
      {:error, reason} -> handle_precondition_error(reason, attrs)
      {:ok, []} -> {:error, :inconsistent_state}
      other -> {:error, :unexpected_precondition_error, other}
    end
  end

  defp build_and_add_connection(attrs, map_id, char_id, src_info, tgt_info) do
    Logger.debug(
      "[Connections] build_and_add_connection called with src_info: #{inspect(src_info)}, tgt_info: #{inspect(tgt_info)}"
    )

    # Guard against nil info
    if is_nil(src_info) or is_nil(tgt_info) do
      {:error, :invalid_system_info}
    else
      info = %{
        solar_system_source_id: src_info.solar_system_id,
        solar_system_target_id: tgt_info.solar_system_id,
        character_id: char_id,
        type: parse_type(attrs["type"]),
        ship_size_type:
          resolve_ship_size(attrs["type"], attrs["ship_size_type"], src_info, tgt_info)
      }

      case Server.add_connection(map_id, info) do
        :ok ->
          {:ok, :created}

        {:ok, []} ->
          log_warn_and(:inconsistent_state, info)

        {:error, %Invalid{errors: errs}} = err ->
          if Enum.any?(errs, &is_unique_constraint_error?/1), do: {:skip, :exists}, else: err

        {:error, _} = err ->
          Logger.error("[add_connection] #{inspect(err)}")
          {:error, :server_error}

        other ->
          Logger.error("[add_connection] unexpected: #{inspect(other)}")
          {:error, :unexpected_error}
      end
    end
  end

  @doc """
  Determines the ship size for a connection, applying wormhole‑specific rules
  for C1, C13, and C4⇄NS links, falling back to the caller’s provided size or Large.
  """
  defp resolve_ship_size(type_val, ship_size_val, src_info, tgt_info) do
    case parse_type(type_val) do
      @connection_type_wormhole ->
        wormhole_ship_size(ship_size_val, src_info, tgt_info)

      _other ->
        # Stargates and others just use the parsed or default size
        parse_ship_size(ship_size_val, @large_ship_size)
    end
  end

  # -- Wormhole‑specific sizing rules ----------------------------------------

  defp wormhole_ship_size(ship_size_val, src, tgt) do
    cond do
      c1_system?(src, tgt) -> @medium_ship_size
      c13_system?(src, tgt) -> @small_ship_size
      c4_to_ns?(src, tgt) -> @small_ship_size
      true -> parse_ship_size(ship_size_val, @large_ship_size)
    end
  end

  defp c1_system?(%{system_class: @c1_system_class}, _), do: true
  defp c1_system?(_, %{system_class: @c1_system_class}), do: true
  defp c1_system?(_, _), do: false

  defp c13_system?(%{system_class: @c13_system_class}, _), do: true
  defp c13_system?(_, %{system_class: @c13_system_class}), do: true
  defp c13_system?(_, _), do: false

  defp c4_to_ns?(%{system_class: @c4_system_class, is_shattered: false}, %{
         system_class: @ns_system_class
       }),
       do: true

  defp c4_to_ns?(%{system_class: @ns_system_class}, %{
         system_class: @c4_system_class,
         is_shattered: false
       }),
       do: true

  defp c4_to_ns?(_, _), do: false

  defp parse_ship_size(nil, default), do: default
  defp parse_ship_size(val, _default) when is_integer(val), do: val

  defp parse_ship_size(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {i, _} -> i
      :error -> default
    end
  end

  defp parse_ship_size(_, default), do: default

  defp parse_type(nil), do: @connection_type_wormhole
  defp parse_type(val) when is_integer(val), do: val

  defp parse_type(val) when is_binary(val) do
    case Integer.parse(val) do
      {i, _} -> i
      :error -> @connection_type_wormhole
    end
  end

  defp parse_type(_), do: @connection_type_wormhole

  defp parse_int(nil, field), do: {:error, {:missing_field, field}}
  defp parse_int(val, _) when is_integer(val), do: {:ok, val}

  defp parse_int(val, _) when is_binary(val) do
    case Integer.parse(val) do
      {i, _} -> {:ok, i}
      :error -> {:error, :invalid_integer}
    end
  end

  defp parse_int(_, field), do: {:error, {:invalid_field, field}}

  defp handle_precondition_error(reason, attrs) do
    Logger.warning(
      "[add_connection] precondition failed: #{inspect(reason)} for #{inspect(attrs)}"
    )

    {:error, :precondition_failed, reason}
  end

  defp log_warn_and(return, info) do
    Logger.warning("[add_connection] inconsistent for #{inspect(info)}")
    {:error, return}
  end

  defp is_unique_constraint_error?(%{code: :unique_constraint}), do: true
  defp is_unique_constraint_error?(_), do: false

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

  @spec update_connection(Plug.Conn.t(), String.t(), map()) :: {:ok, map()} | {:error, atom()}
  def update_connection(
        %{assigns: %{map_id: map_id, owner_character_id: char_id}} = _conn,
        conn_id,
        attrs
      ) do
    with {:ok, conn_struct} <- MapConnectionRepo.get_by_id(map_id, conn_id),
         result <-
           (try do
              _allowed_keys = [
                :mass_status,
                :ship_size_type,
                :time_status,
                :type
              ]

              _update_map =
                attrs
                |> Enum.filter(fn {k, _v} ->
                  k in ["mass_status", "ship_size_type", "time_status", "type"]
                end)
                |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
                |> Enum.into(%{})

              res = apply_connection_updates(map_id, conn_struct, attrs, char_id)
              res
            rescue
              error ->
                Logger.error("[update_connection] Exception: #{inspect(error)}")
                {:error, :exception}
            end),
         :ok <- result do
      # Since GenServer updates are asynchronous, manually apply updates to the current struct
      # to return the correct data immediately instead of refetching from potentially stale cache
      updated_attrs =
        attrs
        |> Enum.filter(fn {k, _v} ->
          k in ["mass_status", "ship_size_type", "time_status", "type"]
        end)
        |> Enum.map(fn {k, v} -> {String.to_existing_atom(k), v} end)
        |> Enum.into(%{})

      updated_conn = struct(conn_struct, updated_attrs)
      {:ok, updated_conn}
    else
      {:error, err} -> {:error, err}
      _ -> {:error, :unexpected_error}
    end
  end

  def update_connection(_conn, _conn_id, _attrs), do: {:error, :missing_params}

  @spec delete_connection(Plug.Conn.t(), integer(), integer()) :: :ok | {:error, atom()}
  def delete_connection(%{assigns: %{map_id: map_id}} = _conn, src, tgt) do
    case Server.delete_connection(map_id, %{
           solar_system_source_id: src,
           solar_system_target_id: tgt
         }) do
      :ok ->
        :ok

      {:error, :not_found} ->
        Logger.warning(
          "[delete_connection] Connection not found: source=#{inspect(src)}, target=#{inspect(tgt)}"
        )

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
  @spec upsert_batch(Plug.Conn.t(), [map()]) :: %{
          created: integer(),
          updated: integer(),
          skipped: integer()
        }
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
  @spec get_connection_by_systems(String.t(), integer(), integer()) ::
          {:ok, map()} | {:error, String.t()}
  def get_connection_by_systems(map_id, source, target) do
    with {:ok, conn} <- WandererApp.Map.find_connection(map_id, source, target) do
      if conn, do: {:ok, conn}, else: WandererApp.Map.find_connection(map_id, target, source)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # -- Helpers ---------------------------------------------------------------

  defp apply_connection_updates(map_id, conn, attrs, _char_id) do
    Enum.reduce_while(attrs, :ok, fn {key, val}, _acc ->
      result =
        case key do
          "mass_status" -> maybe_update_mass_status(map_id, conn, val)
          "ship_size_type" -> maybe_update_ship_size_type(map_id, conn, val)
          "time_status" -> maybe_update_time_status(map_id, conn, val)
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

  defp maybe_update_time_status(_map_id, _conn, nil), do: :ok

  defp maybe_update_time_status(map_id, conn, value) do
    Server.update_connection_time_status(map_id, %{
      solar_system_source_id: conn.solar_system_source,
      solar_system_target_id: conn.solar_system_target,
      time_status: value
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

  @doc "Creates a connection between two systems"
  @spec create_connection(String.t(), map(), String.t()) ::
          {:ok, :created} | {:skip, :exists} | {:error, atom()}
  def create_connection(map_id, attrs, char_id) do
    do_create(attrs, map_id, char_id)
  end

  @doc "Creates a connection between two systems from a Plug.Conn"
  @spec create_connection(Plug.Conn.t(), map()) ::
          {:ok, :created} | {:skip, :exists} | {:error, atom()}
  def create_connection(%{assigns: %{map_id: map_id, owner_character_id: char_id}} = _conn, attrs) do
    do_create(attrs, map_id, char_id)
  end
end
