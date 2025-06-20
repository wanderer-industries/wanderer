defmodule WandererAppWeb.Plugs.CheckMapApiKey do
  @behaviour Plug

  import Plug.Conn
  alias Plug.Crypto
  alias WandererApp.Api.Map, as: ApiMap
  alias WandererAppWeb.Schemas.ResponseSchemas, as: R
  require Logger

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    with [auth_header] <- get_req_header(conn, "authorization"),
         token when is_binary(token) <- extract_bearer_token(auth_header),
         {:ok, map_id} <- fetch_map_id(conn),
         {:ok, map} <- ApiMap.by_id(map_id),
         true <-
           is_binary(map.public_api_key) &&
             Crypto.secure_compare(map.public_api_key, token) do
      conn
      |> assign(:map, map)
      |> assign(:map_id, map.id)
    else
      [] ->
        Logger.warning("Missing or invalid 'Bearer' token")
        conn |> respond(401, "Missing or invalid 'Bearer' token") |> halt()

      {:error, :bad_request, msg} ->
        Logger.warning("Bad request: #{msg}")
        conn |> respond(400, msg) |> halt()

      {:error, :not_found, msg} ->
        Logger.warning("Not found: #{msg}")
        conn |> respond(404, msg) |> halt()

      {:error, _} ->
        Logger.warning("Map identifier required")

        conn
        |> respond(
          400,
          "Map identifier required. Provide `map_identifier` in the path or `map_id`/`slug` in query."
        )
        |> halt()

      false ->
        Logger.warning(
          "Unauthorized: invalid token for map #{inspect(conn.params["map_identifier"])}"
        )

        conn |> respond(401, "Unauthorized (invalid token for map)") |> halt()

      error ->
        Logger.error("Unexpected error: #{inspect(error)}")
        conn |> respond(500, "Unexpected error") |> halt()
    end
  end

  # Try unified path param first, then fall back to legacy query params
  defp fetch_map_id(%Plug.Conn{params: %{"map_identifier" => id}})
       when is_binary(id) and id != "" do
    resolve_identifier(id)
  end

  defp fetch_map_id(conn), do: legacy_fetch(conn)

  # Try ID lookup first, then slug lookup
  defp resolve_identifier(id) do
    case ApiMap.by_id(id) do
      {:ok, %{id: map_id}} ->
        {:ok, map_id}

      _ ->
        case ApiMap.get_map_by_slug(id) do
          {:ok, %{id: map_id}} ->
            {:ok, map_id}

          _ ->
            {:error, :not_found, "Map not found for identifier: #{id}"}
        end
    end
  end

  # Legacy: check assigns, then params["map_id"], then params["slug"]
  defp legacy_fetch(conn) do
    map_id_from_assign = conn.assigns[:map_id]
    map_id_param = conn.params["map_id"]
    slug_param = conn.params["slug"]

    cond do
      is_binary(map_id_from_assign) and map_id_from_assign != "" ->
        {:ok, map_id_from_assign}

      is_binary(map_id_param) and map_id_param != "" ->
        {:ok, map_id_param}

      is_binary(slug_param) and slug_param != "" ->
        case ApiMap.get_map_by_slug(slug_param) do
          {:ok, %{id: map_id}} -> {:ok, map_id}
          _ -> {:error, :not_found, "Map not found for slug: #{slug_param}"}
        end

      true ->
        {:error, :bad_request,
         "Map identifier required. Provide `map_identifier` in the path or `map_id`/`slug` in query."}
    end
  end

  # Pick the right shared schema and send JSON
  defp respond(conn, status, msg) do
    {_desc, content_type, _schema} =
      case status do
        400 -> R.bad_request(msg)
        401 -> R.unauthorized(msg)
        404 -> R.not_found(msg)
        500 -> R.internal_server_error(msg)
        _ -> R.internal_server_error("Unexpected error")
      end

    conn
    |> put_resp_content_type(content_type)
    |> send_resp(status, Jason.encode!(%{error: msg}))
  end

  # Extract token from Authorization header (case-insensitive)
  defp extract_bearer_token(auth_header) do
    case String.split(auth_header, " ", parts: 2) do
      [scheme, token] ->
        if String.downcase(scheme) == "bearer" do
          token
        else
          nil
        end
      _ ->
        nil
    end
  end
end
