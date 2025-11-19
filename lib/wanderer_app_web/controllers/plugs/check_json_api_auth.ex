defmodule WandererAppWeb.Plugs.CheckJsonApiAuth do
  @moduledoc """
  Plug for authenticating JSON:API v1 endpoints.

  Supports both session-based authentication (for web clients) and
  Bearer token authentication (for API clients).

  Currently, Bearer token authentication only supports map API keys.
  When a valid map API key is provided, the map owner is set as the
  authenticated user and the map is made available in conn.assigns.

  """

  import Plug.Conn

  alias WandererApp.Api.User
  alias WandererApp.Api.ActorWithMap
  alias WandererApp.SecurityAudit
  alias WandererApp.Audit.RequestContext
  alias Ash.PlugHelpers

  # Error messages for different failure reasons
  @error_messages %{
    map_owner_not_found: "Authentication failed",
    invalid_token: "Authentication failed",
    missing_auth_header: "Missing or invalid authorization header",
    invalid_session: "Invalid session"
  }

  def init(opts), do: opts

  def call(conn, _opts) do
    start_time = System.monotonic_time(:millisecond)

    case authenticate_request(conn) do
      {:ok, user, map} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        # Log successful authentication
        request_details = extract_request_details(conn)
        SecurityAudit.log_auth_event(:auth_success, user.id, request_details)

        # Emit successful authentication event
        :telemetry.execute(
          [:wanderer_app, :json_api, :auth],
          %{count: 1, duration: duration},
          %{auth_type: get_auth_type(conn), result: "success"}
        )

        # Wrap user and map together as actor for Ash
        actor = ActorWithMap.new(user, map)

        conn
        |> assign(:current_user, user)
        |> assign(:current_user_role, get_user_role(user))
        |> PlugHelpers.set_actor(actor)
        |> maybe_assign_map(map)

      {:ok, user} ->
        # Backward compatibility for session auth without map
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        # Log successful authentication
        request_details = extract_request_details(conn)
        SecurityAudit.log_auth_event(:auth_success, user.id, request_details)

        # Emit successful authentication event
        :telemetry.execute(
          [:wanderer_app, :json_api, :auth],
          %{count: 1, duration: duration},
          %{auth_type: get_auth_type(conn), result: "success"}
        )

        # Wrap user with nil map as actor for Ash (session auth has no map context)
        actor = ActorWithMap.new(user, nil)

        conn
        |> assign(:current_user, user)
        |> assign(:current_user_role, get_user_role(user))
        |> PlugHelpers.set_actor(actor)

      {:error, reason} when is_atom(reason) ->
        # Error handling with atom reasons
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        # Get user-facing message from error messages map
        message = Map.get(@error_messages, reason, "Authentication failed")

        # Log failed authentication with detailed internal reason
        request_details = extract_request_details(conn)

        SecurityAudit.log_auth_event(
          :auth_failure,
          nil,
          Map.put(request_details, :failure_reason, reason)
        )

        # Emit failed authentication event
        :telemetry.execute(
          [:wanderer_app, :json_api, :auth],
          %{count: 1, duration: duration},
          %{auth_type: get_auth_type(conn), result: "failure"}
        )

        conn
        |> put_status(:unauthorized)
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: message}))
        |> halt()
    end
  end

  defp authenticate_request(conn) do
    # Try session-based auth first (for web clients)
    case get_session(conn, :user_id) do
      nil ->
        # Fallback to Bearer token auth
        authenticate_bearer_token(conn)

      user_id ->
        case User.by_id(user_id, load: :characters) do
          {:ok, user} -> {:ok, user}
          {:error, _} -> {:error, :invalid_session}
        end
    end
  end

  defp authenticate_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        validate_api_token(conn, token)

      _ ->
        {:error, :missing_auth_header}
    end
  end

  defp validate_api_token(_conn, token) do
    # Token determines map - no need to check request params
    find_map_by_token(token)
  end

  defp find_map_by_token(token) do
    case WandererApp.Api.Map.by_api_key(token, load: :owner) do
      {:ok, map} ->
        case User.by_id(map.owner.user_id, load: :characters) do
          {:ok, user} -> {:ok, user, map}
          _ -> {:error, :map_owner_not_found}
        end

      _ ->
        {:error, :invalid_token}
    end
  end

  defp get_user_role(user) do
    admins = WandererApp.Env.admins()

    case Enum.empty?(admins) or user.hash in admins do
      true -> :admin
      false -> :user
    end
  end

  defp get_auth_type(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> _token] ->
        "bearer_token"

      _ ->
        case get_session(conn, :user_id) do
          nil -> "none"
          _ -> "session"
        end
    end
  end

  defp extract_request_details(conn) do
    RequestContext.build_request_details(conn)
    |> Map.put(:auth_method, get_auth_type(conn))
  end

  defp maybe_assign_map(conn, nil), do: conn

  defp maybe_assign_map(conn, map) do
    conn
    |> assign(:map, map)
    |> assign(:map_id, map.id)
  end
end
