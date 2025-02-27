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
  alias WandererApp.Helpers.Config

  @doc """
  Authenticates requests using the LM_AUTH_KEY.

  This is used for management endpoints that require administrative access.
  """
  def authenticate_lm(conn, _opts) do
    auth_header = get_req_header(conn, "authorization")
    lm_auth_key = Config.get_env(:wanderer_app, :lm_auth_key)

    case auth_header do
      ["Bearer " <> token] ->
        if token == lm_auth_key do
          conn
        else
          conn
          |> put_status(:unauthorized)
          |> json(%{error: "Invalid authentication token"})
          |> halt()
        end

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Missing authentication token"})
        |> halt()
    end
  end

  @doc """
  Authenticates requests using a license key.

  This is used for validation endpoints that check if a license is valid.
  """
  def authenticate_license(conn, _opts) do
    auth_header = get_req_header(conn, "authorization")

    case auth_header do
      ["Bearer " <> license_key] ->
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

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Missing license key"})
        |> halt()
    end
  end
end
