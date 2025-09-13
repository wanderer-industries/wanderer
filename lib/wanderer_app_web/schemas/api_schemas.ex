defmodule WandererAppWeb.Schemas.ApiSchemas do
  @moduledoc """
  Shared OpenAPI schema definitions for the Wanderer API.

  This module defines common schema components that can be reused
  across different controller specifications.
  """

  alias OpenApiSpex.Schema

  # Standard response wrappers
  def data_wrapper(schema) do
    %Schema{
      type: :object,
      properties: %{
        data: schema
      },
      required: ["data"]
    }
  end

  # Standard error responses
  def error_response(description \\ "Error") do
    %Schema{
      type: :object,
      properties: %{
        error: %Schema{type: :string, description: "Brief error message"},
        details: %Schema{type: :string, description: "Detailed explanation", nullable: true},
        code: %Schema{type: :string, description: "Optional error code", nullable: true}
      },
      required: ["error"],
      example: %{"error" => description, "details" => "Additional information about the error"}
    }
  end

  # Common entity schemas
  def character_schema do
    %Schema{
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Character UUID"},
        eve_id: %Schema{type: :string, description: "EVE Online character ID"},
        name: %Schema{type: :string, description: "Character name"},
        online: %Schema{type: :boolean, description: "Online status"},
        corporation_id: %Schema{type: :integer, description: "Corporation ID"},
        corporation_name: %Schema{type: :string, description: "Corporation name"},
        corporation_ticker: %Schema{type: :string, description: "Corporation ticker"},
        alliance_id: %Schema{type: :integer, description: "Alliance ID"},
        alliance_name: %Schema{type: :string, description: "Alliance name"},
        alliance_ticker: %Schema{type: :string, description: "Alliance ticker"},
        solar_system_id: %Schema{type: :integer, description: "Current solar system ID"},
        ship: %Schema{type: :integer, description: "Current ship type ID"},
        ship_name: %Schema{type: :string, description: "Current ship name"},
        inserted_at: %Schema{type: :string, format: :date_time, description: "Creation timestamp"},
        updated_at: %Schema{
          type: :string,
          format: :date_time,
          description: "Last update timestamp"
        }
      },
      required: ~w(eve_id name)a
    }
  end

  # Common system schema based on what we've seen in controllers
  def solar_system_basic_schema do
    %Schema{
      type: :object,
      properties: %{
        solar_system_id: %Schema{type: :integer},
        solar_system_name: %Schema{type: :string},
        region_id: %Schema{type: :integer},
        region_name: %Schema{type: :string},
        constellation_id: %Schema{type: :integer},
        constellation_name: %Schema{type: :string},
        security: %Schema{type: :string}
      },
      required: ["solar_system_id", "solar_system_name"]
    }
  end

  # Map schema with common fields
  def map_basic_schema do
    %Schema{
      type: :object,
      properties: %{
        id: %Schema{type: :string},
        name: %Schema{type: :string},
        slug: %Schema{type: :string},
        description: %Schema{type: :string},
        owner_id: %Schema{type: :string},
        inserted_at: %Schema{type: :string, format: :date_time},
        updated_at: %Schema{type: :string, format: :date_time}
      },
      required: ["id", "name", "slug"]
    }
  end

  # License schema
  def license_schema do
    %Schema{
      type: :object,
      properties: %{
        id: %Schema{type: :string},
        license_key: %Schema{type: :string},
        is_valid: %Schema{type: :boolean},
        expire_at: %Schema{type: :string, format: :date_time},
        map_id: %Schema{type: :string}
      },
      required: ["id", "license_key", "is_valid", "map_id"]
    }
  end

  # Access list schema
  def access_list_schema do
    %Schema{
      type: :object,
      properties: %{
        id: %Schema{type: :string},
        name: %Schema{type: :string},
        description: %Schema{type: :string},
        owner_id: %Schema{type: :string},
        api_key: %Schema{type: :string},
        inserted_at: %Schema{type: :string, format: :date_time},
        updated_at: %Schema{type: :string, format: :date_time}
      },
      required: ["id", "name"]
    }
  end

  # Access list member schema
  def access_list_member_schema do
    %Schema{
      type: :object,
      properties: %{
        id: %Schema{type: :string},
        name: %Schema{type: :string},
        role: %Schema{type: :string},
        eve_character_id: %Schema{type: :string},
        eve_corporation_id: %Schema{type: :string},
        eve_alliance_id: %Schema{type: :string},
        inserted_at: %Schema{type: :string, format: :date_time},
        updated_at: %Schema{type: :string, format: :date_time}
      },
      required: ["id", "name", "role"]
    }
  end

  # Common paginated response wrapper
  def paginated_response(items_schema) do
    %Schema{
      type: :object,
      properties: %{
        data: items_schema,
        pagination: %Schema{
          type: :object,
          properties: %{
            page: %Schema{type: :integer},
            page_size: %Schema{type: :integer},
            total_pages: %Schema{type: :integer},
            total_count: %Schema{type: :integer}
          },
          required: ["page", "page_size", "total_count"]
        }
      },
      required: ["data", "pagination"]
    }
  end
end
