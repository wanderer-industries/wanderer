defmodule WandererAppWeb.AshJsonApiRouter do
  @moduledoc """
  Legacy AshJsonApi Router - Backward compatibility.

  @deprecated "Use WandererAppWeb.Routers.ApiV1Router for new code. This router is maintained for backward compatibility only and will be removed after 2025-12-31."

  This module exists for backward compatibility with code that may directly
  reference the old AshJsonApiRouter. New development should use the versioned
  routers under WandererAppWeb.Routers.ApiV1Router or ApiV2Router.
  """

  use AshJsonApi.Router,
    domains: [WandererApp.Api],
    json_schema: "/json_schema",
    open_api: "/openapi"

  # Legacy JSON:API routes - delegates to the same resources as V1
  # Maintained for backward compatibility only
end
