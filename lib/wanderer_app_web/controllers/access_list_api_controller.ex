defmodule WandererAppWeb.MapAccessListAPIController do
  @moduledoc """
  API endpoints for fetching and updating Access Lists

  Endpoints (under /api/acls):
    - GET /api/acls?map_id=... or ?slug=...   (index)
    - POST /api/acls                         (create)
    - GET /api/acls/:id                      (show)
    - PUT /api/acls/:id                      (update)

  Members are handled by AccessListMemberAPIController, which has:
    - POST /api/acls/:acl_id/members
    - PUT /api/acls/:acl_id/members/:member_id  (member_id here is the external EVE id)
    - DELETE /api/acls/:acl_id/members/:member_id (member_id here is the external EVE id)
  """

  use WandererAppWeb, :controller
  alias WandererApp.Api.{AccessList, Map}
  alias WandererAppWeb.UtilAPIController, as: Util
  import Ash.Query

  @doc """
  GET /api/acls?map_id=... or ?slug=...

  Fetches ACLs for a given map if provided.
  Returns a 400 error if neither a map_id nor slug is provided.
  """
  def index(conn, params) do
    case Util.fetch_map_id(params) do
      {:ok, map_identifier} ->
        with {:ok, map} <- get_map(map_identifier) do
          acls = map.acls || []
          json(conn, %{data: Enum.map(acls, &acl_to_json/1)})
        else
          {:error, :map_not_found} ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "Map not found"})

          {:error, error} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: inspect(error)})
        end

      {:error, msg} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: msg})
    end
  end

  @doc """
  GET /api/acls/:id

  Returns a single ACL (with members preloaded).
  If no matching ACL is found, returns 404.
  """
  def show(conn, %{"id" => id}) do
    query =
      AccessList
      |> Ash.Query.new()
      |> filter(id == ^id)

    case WandererApp.Api.read(query) do
      {:ok, [acl]} ->
        case Ash.load(acl, :members) do
          {:ok, loaded_acl} ->
            json(conn, %{data: acl_to_json(loaded_acl)})

          {:error, error} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "Failed to load ACL members: #{inspect(error)}"})
        end

      {:ok, []} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "ACL not found"})

      {:error, error} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Error reading ACL: #{inspect(error)}"})
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Fetch the map by UUID (the slug has been converted to a UUID by Util.fetch_map_id)
  # then preload its ACLs.
  defp get_map(map_identifier) do
    query =
      Map
      |> Ash.Query.new()
      |> filter(id == ^map_identifier)
      |> load([:acls])

    case WandererApp.Api.read(query) do
      {:ok, [map]} ->
        {:ok, map}

      {:ok, []} ->
        {:error, :map_not_found}

      {:error, error} ->
        {:error, error}
    end
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
end
