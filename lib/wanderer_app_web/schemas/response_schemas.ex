defmodule WandererAppWeb.Schemas.ResponseSchemas do
  @moduledoc """
  Standard response schema definitions for API responses.

  This module provides helper functions to create standardized
  HTTP response schemas for OpenAPI documentation.
  """

  alias WandererAppWeb.Schemas.ApiSchemas

  # Standard response status codes
  def ok(schema, description \\ "Successful operation") do
    {
      description,
      "application/json",
      schema
    }
  end

  def created(schema, description \\ "Resource created") do
    {
      description,
      "application/json",
      schema
    }
  end

  def bad_request(description \\ "Bad request") do
    {
      description,
      "application/json",
      ApiSchemas.error_response(description)
    }
  end

  def not_found(description \\ "Resource not found") do
    {
      description,
      "application/json",
      ApiSchemas.error_response(description)
    }
  end

  def internal_server_error(description \\ "Internal server error") do
    {
      description,
      "application/json",
      ApiSchemas.error_response(description)
    }
  end

  def unauthorized(description \\ "Unauthorized") do
    {
      description,
      "application/json",
      ApiSchemas.error_response(description)
    }
  end

  def forbidden(description \\ "Forbidden") do
    {
      description,
      "application/json",
      ApiSchemas.error_response(description)
    }
  end

  # Helper for common response patterns
  def standard_responses(success_schema, success_description \\ "Successful operation") do
    [
      ok: ok(success_schema, success_description),
      bad_request: bad_request(),
      not_found: not_found(),
      internal_server_error: internal_server_error()
    ]
  end

  # Helper for create operation responses
  def create_responses(created_schema, created_description \\ "Resource created") do
    [
      created: created(created_schema, created_description),
      bad_request: bad_request(),
      internal_server_error: internal_server_error()
    ]
  end

  # Helper for update operation responses
  def update_responses(updated_schema, updated_description \\ "Resource updated") do
    [
      ok: ok(updated_schema, updated_description),
      bad_request: bad_request(),
      not_found: not_found(),
      internal_server_error: internal_server_error()
    ]
  end

  # Helper for delete operation responses
  def delete_responses(deleted_schema \\ nil, deleted_description \\ "Resource deleted") do
    if deleted_schema do
      [
        ok: ok(deleted_schema, deleted_description),
        not_found: not_found(),
        internal_server_error: internal_server_error()
      ]
    else
      [
        no_content: {deleted_description <> " (no content)", nil, nil},
        not_found: not_found(),
        internal_server_error: internal_server_error()
      ]
    end
  end
end
