defmodule WandererAppWeb.Plugs.CheckAclApiKey do
  @moduledoc """
  A plug that checks the "Authorization: Bearer <token>" header
  against the ACL’s stored api_key.
  """

  import Plug.Conn
  alias WandererApp.Repo
  alias WandererApp.Api.AccessList

  def init(opts), do: opts

  def call(conn, _opts) do
    header = get_req_header(conn, "authorization") |> List.first()

    case header do
      "Bearer " <> incoming_token ->
        acl_id = conn.params["id"] || conn.params["acl_id"]

        if acl_id do
          case Repo.get(AccessList, acl_id) do
            nil ->
              conn
              |> send_resp(404, "ACL not found")
              |> halt()

            acl ->
              cond do
                is_nil(acl.api_key) ->
                  conn
                  |> send_resp(401, "Unauthorized (no API key set for ACL)")
                  |> halt()

                acl.api_key == incoming_token ->
                  conn

                true ->
                  conn
                  |> send_resp(401, "Unauthorized (invalid API key for ACL)")
                  |> halt()
              end
          end
        else
          conn
          |> send_resp(400, "ACL ID not provided")
          |> halt()
        end

      _ ->
        conn
        |> send_resp(401, "Missing or invalid 'Bearer' token")
        |> halt()
    end
  end
end
