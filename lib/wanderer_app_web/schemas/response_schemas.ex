defmodule WandererAppWeb.Schemas.ResponseSchemas do
  @moduledoc """
  Common response schema patterns for API endpoints.

  This module provides standardized response schemas for common operations
  like delete confirmations, batch operations, and standard HTTP responses.
  """

  alias OpenApiSpex.Schema
  alias WandererAppWeb.Schemas.ApiSchemas

  @doc """
  Standard response specifications for common HTTP status codes.
  """
  def standard_responses(success_schema \\ nil) do
    base_responses = [
      bad_request: {
        "Bad Request",
        "application/json",
        ApiSchemas.legacy_error_response("Invalid request parameters")
      },
      unauthorized: {
        "Unauthorized",
        "application/json",
        ApiSchemas.legacy_error_response("Authentication required")
      },
      forbidden: {
        "Forbidden",
        "application/json",
        ApiSchemas.legacy_error_response("Insufficient permissions")
      },
      not_found: {
        "Not Found",
        "application/json",
        ApiSchemas.legacy_error_response("Resource not found")
      },
      unprocessable_entity: {
        "Unprocessable Entity",
        "application/json",
        ApiSchemas.error_response("Validation failed")
      },
      internal_server_error: {
        "Internal Server Error",
        "application/json",
        ApiSchemas.legacy_error_response("An unexpected error occurred")
      }
    ]

    if success_schema do
      [{:ok, {"Success", "application/json", success_schema}} | base_responses]
    else
      base_responses
    end
  end

  @doc """
  Response schema for delete operations.
  """
  def delete_response_schema do
    %Schema{
      type: :object,
      properties: %{
        data: %Schema{
          type: :object,
          properties: %{
            deleted: %Schema{type: :boolean, description: "Deletion success flag"}
          },
          required: ["deleted"]
        }
      },
      required: ["data"],
      example: %{data: %{deleted: true}}
    }
  end

  @doc """
  Response schema for bulk delete operations.
  """
  def bulk_delete_response_schema do
    %Schema{
      type: :object,
      properties: %{
        data: %Schema{
          type: :object,
          properties: %{
            deleted_count: %Schema{type: :integer, description: "Number of items deleted"}
          },
          required: ["deleted_count"]
        }
      },
      required: ["data"],
      example: %{data: %{deleted_count: 5}}
    }
  end

  @doc """
  Response schema for batch operations (create/update/delete).
  """
  def batch_operation_response_schema do
    %Schema{
      type: :object,
      properties: %{
        data: %Schema{
          type: :object,
          properties: %{
            created: %Schema{type: :integer, description: "Number of items created"},
            updated: %Schema{type: :integer, description: "Number of items updated"},
            deleted: %Schema{type: :integer, description: "Number of items deleted"},
            errors: %Schema{
              type: :array,
              items: %Schema{
                type: :object,
                properties: %{
                  index: %Schema{type: :integer, description: "Index of failed item"},
                  error: %Schema{type: :string, description: "Error message"}
                }
              },
              description: "List of errors for failed operations"
            }
          }
        }
      },
      required: ["data"],
      example: %{
        data: %{
          created: 3,
          updated: 2,
          deleted: 1,
          errors: []
        }
      }
    }
  end

  @doc """
  Specific batch response for systems and connections operations.
  """
  def systems_connections_batch_response do
    %Schema{
      type: :object,
      properties: %{
        data: %Schema{
          type: :object,
          properties: %{
            systems: %Schema{
              type: :object,
              properties: %{
                created: %Schema{type: :integer},
                updated: %Schema{type: :integer}
              },
              required: ~w(created updated)a
            },
            connections: %Schema{
              type: :object,
              properties: %{
                created: %Schema{type: :integer},
                updated: %Schema{type: :integer},
                deleted: %Schema{type: :integer}
              },
              required: ~w(created updated deleted)a
            }
          },
          required: ~w(systems connections)a
        }
      },
      example: %{
        data: %{
          systems: %{created: 2, updated: 1},
          connections: %{created: 1, updated: 0, deleted: 1}
        }
      }
    }
  end

  @doc """
  Standard responses for create operations (201 Created).
  """
  def create_responses(resource_schema) do
    [
      created: {"Created", "application/json", resource_schema}
    ] ++ standard_responses()
  end

  @doc """
  Standard responses for update operations.
  """
  def update_responses(resource_schema) do
    standard_responses(resource_schema)
  end

  @doc """
  Standard responses for delete operations (204 No Content).
  """
  def delete_responses(response_schema \\ nil) do
    if response_schema do
      standard_responses(response_schema)
    else
      [
        no_content: {"Deleted", nil, nil}
      ] ++ standard_responses()
    end
  end

  @doc """
  Response schema for operations that can return "created" or "exists".
  """
  def create_or_exists_response do
    %Schema{
      type: :object,
      properties: %{
        data: %Schema{
          type: :object,
          properties: %{
            result: %Schema{
              type: :string,
              enum: ["created", "exists"],
              description: "Operation result"
            }
          },
          required: ["result"]
        }
      },
      required: ["data"],
      example: %{data: %{result: "created"}}
    }
  end

  @doc """
  Standard OK response.
  """
  def ok(schema, description \\ "Success") do
    {description, "application/json", ApiSchemas.data_wrapper(schema)}
  end

  @doc """
  Standard bad request response.
  """
  def bad_request(message \\ "Bad Request") do
    {"Bad Request", "application/json", ApiSchemas.legacy_error_response(message)}
  end

  @doc """
  Standard unauthorized response.
  """
  def unauthorized(message \\ "Authentication required") do
    {"Unauthorized", "application/json", ApiSchemas.legacy_error_response(message)}
  end

  @doc """
  Standard forbidden response.
  """
  def forbidden(message \\ "Insufficient permissions") do
    {"Forbidden", "application/json", ApiSchemas.legacy_error_response(message)}
  end

  @doc """
  Standard not found response.
  """
  def not_found(message \\ "Resource not found") do
    {"Not Found", "application/json", ApiSchemas.legacy_error_response(message)}
  end

  @doc """
  Standard internal server error response.
  """
  def internal_server_error(message \\ "An unexpected error occurred") do
    {"Internal Server Error", "application/json", ApiSchemas.legacy_error_response(message)}
  end

  @doc """
  List response wrapper for arrays.
  """
  def list_response(item_schema) do
    ApiSchemas.data_wrapper(%Schema{
      type: :array,
      items: item_schema
    })
  end

  @doc """
  Single item response wrapper.
  """
  def item_response(item_schema) do
    ApiSchemas.data_wrapper(item_schema)
  end

  @doc """
  Empty response for 204 No Content.
  """
  def no_content_response do
    {nil, nil, nil}
  end
end
