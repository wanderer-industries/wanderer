defmodule WandererAppWeb.FallbackController do
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

  # Handles any other unmatched errors
  def call(conn, _error) do
    APIUtils.error_response(conn, :internal_server_error, "An unexpected error occurred")
  end
end
