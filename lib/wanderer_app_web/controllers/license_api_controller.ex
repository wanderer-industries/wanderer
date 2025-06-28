defmodule WandererAppWeb.LicenseApiController do
  @moduledoc """
  Controller for the Bot License API.

  This controller provides endpoints for:
  - Creating new licenses for maps with active subscriptions
  - Updating license validity and expiration
  - Validating license keys

  All endpoints require proper authentication.
  """

  use WandererAppWeb, :controller
  require Logger

  alias WandererApp.License.LicenseManager
  alias WandererApp.Api.License
  alias WandererApp.Api.Map

  @doc """
  Creates a new license for a map.

  Requires LM_AUTH_KEY authentication.

  ## Request

  POST /api/licenses

  ```json
  {
    "map_id": "uuid-of-map"
  }
  ```

  ## Response

  ```json
  {
    "id": "license-uuid",
    "license_key": "BOT-XXXXXXXXXXXX",
    "is_valid": true,
    "expire_at": "2024-12-31T23:59:59Z",
    "map_id": "uuid-of-map"
  }
  ```
  """
  def create(conn, %{"map_id" => map_id}) do
    with {:ok, _map} <- Map.by_id(map_id),
         {:ok, license} <- LicenseManager.create_license_for_map(map_id) do
      conn
      |> put_status(:created)
      |> json(format_license(license))
    else
      {:error, :no_active_subscription} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Map does not have an active subscription"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Map not found"})

      {:error, reason} ->
        Logger.error("Failed to create license: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to create license"})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameter: map_id"})
  end

  @doc """
  Updates a license's validity status.

  Requires LM_AUTH_KEY authentication.

  ## Request

  PUT /api/licenses/:id/validity

  ```json
  {
    "is_valid": true
  }
  ```

  ## Response

  ```json
  {
    "id": "license-uuid",
    "license_key": "BOT-XXXXXXXXXXXX",
    "is_valid": true,
    "expire_at": "2024-12-31T23:59:59Z",
    "map_id": "uuid-of-map"
  }
  ```
  """
  def update_validity(conn, %{"id" => license_id, "is_valid" => is_valid}) do
    with {:ok, license} <- License.by_id(license_id),
         {:ok, updated_license} <- LicenseManager.invalidate_license(license_id) do
      conn
      |> json(format_license(updated_license))
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "License not found"})

      {:error, reason} ->
        Logger.error("Failed to update license validity: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to update license validity"})
    end
  end

  def update_validity(conn, %{"id" => _license_id}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameter: is_valid"})
  end

  @doc """
  Updates a license's expiration date.

  Requires LM_AUTH_KEY authentication.

  ## Request

  PUT /api/licenses/:id/expiration

  ```json
  {
    "expire_at": "2024-12-31T23:59:59Z"
  }
  ```

  ## Response

  ```json
  {
    "id": "license-uuid",
    "license_key": "BOT-XXXXXXXXXXXX",
    "is_valid": true,
    "expire_at": "2024-12-31T23:59:59Z",
    "map_id": "uuid-of-map"
  }
  ```
  """
  def update_expiration(conn, %{"id" => license_id, "expire_at" => expire_at}) do
    with {:ok, _license} <- License.by_id(license_id),
         {:ok, updated_license} <- LicenseManager.update_expiration(license_id, expire_at) do
      conn
      |> json(format_license(updated_license))
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "License not found"})

      {:error, reason} ->
        Logger.error("Failed to update license expiration: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to update license expiration"})
    end
  end

  def update_expiration(conn, %{"id" => _license_id}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameter: expire_at"})
  end

  @doc """
  Gets a license by map ID.

  Requires LM_AUTH_KEY authentication.

  ## Request

  GET /api/licenses/map/:map_id

  ## Response

  ```json
  {
    "id": "license-uuid",
    "license_key": "BOT-XXXXXXXXXXXX",
    "is_valid": true,
    "expire_at": "2024-12-31T23:59:59Z",
    "map_id": "uuid-of-map"
  }
  ```
  """
  def get_by_map_id(conn, %{"map_id" => map_id}) do
    case LicenseManager.get_license_by_map_id(map_id) do
      {:ok, license} ->
        conn
        |> json(format_license(license))

      {:error, :license_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "No license found for this map"})

      {:error, reason} ->
        Logger.error("Failed to get license by map ID: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to get license"})
    end
  end

  @doc """
  Validates a license key.

  Requires the license key as a Bearer token in the Authorization header.

  ## Request

  GET /api/license/validate

  ## Response

  ```json
  {
    "license_valid": true,
    "expire_at": "2024-12-31T23:59:59Z",
    "map_id": "uuid-of-map"
  }
  ```
  """
  def validate(conn, _params) do
    license = conn.assigns.license

    conn
    |> json(%{
      license_valid: license.is_valid,
      expire_at: license.expire_at,
      map_id: license.map_id
    })
  end

  # Helper to format license for JSON response
  defp format_license(license) do
    %{
      id: license.id,
      license_key: license.license_key,
      is_valid: license.is_valid,
      expire_at: license.expire_at,
      map_id: license.map_id
    }
  end
end
