defmodule WandererAppWeb.ApiV1Router do
  use AshJsonApi.Router,
    domains: [WandererApp.Api],
    prefix: "/api/v1",
    open_api: "/open_api",
    json_schema: "/json_schema",
    open_api_title: "WandererApp v1 JSON:API",
    open_api_version: "1.0.0",
    modify_open_api: {WandererAppWeb.OpenApi, :spec, []}
end
