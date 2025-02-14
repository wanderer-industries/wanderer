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
  # Do not alias Map—to avoid conflicts—use the full module name: WandererApp.Map.
  alias WandererAppWeb.UtilAPIController, as: Util
  import Ash.Query

  # List ACLs for a given map
  def index(conn, params) do
    case Util.fetch_map_id(params) do
      {:ok, map_identifier} ->
        with {:ok, map} <- get_map(map_identifier) do
          acls = map.acls || []
          json(conn, %{data: Enum.map(acls, &acl_to_json/1)})
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

  # Create a new ACL for a map
  def create(conn, params) do
    with {:ok, map_identifier} <- Util.fetch_map_id(params),
         {:ok, map} <- get_map(map_identifier),
         %{"acl" => acl_params} <- params,
         owner_eve_id when is_binary(owner_eve_id) <- Map.get(acl_params, "owner_eve_id"),
         {:ok, query} <- {:ok, Character |> Ash.Query.new() |> filter(eve_id == ^owner_eve_id)},
         {:ok, characters} <- WandererApp.Api.read(query),
         [character] <- characters,
         {:ok, new_api_key} <- {:ok, UUID.uuid4()},
         {:ok, new_params} <- {:ok,
           acl_params
           |> Map.delete("owner_eve_id")
           |> Map.put("owner_id", character.id)
           |> Map.put("api_key", new_api_key)
         },
         {:ok, new_acl} <- AccessList.new(new_params),
         {:ok, _} <- {:ok, associate_acl_with_map(map, new_acl)}
    do
      json(conn, %{data: acl_to_json(new_acl)})
    else
      error ->
        conn |> put_status(:bad_request) |> json(%{error: inspect(error)})
    end
  end

  # Show a specific ACL (with members)
  def show(conn, %{"id" => id}) do
    query = AccessList |> Ash.Query.new() |> filter(id == ^id)
    case WandererApp.Api.read(query) do
      {:ok, [acl]} ->
        case Ash.load(acl, :members) do
          {:ok, loaded_acl} -> json(conn, %{data: acl_to_json(loaded_acl)})
          {:error, error} -> conn |> put_status(:internal_server_error) |> json(%{error: "Failed to load ACL members: #{inspect(error)}"})
        end
      {:ok, []} ->
        conn |> put_status(:not_found) |> json(%{error: "ACL not found"})
      {:error, error} ->
        conn |> put_status(:internal_server_error) |> json(%{error: "Error reading ACL: #{inspect(error)}"})
    end
  end

  # Update an ACL (if needed)
  def update(conn, %{"id" => id, "acl" => acl_params}) do
    with {:ok, acl} <- AccessList.by_id(id),
         # Update the record using the fetched ACL struct.
         {:ok, updated_acl} <- AccessList.update(acl, acl_params),
         {:ok, updated_acl} <- Ash.load(updated_acl, :members) do
      json(conn, %{data: acl_to_json(updated_acl)})
    else
      {:error, error} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Failed to update ACL: #{inspect(error)}"})
    end
  end

  # Helper to get the map (using your module WandererApp.Map)
  defp get_map(map_identifier) do
    # Assuming Util.fetch_map_id returns a map id.
    case WandererApp.Map.get_map(map_identifier) do
      {:ok, map} -> {:ok, map}
      other -> other
    end
  end

  # Helper to convert ACL to JSON
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

  # Associate the new ACL with the map by updating the map's acls list.
  defp associate_acl_with_map(map, new_acl) do
    current_acls = map.acls || []
    updated_acls = current_acls ++ [new_acl]
    # Update the map using your Map module's update_map/2 function.
    case WandererApp.Map.update_map(map.map_id, %{acls: updated_acls}) do
      _ -> :ok
    end
  end
end
