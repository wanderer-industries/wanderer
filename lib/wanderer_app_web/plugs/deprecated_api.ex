defmodule WandererAppWeb.Plugs.DeprecatedApi do
  @moduledoc """
  Plug to add deprecation headers to legacy API endpoints.
  Implements RFC 8594 Sunset header for API deprecation.

  Provides strong enforcement in development/test environments unless
  explicitly enabled via FEATURE_LEGACY_API environment variable.
  """

  import Plug.Conn
  alias WandererAppWeb.Telemetry.DeprecatedApiTracker

  # Fixed sunset date: December 31, 2025
  @sunset_date "Tue, 31 Dec 2025 23:59:59 GMT"

  def init(opts), do: opts

  def call(conn, _opts) do
    # Track the deprecated API usage
    DeprecatedApiTracker.track_legacy_request(conn)

    # Check if legacy API is allowed
    if legacy_api_allowed?() do
      conn
      |> put_resp_header("sunset", @sunset_date)
      |> put_resp_header("deprecation", "true")
      |> put_resp_header("deprecation-date", @sunset_date)
      |> put_resp_header("link", "<https://docs.wanderer.app/api/v1>; rel=\"successor-version\"")
      |> put_resp_header(
        "warning",
        ~s(299 - "Deprecated API: This endpoint will be removed after #{@sunset_date}")
      )
    else
      # Block the request in dev/test unless explicitly allowed
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(
        410,
        Jason.encode!(%{
          error: "Gone",
          message: "This legacy API endpoint is deprecated and disabled.",
          details:
            "Set FEATURE_LEGACY_API to any value other than 'false' to re-enable legacy endpoints in development/test.",
          migration_guide: "https://docs.wanderer.app/api/migration",
          sunset_date: @sunset_date
        })
      )
      |> halt()
    end
  end

  defp legacy_api_allowed? do
    case Application.get_env(:wanderer_app, :env) do
      :prod ->
        # Always allow in production (for now)
        true

      env when env in [:dev, :test] ->
        # Allow by default unless explicitly disabled
        System.get_env("FEATURE_LEGACY_API") != "false"

      _ ->
        # Default to enabled for unknown environments
        true
    end
  end
end
