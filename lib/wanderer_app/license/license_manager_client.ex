defmodule WandererApp.License.LicenseManagerClient do
  @moduledoc """
  Client for interacting with the external License Manager API.

  This module provides functions to create, update, and validate licenses
  through the external License Manager API.
  """

  require Logger

  @doc """
  Creates a new license in the License Manager.

  ## Parameters

  - `license_params` - Map containing license details:
    - `name` (required) - Name of the license
    - `description` (optional) - Description of the license
    - `is_valid` (optional) - Boolean indicating if the license is valid
    - `valid_to` (optional) - Expiration date in YYYY-MM-DD format
    - `link` (required) - URL associated with the license
    - `contact_email` (optional) - Contact email for the license

  ## Returns

  - `{:ok, license}` - On successful creation
  - `{:error, reason}` - On failure
  """
  def create_license(license_params) do
    url = "#{api_url()}/api/manage/licenses"

    auth_opts = [auth: {:bearer, auth_key()}]

    log_request("POST", url, license_params)

    with {:ok, %{status: status, body: license}} when status in 200..299 <-
           Req.post(url, [json: license_params] ++ auth_opts) do
      log_response(status, license)
      {:ok, license}
    else
      {:ok, %{status: status, body: body}} ->
        Logger.error("Failed to create license. Status: #{status}, Body: #{body}")
        parse_error_response(status, body)

      {:error, error} ->
        Logger.error("HTTP request failed: #{inspect(error)}")
        {:error, :request_failed}
    end
  end

  @doc """
  Updates an existing license in the License Manager.

  ## Parameters

  - `license_id` - ID of the license to update
  - `update_params` - Map containing fields to update:
    - `is_valid` (optional) - Boolean indicating if the license is valid
    - `valid_to` (optional) - Expiration date in YYYY-MM-DD format

  ## Returns

  - `{:ok, license}` - On successful update
  - `{:error, reason}` - On failure
  """
  def update_license(license_id, update_params) do
    url = "#{api_url()}/api/manage/licenses/#{license_id}"

    auth_opts = [auth: {:bearer, auth_key()}]

    log_request("PUT", url, update_params)

    with {:ok, %{status: status, body: license}} when status in 200..299 <-
           Req.put(url, [json: update_params] ++ auth_opts) do
      log_response(status, license)
      {:ok, license}
    else
      {:ok, %{status: status, body: body}} ->
        Logger.error("Failed to update license. Status: #{status}, Body: #{inspect(body)}")
        parse_error_response(status, body)

      {:error, error} ->
        Logger.error("HTTP request failed: #{inspect(error)}")
        {:error, :request_failed}
    end
  end

  @doc """
  Validates a license key.

  ## Parameters

  - `license_key` - The license key to validate

  ## Returns

  - `{:ok, result}` - On successful validation, where result is a map containing:
    - `license_valid` - Boolean indicating if the license is valid
    - `valid_to` - Expiration date of the license
    - `license_id` - UUID of the license
    - `license_name` - Name of the license
    - `bots` - List of associated bots with their details
  - `{:error, reason}` - On failure
  """
  def validate_license(license_key) do
    url = "#{api_url()}/api/license/validate"

    auth_opts = [auth: {:bearer, license_key}]

    log_request("GET", url, nil)

    with {:ok, %{status: 200, body: validation_result}} <- Req.get(url, auth_opts) do
      log_response(200, validation_result)
      {:ok, validation_result}
    else
      {:ok, %{status: 401}} ->
        {:error, :invalid_license}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Failed to validate license. Status: #{status}, Body: #{body}")
        parse_error_response(status, body)

      {:error, error} ->
        Logger.error("HTTP request failed: #{inspect(error)}")
        {:error, :request_failed}
    end
  end

  # Private helper functions
  defp api_url do
    Application.get_env(:wanderer_app, :license_manager)[:api_url]
  end

  defp auth_key do
    Application.get_env(:wanderer_app, :license_manager)[:auth_key]
  end

  defp parse_error_response(status, %{"error" => error_message}) do
    {:error, error_message}
  end

  defp parse_error_response(status, error) do
    {:error, "HTTP #{status}: #{inspect(error)}"}
  end

  defp log_request(method, url, params) do
    Logger.info("License Manager API Request: #{method} #{url}")
    Logger.debug("License Manager API Params: #{inspect(params)}")
  end

  defp log_response(status, body) do
    Logger.info("License Manager API Response: Status #{status}")
    Logger.debug("License Manager API Response Body: #{inspect(body)}")
  end
end
