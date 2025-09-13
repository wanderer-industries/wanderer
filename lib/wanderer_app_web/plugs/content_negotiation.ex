defmodule WandererAppWeb.Plugs.ContentNegotiation do
  @moduledoc """
  Handles content negotiation for API endpoints.
  Returns 406 Not Acceptable for unsupported Accept headers instead of raising an exception.
  """

  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, opts) do
    accepted_formats = Keyword.get(opts, :accepts, ["json"])

    case get_req_header(conn, "accept") do
      [] ->
        # No Accept header, continue with default
        conn

      [accept_header | _] ->
        if accepts_any?(accept_header, accepted_formats) do
          conn
        else
          Logger.debug("Rejecting request with Accept header: #{accept_header}")

          conn
          |> put_status(406)
          |> put_resp_content_type("application/json")
          |> Phoenix.Controller.json(%{
            error:
              "Not acceptable format. This API only supports: #{Enum.join(accepted_formats, ", ")}"
          })
          |> halt()
        end
    end
  end

  defp accepts_any?(accept_header, accepted_formats) do
    # Simple check for now - can be enhanced to handle quality values
    accept_header == "*/*" or
      Enum.any?(accepted_formats, fn format ->
        # Handle both regular JSON and JSON:API formats
        String.contains?(accept_header, "application/#{format}") or
          (format == "json" and String.contains?(accept_header, "application/vnd.api+json"))
      end)
  end
end
