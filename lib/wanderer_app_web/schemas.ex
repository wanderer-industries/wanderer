defmodule WandererAppWeb.Schemas do
  @moduledoc """
  Centralized OpenAPI schemas for the Wanderer API.

  This module consolidates common schema definitions used across multiple controllers
  to reduce duplication and ensure consistency.
  """

  alias OpenApiSpex.Schema
  require OpenApiSpex

  # Re-export existing schema modules for convenience
  defdelegate data_wrapper(schema, description \\ nil), to: WandererAppWeb.Schemas.ApiSchemas
  defdelegate error_response(description \\ nil), to: WandererAppWeb.Schemas.ApiSchemas
  defdelegate legacy_error_response(description \\ nil), to: WandererAppWeb.Schemas.ApiSchemas
  defdelegate paginated_response(item_schema), to: WandererAppWeb.Schemas.ApiSchemas
  defdelegate character_schema(), to: WandererAppWeb.Schemas.ApiSchemas

  # Common field schemas
  @doc "UUID field schema"
  def uuid_schema(description \\ nil) do
    %Schema{
      type: :string,
      format: :uuid,
      description: description
    }
  end

  @doc "Timestamp field schema"
  def timestamp_schema(description \\ nil) do
    %Schema{
      type: :string,
      format: :"date-time",
      description: description
    }
  end

  @doc "Integer ID field schema"
  def integer_id_schema(description \\ nil) do
    %Schema{
      type: :integer,
      description: description
    }
  end

  # Common request schemas
  @doc "Generic create request schema"
  def create_request_schema(properties, required_fields \\ []) do
    %Schema{
      type: :object,
      properties: properties,
      required: required_fields
    }
  end

  @doc "Generic update request schema"
  def update_request_schema(properties) do
    %Schema{
      type: :object,
      properties: properties
    }
  end

  # Common response schemas
  @doc "Generic show response schema"
  def show_response_schema(resource_schema, description \\ nil) do
    schema = data_wrapper(resource_schema)
    if description, do: %{schema | description: description}, else: schema
  end

  @doc "Generic index response schema"
  def index_response_schema(resource_schema, description \\ nil) do
    schema =
      data_wrapper(%Schema{
        type: :array,
        items: resource_schema
      })

    if description, do: %{schema | description: description}, else: schema
  end

  @doc "Generic create response schema"
  def create_response_schema(resource_schema, description \\ nil) do
    schema = data_wrapper(resource_schema)
    description = description || "Created resource"
    %{schema | description: description}
  end

  @doc "Generic update response schema"
  def update_response_schema(resource_schema, description \\ nil) do
    schema = data_wrapper(resource_schema)
    description = description || "Updated resource"
    %{schema | description: description}
  end

  @doc "Generic delete response schema"
  def delete_response_schema(description \\ nil) do
    %Schema{
      type: :object,
      properties: %{
        message: %Schema{type: :string, description: "Success message"}
      },
      required: ["message"],
      description: description || "Delete confirmation"
    }
  end

  @doc "Batch operation response schema"
  def batch_operation_response_schema(description \\ nil) do
    %Schema{
      type: :object,
      properties: %{
        success: %Schema{type: :integer, description: "Number of successful operations"},
        failed: %Schema{type: :integer, description: "Number of failed operations"},
        errors: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              id: %Schema{type: :string, description: "Resource ID that failed"},
              error: %Schema{type: :string, description: "Error message"}
            }
          },
          description: "List of errors for failed operations"
        }
      },
      required: ["success", "failed"],
      description: description || "Batch operation result"
    }
  end

  # Authentication schemas
  @doc "Bearer token authentication schema"
  def bearer_auth_schema() do
    %Schema{
      type: :string,
      pattern: "^Bearer .+$",
      description: "Bearer token for authentication"
    }
  end

  @doc "API key authentication schema"
  def api_key_schema(description \\ nil) do
    %Schema{
      type: :string,
      description: description || "API key for authentication"
    }
  end

  # Pagination schemas
  @doc "Pagination request parameters"
  def pagination_params() do
    [
      page: [
        in: :query,
        description: "Page number",
        type: :integer,
        default: 1
      ],
      page_size: [
        in: :query,
        description: "Number of items per page",
        type: :integer,
        default: 20
      ]
    ]
  end

  # EVE Online specific schemas
  @doc "EVE character ID schema"
  def eve_character_id_schema(description \\ nil) do
    %Schema{
      type: :integer,
      description: description || "EVE Online character ID"
    }
  end

  @doc "EVE solar system ID schema"
  def eve_solar_system_id_schema(description \\ nil) do
    %Schema{
      type: :integer,
      description: description || "EVE Online solar system ID"
    }
  end

  @doc "EVE ship type ID schema"
  def eve_ship_type_id_schema(description \\ nil) do
    %Schema{
      type: :integer,
      description: description || "EVE Online ship type ID"
    }
  end

  # Common filter schemas
  @doc "Date range filter schema"
  def date_range_filter_schema() do
    %Schema{
      type: :object,
      properties: %{
        from: timestamp_schema("Start date"),
        to: timestamp_schema("End date")
      }
    }
  end

  @doc "Search filter schema"
  def search_filter_schema(searchable_fields) do
    %Schema{
      type: :object,
      properties: %{
        query: %Schema{type: :string, description: "Search query"},
        fields: %Schema{
          type: :array,
          items: %Schema{
            type: :string,
            enum: searchable_fields
          },
          description: "Fields to search in"
        }
      }
    }
  end

  # Status and state schemas
  @doc "Generic status schema"
  def status_schema(valid_statuses, description \\ nil) do
    %Schema{
      type: :string,
      enum: valid_statuses,
      description: description || "Current status"
    }
  end

  @doc "Boolean flag schema"
  def boolean_flag_schema(description) do
    %Schema{
      type: :boolean,
      description: description
    }
  end

  # Metadata schemas
  @doc "Generic metadata schema"
  def metadata_schema(description \\ nil) do
    %Schema{
      type: :object,
      additionalProperties: true,
      description: description || "Additional metadata"
    }
  end

  @doc "Tags schema"
  def tags_schema(description \\ nil) do
    %Schema{
      type: :array,
      items: %Schema{type: :string},
      description: description || "List of tags"
    }
  end

  # Error response schemas
  @doc "Standard error response schema"
  def error_schema(description \\ nil) do
    %Schema{
      type: :object,
      properties: %{
        error: %Schema{type: :string, description: "Error message"}
      },
      required: ["error"],
      description: description || "Error response"
    }
  end

  @doc "Detailed error response schema with additional fields"
  def detailed_error_schema(description \\ nil) do
    %Schema{
      type: :object,
      properties: %{
        error: %Schema{type: :string, description: "Error message"},
        details: %Schema{type: :string, description: "Additional error details"},
        code: %Schema{type: :string, description: "Error code"},
        field: %Schema{type: :string, description: "Field that caused the error"}
      },
      required: ["error"],
      description: description || "Detailed error response"
    }
  end

  @doc "Validation error response schema"
  def validation_error_schema(description \\ nil) do
    %Schema{
      type: :object,
      properties: %{
        errors: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              field: %Schema{type: :string, description: "Field name"},
              message: %Schema{type: :string, description: "Error message"},
              code: %Schema{type: :string, description: "Error code"}
            },
            required: ["field", "message"]
          },
          description: "List of validation errors"
        }
      },
      required: ["errors"],
      description: description || "Validation error response"
    }
  end

  # Helper functions
  @doc "Merge multiple schemas into one"
  def merge_schemas(schemas) when is_list(schemas) do
    Enum.reduce(schemas, %Schema{type: :object, properties: %{}}, fn schema, acc ->
      %{acc | properties: Map.merge(acc.properties, schema.properties || %{})}
    end)
  end

  @doc "Create enum schema from list"
  def enum_schema(values, description \\ nil) when is_list(values) do
    %Schema{
      type: :string,
      enum: values,
      description: description
    }
  end

  @doc "Create nullable schema"
  def nullable(schema) do
    %{schema | nullable: true}
  end

  @doc "Add example to schema"
  def with_example(schema, example) do
    %{schema | example: example}
  end

  # Response helpers for controllers
  @doc "Generate standard API responses for OpenApiSpex operations"
  def standard_responses(additional_responses \\ []) do
    base_responses = [
      bad_request: {"Bad request", "application/json", error_schema()},
      unauthorized: {"Unauthorized", "application/json", error_schema()},
      forbidden: {"Forbidden", "application/json", error_schema()},
      not_found: {"Not found", "application/json", error_schema()},
      unprocessable_entity: {"Validation error", "application/json", validation_error_schema()},
      internal_server_error: {"Internal server error", "application/json", error_schema()}
    ]

    Keyword.merge(base_responses, additional_responses)
  end
end
