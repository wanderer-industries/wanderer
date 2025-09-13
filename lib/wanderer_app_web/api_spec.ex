defmodule WandererAppWeb.ApiSpec do
  @behaviour OpenApiSpex.OpenApi

  alias OpenApiSpex.{OpenApi, Info, Paths, Components, SecurityScheme, Server, Schema}
  alias WandererAppWeb.{Endpoint, Router}
  alias WandererAppWeb.Schemas.ApiSchemas

  @impl OpenApiSpex.OpenApi
  def spec do
    %OpenApi{
      info: %Info{
        title: "WandererApp API",
        version: "1.0.0",
        description: "API documentation for WandererApp"
      },
      servers: [
        Server.from_endpoint(Endpoint)
      ],
      paths: Paths.from_router(Router),
      components: %Components{
        securitySchemes: %{
          "bearerAuth" => %SecurityScheme{
            type: "http",
            scheme: "bearer",
            bearerFormat: "JWT"
          }
        },
        schemas: %{
          "ErrorResponse" => ApiSchemas.error_response()
        }
      },
      security: [%{"bearerAuth" => []}]
    }
  end
end
