defmodule WandererApp.Map.Operations.Structures do
  @moduledoc """
  CRUD for map structures.
  """

  alias WandererApp.Map.Operations
  alias WandererApp.Api.MapSystem
  alias WandererApp.Api.MapSystemStructure
  alias WandererApp.Structure
  require Logger

  @spec list_structures(String.t()) :: [map()]
  def list_structures(map_id) do
    with systems when is_list(systems) and systems != [] <-
           (case Operations.list_systems(map_id) do
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

  @spec create_structure(Plug.Conn.t(), map()) :: {:ok, map()} | {:error, atom()}
  def create_structure(
        %{assigns: %{map_id: map_id, owner_character_id: char_id, owner_user_id: user_id}} =
          _conn,
        %{"solar_system_id" => _solar_system_id} = params
      )
      when not is_nil(char_id) do
    with {:ok, character} when not is_nil(character) <-
           WandererApp.Character.get_character(char_id),
         {:ok, system} <-
           MapSystem.read_by_map_and_solar_system(%{
             map_id: map_id,
             solar_system_id: params["solar_system_id"]
           }),
         attrs <- Map.put(prepare_attrs(params), "system_id", system.id),
         :ok <- Structure.update_structures(system, [attrs], [], [], character.eve_id, user_id),
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

      {:error, %Ash.Error.Query.NotFound{}} ->
        {:error, :not_found}

      err ->
        Logger.error("[create_structure] Unexpected error: #{inspect(err)}")
        {:error, :unexpected_error}
    end
  end

  def create_structure(_conn, _params), do: {:error, "missing params"}

  @spec update_structure(Plug.Conn.t(), String.t(), map()) :: {:ok, map()} | {:error, atom()}
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
      prepared_attrs = prepare_attrs(params)
      # Preserve existing structure_type_id and structure_type if not being updated
      preserved_attrs =
        prepared_attrs
        |> Map.put_new("structureTypeId", struct.structure_type_id)
        |> Map.put_new("structureType", struct.structure_type)

      attrs = Map.merge(preserved_attrs, %{"id" => struct_id})
      :ok = Structure.update_structures(system, [], [attrs], [], char_id, user_id)

      case MapSystemStructure.by_id(struct_id) do
        {:ok, updated} ->
          {:ok, updated}

        err ->
          Logger.error("[update_structure] Unexpected error: #{inspect(err)}")
          {:error, :unexpected_error}
      end
    else
      {:error, %Ash.Error.Query.NotFound{}} ->
        {:error, :not_found}

      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{} | _]}} ->
        {:error, :not_found}

      err ->
        Logger.error("[update_structure] Unexpected error: #{inspect(err)}")
        {:error, :unexpected_error}
    end
  end

  def update_structure(_conn, _struct_id, _params), do: {:error, "missing params"}

  @spec delete_structure(Plug.Conn.t(), String.t()) :: :ok | {:error, atom()}
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
      {:error, %Ash.Error.Query.NotFound{}} ->
        {:error, :not_found}

      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{} | _]}} ->
        {:error, :not_found}

      err ->
        Logger.error("[delete_structure] Unexpected error: #{inspect(err)}")
        {:error, :unexpected_error}
    end
  end

  def delete_structure(_conn, _struct_id), do: {:error, "missing params"}

  defp prepare_attrs(params) do
    params
    |> Enum.map(fn
      {"structure_type", v} -> {"structureType", v}
      {"structure_type_id", v} -> {"structureTypeId", v}
      {"end_time", v} -> {"endTime", v}
      {"owner_name", v} -> {"ownerName", v}
      {"owner_ticker", v} -> {"ownerTicker", v}
      {"owner_id", v} -> {"ownerId", v}
      {k, v} -> {k, v}
    end)
    |> Map.new()
    |> Map.take([
      "name",
      "structureType",
      "structureTypeId",
      "status",
      "notes",
      "endTime",
      "ownerName",
      "ownerTicker",
      "ownerId",
      "character_eve_id"
    ])
  end
end
