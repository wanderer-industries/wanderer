defmodule WandererApp.Contexts.MapSystems do
  @moduledoc """
  Context for managing map systems.
  
  This module provides a high-level interface for system operations,
  including CRUD operations and batch upserts for map systems.
  """

  alias WandererApp.MapSystemRepo
  alias WandererApp.Contexts.MapConnections
  require Logger

  @map_server Application.compile_env(:wanderer_app, :map_server, WandererApp.Map.Server)

  @doc """
  Lists all systems for a map.
  """
  @spec list_systems(String.t()) :: [map()]
  def list_systems(map_id) do
    list_systems(map_id, %{})
  end

  @doc """
  Lists systems for a map with optional filtering.
  """
  @spec list_systems(String.t(), map()) :: [map()]
  def list_systems(map_id, filter_opts) do
    with {:ok, systems} <- MapSystemRepo.get_visible_by_map(map_id, filter_opts) do
      systems
    else
      _ -> []
    end
  end

  @doc """
  Gets a specific system by solar system ID.
  """
  @spec get_system(String.t(), integer()) :: {:ok, map()} | {:error, :not_found}
  def get_system(map_id, system_id) do
    MapSystemRepo.get_by_map_and_solar_system_id(map_id, system_id)
  end

  @doc """
  Creates a new system in a map.
  """
  @spec create_system(Plug.Conn.t(), map()) :: {:ok, map()} | {:error, atom()}
  def create_system(
        %{assigns: %{map_id: map_id, owner_character_id: char_id, owner_user_id: user_id}} =
          _conn,
        params
      ) do
    do_create_system(map_id, user_id, char_id, params)
  end

  def create_system(_conn, _params), do: {:error, :missing_params}

  @doc """
  Updates an existing system.
  """
  @spec update_system(Plug.Conn.t(), integer(), map()) :: {:ok, map()} | {:error, atom()}
  def update_system(
        %{assigns: %{map_id: map_id, owner_character_id: char_id, owner_user_id: user_id}} = _conn,
        system_id,
        attrs
      ) do
    case @map_server.update_system(
           map_id,
           %{solar_system_id: system_id, update_attrs: attrs},
           user_id,
           char_id
         ) do
      :ok ->
        case MapSystemRepo.get_by_map_and_solar_system_id(map_id, system_id) do
          {:ok, system} -> {:ok, system}
          _ -> {:error, :not_found}
        end

      {:error, reason} ->
        Logger.warning("[update_system] Error: #{inspect(reason)}")
        {:error, :update_failed}

      _ ->
        {:error, :unexpected_error}
    end
  end

  def update_system(_conn, _system_id, _attrs), do: {:error, :missing_params}

  @doc """
  Deletes a system from a map.
  """
  @spec delete_system(Plug.Conn.t(), integer()) :: :ok | {:error, atom()}
  def delete_system(
        %{assigns: %{map_id: map_id, owner_character_id: char_id, owner_user_id: user_id}} = _conn,
        system_id
      ) do
    case @map_server.delete_system(
           map_id,
           %{solar_system_id: system_id},
           user_id,
           char_id
         ) do
      :ok -> {:ok, :deleted}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :unexpected_error}
    end
  end

  def delete_system(_conn, _system_id), do: {:error, :missing_params}

  @doc """
  Batch upserts systems and connections.
  Returns statistics about the operation.
  """
  @spec upsert_systems_and_connections(Plug.Conn.t(), [map()], [map()]) ::
          {:ok, map()} | {:error, atom()}
  def upsert_systems_and_connections(
        %{assigns: %{map_id: _map_id, owner_character_id: _char_id, owner_user_id: _user_id}} = conn,
        systems,
        connections
      ) do
    # Upsert systems first
    system_stats = upsert_systems_batch(conn, systems)

    # Then upsert connections
    connection_stats = MapConnections.upsert_batch(conn, connections)

    # Combine statistics
    combined_stats = %{
      systems: system_stats,
      connections: connection_stats,
      total_created: system_stats.created + connection_stats.created,
      total_updated: system_stats.updated + connection_stats.updated,
      total_skipped: system_stats.skipped + connection_stats.skipped
    }

    {:ok, combined_stats}
  end

  def upsert_systems_and_connections(_conn, _systems, _connections), do: {:error, :missing_params}

  @doc """
  Batch upserts systems only.
  """
  @spec upsert_systems_batch(Plug.Conn.t(), [map()]) :: %{
          created: integer(),
          updated: integer(),
          skipped: integer()
        }
  def upsert_systems_batch(
        %{assigns: %{map_id: map_id, owner_character_id: char_id, owner_user_id: user_id}} = _conn,
        systems
      ) do
    assigns = %{map_id: map_id, user_id: user_id, char_id: char_id}

    Enum.reduce(systems, %{created: 0, updated: 0, skipped: 0}, fn system_params, acc ->
      case create_system_batch(assigns, system_params) do
        {:ok, _system} -> %{acc | created: acc.created + 1}
        {:skip, _system} -> %{acc | updated: acc.updated + 1}
        {:error, _} -> %{acc | skipped: acc.skipped + 1}
      end
    end)
  end

  def upsert_systems_batch(_conn, _systems), do: %{created: 0, updated: 0, skipped: 0}

  # -- Private Functions -----------------------------------------------------

  defp create_system_batch(%{map_id: map_id, user_id: user_id, char_id: char_id}, params) do
    do_create_system(map_id, user_id, char_id, params)
  end

  defp do_create_system(map_id, user_id, char_id, params) do
    with {:ok, system_id} <- fetch_system_id(params),
         coords <- normalize_coordinates(params) do
      case @map_server.add_system(
             map_id,
             %{solar_system_id: system_id, coordinates: coords, params: params},
             user_id,
             char_id
           ) do
        :ok ->
          # System was created successfully
          case MapSystemRepo.get_by_map_and_solar_system_id(map_id, system_id) do
            {:ok, system} -> {:ok, system}
            _ -> {:error, :unexpected_error}
          end

        {:error, "System already exists"} ->
          # System already exists, treat as update/skip in batch operations
          case MapSystemRepo.get_by_map_and_solar_system_id(map_id, system_id) do
            {:ok, system} -> {:skip, system}
            _ -> {:error, :unexpected_error}
          end

        {:error, reason} when is_binary(reason) ->
          Logger.warning("[do_create_system] Expected error: #{inspect(reason)}")
          {:error, :expected_error}

        _ ->
          Logger.error("[do_create_system] Unexpected error")
          {:error, :unexpected_error}
      end
    else
      {:error, reason} when is_binary(reason) ->
        Logger.warning("[do_create_system] Parameter error: #{inspect(reason)}")
        {:error, :parameter_error}

      {:error, reason} ->
        Logger.error("[do_create_system] Unexpected parameter error: #{inspect(reason)}")
        {:error, :unexpected_parameter_error}
    end
  end

  defp fetch_system_id(params) do
    solar_system_id = params["solar_system_id"] || params[:solar_system_id]

    case solar_system_id do
      nil ->
        {:error, "Missing solar_system_id"}

      id when is_integer(id) ->
        {:ok, id}

      id when is_binary(id) ->
        case Integer.parse(id) do
          {parsed_id, _} -> {:ok, parsed_id}
          :error -> {:error, "Invalid solar_system_id format"}
        end

      _ ->
        {:error, "Invalid solar_system_id type"}
    end
  end

  defp normalize_coordinates(params) do
    %{
      x: params["position_x"] || params[:position_x] || params["x"] || params[:x] || 0,
      y: params["position_y"] || params[:position_y] || params["y"] || params[:y] || 0
    }
  end
end