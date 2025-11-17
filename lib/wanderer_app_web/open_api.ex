defmodule WandererAppWeb.OpenApi do
  @moduledoc """
  Generates OpenAPI spec for v1 JSON:API endpoints using AshJsonApi.
  """

  alias OpenApiSpex.{OpenApi, Info, Server, Components}

  def spec do
    %OpenApi{
      info: %Info{
        title: "WandererApp v1 JSON:API",
        version: "1.0.0",
        description: """
        JSON:API compliant endpoints for WandererApp.

        ## Features
        - Filtering: Use `filter[attribute]=value` parameters
        - Sorting: Use `sort=attribute` or `sort=-attribute` for descending
        - Pagination: Use `page[limit]=n` and `page[offset]=n`
        - Relationships: Include related resources with `include=relationship`

        ## Authentication

        All endpoints use **token-only authentication**. Your Bearer token identifies both:
        - Your user account
        - The specific map you're working with

        You do **NOT** need to provide `map_id` or `map_identifier` in:
        - Request body attributes
        - Query parameters
        - URL path

        The map context is automatically determined from your API token.

        ### Example
        ```
        Authorization: Bearer YOUR_API_KEY
        ```

        ### Getting Your API Token

        1. Navigate to your map in the web interface
        2. Go to Map Settings
        3. Copy your API key from the "API Access" section

        Each map has its own unique API token. Use the appropriate token for the map you want to interact with.

        ### Security

        - Never share your API tokens publicly
        - Each token provides full access to its associated map
        - Tokens can be regenerated from Map Settings if compromised
        """
      },
      servers: [
        Server.from_endpoint(WandererAppWeb.Endpoint)
      ],
      paths:
        merge_custom_paths(AshJsonApi.OpenApi.paths([WandererApp.Api], [WandererApp.Api], %{})),
      tags: AshJsonApi.OpenApi.tags([WandererApp.Api]),
      components: %Components{
        responses: AshJsonApi.OpenApi.responses(),
        schemas: AshJsonApi.OpenApi.schemas([WandererApp.Api]),
        securitySchemes: %{
          "bearerAuth" => %{
            "type" => "http",
            "scheme" => "bearer",
            "description" => "Map API key for authentication"
          }
        }
      },
      security: [%{"bearerAuth" => []}]
    }
  end

  defp merge_custom_paths(ash_paths) do
    custom_paths = %{
      "/maps/{map_id}/systems_and_connections" => %{
        "get" => %{
          "tags" => ["maps"],
          "summary" => "Get Map Systems and Connections",
          "description" => "Retrieve both systems and connections for a map in a single response",
          "operationId" => "getMapSystemsAndConnections",
          "parameters" => [
            %{
              "name" => "map_id",
              "in" => "path",
              "description" => "Map ID",
              "required" => true,
              "schema" => %{"type" => "string"}
            }
          ],
          "responses" => %{
            "200" => %{
              "description" => "Combined systems and connections data",
              "content" => %{
                "application/json" => %{
                  "schema" => %{
                    "type" => "object",
                    "properties" => %{
                      "systems" => %{
                        "type" => "array",
                        "items" => %{
                          "$ref" => "#/components/schemas/MapSystem"
                        }
                      },
                      "connections" => %{
                        "type" => "array",
                        "items" => %{
                          "$ref" => "#/components/schemas/MapConnection"
                        }
                      }
                    }
                  }
                }
              }
            },
            "404" => %{
              "description" => "Map not found",
              "content" => %{
                "application/json" => %{
                  "schema" => %{
                    "type" => "object",
                    "properties" => %{
                      "error" => %{"type" => "string"}
                    }
                  }
                }
              }
            },
            "401" => %{
              "description" => "Unauthorized",
              "content" => %{
                "application/json" => %{
                  "schema" => %{
                    "type" => "object",
                    "properties" => %{
                      "error" => %{"type" => "string"}
                    }
                  }
                }
              }
            }
          },
          "security" => [%{"bearerAuth" => []}]
        }
      }
    }

    Map.merge(ash_paths, custom_paths)
  end
end
