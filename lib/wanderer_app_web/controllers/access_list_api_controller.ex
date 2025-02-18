defmodule WandererAppWeb.MapAccessListAPIController do
  @moduledoc """
  API endpoints for managing Access Lists.

  Endpoints:
    - GET /api/map/acls?map_id=... or ?slug=...   (list ACLs)
    - POST /api/map/acls                            (create ACL)
    - GET /api/acls/:id                             (show ACL)
    - PUT /api/acls/:id                             (update ACL)

  ACL members are managed via a separate controller.
  """

  use WandererAppWeb, :controller
  alias WandererApp.Api.{AccessList, Character}
  alias WandererAppWeb.UtilAPIController, as: Util
  import Ash.Query
  require Logger

  @doc """
  GET /api/map/acls?map_id=... or ?slug=...

  Lists the ACLs for a given map.
  """
  def index(conn, params) do
    case Util.fetch_map_id(params) do
      {:ok, map_identifier} ->
        with {:ok, map} <- get_map(map_identifier),
             {:ok, loaded_map} <- Ash.load(map, :acls) do
          acls = loaded_map.acls || []
          json(conn, %{data: Enum.map(acls, &acl_to_list_json/1)})
        else
          {:error, :map_not_found} ->
            conn |> put_status(:not_found) |> json(%{error: "Map not found"})
          {:error, error} ->
            conn |> put_status(:internal_server_error) |> json(%{error: inspect(error)})
        end

      {:error, msg} ->
        conn |> put_status(:bad_request) |> json(%{error: msg})
    end
  end

  @doc """
  POST /api/map/acls

  Creates a new ACL for a map.
  """
  def create(conn, params) do
    with {:ok, map_identifier} <- Util.fetch_map_id(params),
         {:ok, map} <- get_map(map_identifier),
         %{"acl" => acl_params} <- params,
         owner_eve_id when not is_nil(owner_eve_id) <- Map.get(acl_params, "owner_eve_id"),
         owner_eve_id_str = to_string(owner_eve_id),
         {:ok, character} <- find_character_by_eve_id(owner_eve_id_str),
         {:ok, new_api_key} <- {:ok, UUID.uuid4()},
         {:ok, new_params} <- {:ok,
           acl_params
           |> Map.delete("owner_eve_id")
           |> Map.put("owner_id", character.id)
           |> Map.put("api_key", new_api_key)
         },
         {:ok, new_acl} <- AccessList.new(new_params),
         {:ok, _} <- associate_acl_with_map(map, new_acl)
    do
      json(conn, %{data: acl_to_json(new_acl)})
    else
      error ->
        conn |> put_status(:bad_request) |> json(%{error: inspect(error)})
    end
  end

  @doc """
  GET /api/acls/:id

  Shows a specific ACL (with its members).
  """
  def show(conn, %{"id" => id}) do
    query = AccessList |> Ash.Query.new() |> filter(id == ^id)
    case WandererApp.Api.read(query) do
      {:ok, [acl]} ->
        case Ash.load(acl, :members) do
          {:ok, loaded_acl} -> json(conn, %{data: acl_to_json(loaded_acl)})
          {:error, error} ->
            conn |> put_status(:internal_server_error) |> json(%{error: "Failed to load ACL members: #{inspect(error)}"})
        end

      {:ok, []} ->
        conn |> put_status(:not_found) |> json(%{error: "ACL not found"})
      {:error, error} ->
        conn |> put_status(:internal_server_error) |> json(%{error: "Error reading ACL: #{inspect(error)}"})
    end
  end

  @doc """
  PUT /api/acls/:id

  Updates an ACL.
  """
  def update(conn, %{"id" => id, "acl" => acl_params}) do
    with {:ok, acl} <- AccessList.by_id(id),
         {:ok, updated_acl} <- AccessList.update(acl, acl_params),
         {:ok, updated_acl} <- Ash.load(updated_acl, :members) do
      json(conn, %{data: acl_to_json(updated_acl)})
    else
      {:error, error} ->
        conn |> put_status(:bad_request) |> json(%{error: "Failed to update ACL: #{inspect(error)}"})
    end
  end

  defp get_map(map_identifier) do
    WandererApp.Api.Map.by_id(map_identifier)
  end

  defp acl_to_json(acl) do
    members =
      case acl.members do
        %Ash.NotLoaded{} -> []
        list when is_list(list) -> Enum.map(list, &member_to_json/1)
        _ -> []
      end

    %{
      id: acl.id,
      name: acl.name,
      description: acl.description,
      owner_id: acl.owner_id,
      api_key: acl.api_key,
      inserted_at: acl.inserted_at,
      updated_at: acl.updated_at,
      members: members
    }
  end

  defp acl_to_list_json(acl) do
    full_acl =
      case AccessList.by_id(acl.id) do
        {:ok, loaded_acl} -> loaded_acl
        _ -> acl
      end

    owner_eve_id =
      case find_character_by_id(full_acl.owner_id) do
        {:ok, character} -> character.eve_id
        _ -> nil
      end

    %{
      id: full_acl.id,
      name: full_acl.name,
      description: full_acl.description,
      owner_eve_id: owner_eve_id,
      inserted_at: full_acl.inserted_at,
      updated_at: full_acl.updated_at
    }
  end

  defp member_to_json(member) do
    %{
      id: member.id,
      name: member.name,
      role: member.role,
      eve_character_id: member.eve_character_id,
      inserted_at: member.inserted_at,
      updated_at: member.updated_at
    }
  end

  # Helper to find a character by external EVE id.
  defp find_character_by_eve_id(eve_id) do
    query = Character |> Ash.Query.new() |> filter(eve_id == ^eve_id)
    case WandererApp.Api.read(query) do
      {:ok, [character]} -> {:ok, character}
      {:ok, []} -> {:error, "owner_eve_id does not match any existing character"}
      other -> other
    end
  end

  # Helper to find a character by internal id.
  defp find_character_by_id(id) do
    query = Character |> Ash.Query.new() |> filter(id == ^id)
    case WandererApp.Api.read(query) do
      {:ok, [character]} -> {:ok, character}
      {:ok, []} -> {:error, "Character not found"}
      other -> other
    end
  end

  # Helper to associate a new ACL with a map.
  defp associate_acl_with_map(map, new_acl) do
    with {:ok, api_map} <- WandererApp.Api.Map.by_id(map.id),
         {:ok, loaded_map} <- Ash.load(api_map, :acls) do
      new_acl_id = if is_binary(new_acl), do: new_acl, else: new_acl.id
      current_acls = loaded_map.acls || []
      updated_acls = current_acls ++ [new_acl_id]

      case WandererApp.Api.Map.update_acls(loaded_map, %{acls: updated_acls}) do
        {:ok, updated_map} ->
          {:ok, updated_map}

        {:error, error} ->
          Logger.error("Failed to update map #{loaded_map.id} with new ACL: #{inspect(error)}")
          {:error, error}
      end
    else
      error ->
        Logger.error("Error loading map ACLs: #{inspect(error)}")
        {:error, error}
    end
  end
end
