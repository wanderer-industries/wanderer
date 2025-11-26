defmodule WandererAppWeb.ApiV1Router do
  use AshJsonApi.Router,
    domains: [WandererApp.Api],
    prefix: "/api/v1",
    open_api: "/open_api",
    json_schema: "/json_schema",
    open_api_title: "WandererApp v1 JSON:API",
    open_api_version: "1.0.0",
    modify_open_api: {WandererAppWeb.OpenApi, :spec, []},
    modify_conn: {__MODULE__, :add_context, []}

  def add_context(conn, _resource) do
    # Actor is set by CheckJsonApiAuth using Ash.PlugHelpers.set_actor/2
    # The actor (ActorWithMap) is passed to Ash actions automatically
    conn
  end
end
