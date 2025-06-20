defmodule WandererApp.Contexts.MapStructures do
  @moduledoc """
  Context for managing map structures.
  
  This module provides a high-level interface for structure operations,
  including CRUD operations for structures within map systems.
  """

  require Logger
  alias WandererApp.Contexts.MapSystems
  alias WandererApp.Api.MapSystem
  alias WandererApp.Api.MapSystemStructure
  alias WandererApp.Structure

  @doc """
  Lists all structures for a map.
  """
  @spec list_structures(String.t()) :: [map()]
  def list_structures(map_id) do
    with systems when is_list(systems) and systems != [] <-
           (case MapSystems.list_systems(map_id) do
              {:ok, systems} -> systems
              systems when is_list(systems) -> systems
              _ -> []
            end) do
      systems
      |> Enum.flat_map(fn sys ->
        with {:ok, structs} <- MapSystemStructure.by_system_id(sys.id) do
          structs
        else
          _other -> []
        end
      end)
    else
      _ -> []
    end
  end

  @doc """
  Lists structures for a specific system.
  """
  @spec list_structures_for_system(String.t()) :: {:ok, [map()]} | {:error, term()}
  def list_structures_for_system(system_id) do
    MapSystemStructure.by_system_id(system_id)
  end

  @doc """
  Creates a new structure in a system.
  """
  @spec create_structure(Plug.Conn.t(), map()) :: {:ok, map()} | {:error, atom() | String.t()}
  def create_structure(
        %{assigns: %{map_id: map_id, owner_character_id: char_id, owner_user_id: user_id}} =
          _conn,
        %{"solar_system_id" => _solar_system_id} = params
      ) do
    with {:ok, system} <-
           MapSystem.read_by_map_and_solar_system(%{
             map_id: map_id,
             solar_system_id: params["solar_system_id"]
           }),
         attrs <- Map.put(prepare_attrs(params), "system_id", system.id),
         :ok <- Structure.update_structures(system, [attrs], [], [], char_id, user_id),
         name = Map.get(attrs, "name"),
         structure_type_id = Map.get(attrs, "structureTypeId"),
         struct when not is_nil(struct) <-
           MapSystemStructure.by_system_id!(system.id)
           |> Enum.find(fn s -> s.name == name and s.structure_type_id == structure_type_id end) do
      {:ok, struct}
    else
      nil ->
        Logger.warning("[create_structure] Structure not found after creation")
        {:error, :structure_not_found}

      err ->
        Logger.error("[create_structure] Unexpected error: #{inspect(err)}")
        {:error, :unexpected_error}
    end
  end

  def create_structure(_conn, _params), do: {:error, "missing params"}

  @doc """
  Updates an existing structure.
  """
  @spec update_structure(Plug.Conn.t(), String.t(), map()) :: {:ok, map()} | {:error, atom() | String.t()}
  def update_structure(
        %{assigns: %{map_id: map_id, owner_character_id: char_id, owner_user_id: user_id}} =
          _conn,
        struct_id,
        params
      ) do
    with {:ok, struct} <- MapSystemStructure.by_id(struct_id),
         {:ok, system} <-
           MapSystem.read_by_map_and_solar_system(%{
             map_id: map_id,
             solar_system_id: struct.solar_system_id
           }) do
      attrs = Map.merge(prepare_attrs(params), %{"id" => struct_id})
      :ok = Structure.update_structures(system, [], [attrs], [], char_id, user_id)

      case MapSystemStructure.by_id(struct_id) do
        {:ok, updated} ->
          {:ok, updated}

        err ->
          Logger.error("[update_structure] Unexpected error: #{inspect(err)}")
          {:error, :unexpected_error}
      end
    else
      err ->
        Logger.error("[update_structure] Unexpected error: #{inspect(err)}")
        {:error, :unexpected_error}
    end
  end

  def update_structure(_conn, _struct_id, _params), do: {:error, "missing params"}

  @doc """
  Deletes a structure.
  """
  @spec delete_structure(Plug.Conn.t(), String.t()) :: :ok | {:error, atom() | String.t()}
  def delete_structure(
        %{assigns: %{map_id: _map_id, owner_character_id: char_id, owner_user_id: user_id}} =
          _conn,
        struct_id
      ) do
    with {:ok, struct} <- MapSystemStructure.by_id(struct_id),
         {:ok, system} <- MapSystem.by_id(struct.system_id) do
      :ok = Structure.update_structures(system, [], [], [%{"id" => struct_id}], char_id, user_id)
      :ok
    else
      err ->
        Logger.error("[delete_structure] Unexpected error: #{inspect(err)}")
        {:error, :unexpected_error}
    end
  end

  def delete_structure(_conn, _struct_id), do: {:error, "missing params"}

  @doc """
  Batch updates structures for a system.
  Handles adding, updating, and removing multiple structures at once.
  """
  @spec batch_update_structures(Plug.Conn.t(), String.t(), map()) :: :ok | {:error, atom()}
  def batch_update_structures(
        %{assigns: %{map_id: map_id, owner_character_id: char_id, owner_user_id: user_id}} = _conn,
        system_id,
        %{
          "added" => added,
          "updated" => updated,
          "removed" => removed
        } = _params
      ) do
    with {:ok, system} <-
           MapSystem.read_by_map_and_solar_system(%{
             map_id: map_id,
             solar_system_id: system_id
           }) do
      added_attrs = Enum.map(added || [], &prepare_attrs/1)
      updated_attrs = Enum.map(updated || [], &prepare_attrs/1)
      removed_attrs = removed || []

      Structure.update_structures(
        system,
        added_attrs,
        updated_attrs,
        removed_attrs,
        char_id,
        user_id
      )
    else
      err ->
        Logger.error("[batch_update_structures] Error: #{inspect(err)}")
        {:error, :system_not_found}
    end
  end

  def batch_update_structures(_conn, _system_id, _params), do: {:error, :missing_params}

  # Private functions

  defp prepare_attrs(params) do
    params
    |> Enum.map(fn
      {"structure_type", v} -> {"structureType", v}
      {"structure_type_id", v} -> {"structureTypeId", v}
      {"end_time", v} -> {"endTime", v}
      {k, v} -> {k, v}
    end)
    |> Map.new()
    |> Map.take(["name", "structureType", "structureTypeId", "status", "notes", "endTime"])
  end
end