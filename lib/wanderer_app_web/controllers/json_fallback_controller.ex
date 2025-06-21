defmodule WandererAppWeb.JsonFallbackController do
  @moduledoc """
  Fallback controller for JSON API endpoints.

  This controller handles errors that occur in JSON API endpoints,
  ensuring proper JSON error responses with appropriate status codes.
  """

  use WandererAppWeb, :controller

  alias WandererAppWeb.Helpers.APIUtils

  # Handles not_found errors from with/else
  def call(conn, {:error, :not_found}) do
    APIUtils.error_response(
      conn,
      :not_found,
      "Not found",
      "The requested resource could not be found"
    )
  end

  # Handles invalid_id errors
  def call(conn, {:error, :invalid_id}) do
    APIUtils.error_response(conn, :bad_request, "Invalid system ID")
  end

  # Handles invalid_coordinates_format errors
  def call(conn, {:error, :invalid_coordinates_format}) do
    APIUtils.error_response(
      conn,
      :bad_request,
      "Invalid coordinates format. Use %{\"coordinates\" => %{\"x\" => number, \"y\" => number}}"
    )
  end

  # Handles not_associated errors
  def call(conn, {:error, :not_associated}) do
    APIUtils.error_response(conn, :not_found, "Connection not associated with specified system")
  end

  # Handles not_involved errors
  def call(conn, {:error, :not_involved}) do
    APIUtils.error_response(conn, :bad_request, "Connection must involve specified system")
  end

  # Handles creation_failed errors
  def call(conn, {:error, :creation_failed}) do
    APIUtils.error_response(conn, :internal_server_error, "Failed to create resource")
  end

  # Handles deletion_failed errors
  def call(conn, {:error, :deletion_failed}) do
    APIUtils.error_response(conn, :internal_server_error, "Failed to delete resource")
  end

  # Handles any other {:error, message} returns
  def call(conn, {:error, msg}) when is_binary(msg) do
    APIUtils.error_response(conn, :bad_request, msg)
  end

  # Handles Ecto changeset errors for standardized validation
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> Phoenix.Controller.json(WandererAppWeb.Validations.ApiValidations.format_errors(changeset))
  end

  # Handles Ash validation errors
  def call(conn, {:error, %Ash.Error.Invalid{} = error}) do
    # Convert Ash errors to a format similar to Ecto changeset errors
    formatted_errors = %{
      errors:
        Enum.map(error.errors, fn ash_error ->
          %{
            field: ash_error.field || "base",
            message: ash_error.message || "Invalid value"
          }
        end)
    }

    conn
    |> put_status(:unprocessable_entity)
    |> Phoenix.Controller.json(formatted_errors)
  end

  # Handles authorization errors
  def call(conn, {:error, :unauthorized}) do
    APIUtils.error_response(conn, :unauthorized, "Unauthorized access")
  end

  def call(conn, {:error, :forbidden}) do
    APIUtils.error_response(conn, :forbidden, "Access forbidden")
  end

  # Handles rate limiting errors
  def call(conn, {:error, :rate_limited}) do
    APIUtils.error_response(conn, :too_many_requests, "Rate limit exceeded")
  end

  # Handles any other unmatched errors
  def call(conn, _error) do
    APIUtils.error_response(conn, :internal_server_error, "An unexpected error occurred")
  end
end
