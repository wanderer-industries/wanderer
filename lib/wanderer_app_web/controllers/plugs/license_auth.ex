defmodule WandererAppWeb.Plugs.LicenseAuth do
  @moduledoc """
  Plug for authenticating license API requests.

  This plug provides two authentication methods:
  1. LM_AUTH_KEY authentication for management endpoints
  2. License key authentication for validation endpoints
  """

  import Plug.Conn
  import Phoenix.Controller
  require Logger

  alias WandererApp.License.LicenseManager

  @doc """
  Authenticates requests using the LM_AUTH_KEY.

  This is used for management endpoints that require administrative access.
  """
  def authenticate_lm(conn, _opts) do
    auth_header = get_req_header(conn, "authorization")
    lm_auth_key = Application.get_env(:wanderer_app, :lm_auth_key)

    # Fail fast and log mis-configuration rather than crashing on secure_compare/2
    cond do
      is_nil(lm_auth_key) or lm_auth_key == "" ->
        Logger.error("LM auth key not configured – refusing all requests")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Authorization failure due to server error"})
        |> halt()

      true ->
        case auth_header do
          [header] when is_binary(header) ->
            case extract_bearer_token(header) do
              nil ->
                conn
                |> put_status(:unauthorized)
                |> json(%{error: "Invalid authentication format"})
                |> halt()

              token ->
                if Plug.Crypto.secure_compare(token, lm_auth_key) do
                  conn
                else
                  conn
                  |> put_status(:unauthorized)
                  |> json(%{error: "Invalid authentication token"})
                  |> halt()
                end
            end

          _ ->
            conn
            |> put_status(:unauthorized)
            |> json(%{error: "Missing authentication token"})
            |> halt()
        end
    end
  end

  @doc """
  Authenticates requests using a license key.

  This is used for validation endpoints that check if a license is valid.
  """
  def authenticate_license(conn, _opts) do
    auth_header = get_req_header(conn, "authorization")

    case auth_header do
      [header] when is_binary(header) ->
        case extract_bearer_token(header) do
          nil ->
            conn
            |> put_status(:unauthorized)
            |> json(%{error: "Invalid authentication format"})
            |> halt()

          license_key ->
            case LicenseManager.validate_license(license_key) do
              {:ok, license} ->
                conn
                |> assign(:license, license)

              {:error, :license_invalidated} ->
                conn
                |> put_status(:unauthorized)
                |> json(%{error: "License has been invalidated"})
                |> halt()

              {:error, :license_expired} ->
                conn
                |> put_status(:unauthorized)
                |> json(%{error: "License has expired"})
                |> halt()

              {:error, _} ->
                conn
                |> put_status(:unauthorized)
                |> json(%{error: "Invalid license key"})
                |> halt()
            end
        end

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Missing license key"})
        |> halt()
    end
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
