defmodule WandererAppWeb.Telemetry.DeprecatedApiTracker do
  @moduledoc """
  Telemetry tracking for deprecated API usage.

  Provides metrics and monitoring for legacy API endpoints to help
  track migration progress and identify clients still using deprecated APIs.
  """

  require Logger

  @legacy_api_event [:wanderer_app, :legacy_api, :request]
  @v1_api_event [:wanderer_app, :api_v1, :request]

  @doc """
  Track a legacy API request.
  """
  def track_legacy_request(conn) do
    metadata = %{
      path: conn.request_path,
      method: conn.method,
      controller: get_controller_module(conn),
      action: get_action_name(conn),
      remote_ip: get_remote_ip(conn),
      user_agent: get_user_agent(conn)
    }

    :telemetry.execute(@legacy_api_event, %{count: 1}, metadata)

    # Log deprecation warning in development (but not in test to reduce noise)
    if Application.get_env(:wanderer_app, :env) == :dev do
      Logger.warning("""
      Deprecated API usage detected:
        Path: #{metadata.path}
        Controller: #{metadata.controller}
        Action: #{metadata.action}
        User-Agent: #{metadata.user_agent}

      This endpoint will be removed after 2025-12-31. Please migrate to /api/v1.
      """)
    end
  end

  @doc """
  Track a v1 API request.
  """
  def track_v1_request(conn) do
    metadata = %{
      path: conn.request_path,
      method: conn.method,
      controller: Phoenix.Controller.controller_module(conn),
      action: Phoenix.Controller.action_name(conn),
      remote_ip: to_string(:inet.ntoa(conn.remote_ip)),
      user_agent: get_user_agent(conn)
    }

    :telemetry.execute(@v1_api_event, %{count: 1}, metadata)
  end

  @doc """
  Get deprecation metrics summary.
  """
  def get_deprecation_metrics do
    # This would typically query your metrics backend
    # For now, return a placeholder structure
    %{
      legacy_requests_total: 0,
      v1_requests_total: 0,
      legacy_endpoints_used: [],
      top_legacy_clients: []
    }
  end

  @doc """
  Report on endpoints still being used that are deprecated.
  """
  def report_deprecated_usage do
    metrics = get_deprecation_metrics()

    if metrics.legacy_requests_total > 0 do
      Logger.warning("""
      Deprecated API Usage Report:
        Total legacy requests: #{metrics.legacy_requests_total}
        Total v1 requests: #{metrics.v1_requests_total}
        Migration progress: #{calculate_migration_percentage(metrics)}%
        
        Top deprecated endpoints:
        #{format_endpoint_list(metrics.legacy_endpoints_used)}
        
        Top clients using deprecated APIs:
        #{format_client_list(metrics.top_legacy_clients)}
      """)
    end
  end

  defp get_controller_module(conn) do
    case conn.private[:phoenix_controller] do
      nil -> "Unknown"
      module -> inspect(module)
    end
  end

  defp get_action_name(conn) do
    case conn.private[:phoenix_action] do
      nil -> "unknown"
      action -> to_string(action)
    end
  end

  defp get_remote_ip(conn) do
    case conn.remote_ip do
      nil -> "Unknown"
      ip -> to_string(:inet.ntoa(ip))
    end
  end

  defp get_user_agent(conn) do
    case Plug.Conn.get_req_header(conn, "user-agent") do
      [user_agent | _] -> user_agent
      [] -> "Unknown"
    end
  end

  defp calculate_migration_percentage(%{legacy_requests_total: 0}), do: 100

  defp calculate_migration_percentage(%{legacy_requests_total: legacy, v1_requests_total: v1}) do
    total = legacy + v1
    round(v1 / total * 100)
  end

  defp format_endpoint_list(endpoints) do
    endpoints
    |> Enum.take(5)
    |> Enum.map_join("\n", fn {endpoint, count} ->
      "  - #{endpoint}: #{count} requests"
    end)
  end

  defp format_client_list(clients) do
    clients
    |> Enum.take(5)
    |> Enum.map_join("\n", fn {client, count} ->
      "  - #{client}: #{count} requests"
    end)
  end
end
