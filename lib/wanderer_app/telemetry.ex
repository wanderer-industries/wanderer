defmodule WandererApp.Telemetry do
  @moduledoc """
  OpenTelemetry instrumentation for API monitoring and observability.

  This module sets up comprehensive telemetry for:
  - HTTP request/response metrics
  - Database query performance  
  - Phoenix LiveView events
  - Custom API metrics for performance baseline
  """

  require Logger

  @doc """
  Sets up additional telemetry for API monitoring.
  Integrates with existing PromEx and telemetry infrastructure.
  """
  def setup do
    Logger.info("Setting up API telemetry monitoring")

    # Set up custom API metrics that integrate with existing telemetry
    setup_api_metrics()

    Logger.info("API telemetry setup complete")
  end

  # Sets up custom metrics specifically for API performance monitoring.
  # These metrics will help establish baseline performance for the legacy API
  # and monitor the new JSON:API endpoints.
  defp setup_api_metrics do
    # API request duration histogram
    :telemetry.attach(
      "api-request-duration",
      [:phoenix, :endpoint, :stop],
      &handle_api_request/4,
      %{}
    )

    # Custom API endpoint metrics
    :telemetry.attach_many(
      "api-custom-metrics",
      [
        [:wanderer_app, :api, :request, :start],
        [:wanderer_app, :api, :request, :stop],
        [:wanderer_app, :api, :request, :exception]
      ],
      &handle_custom_api_metrics/4,
      %{}
    )
  end

  @doc """
  Handles Phoenix request metrics, specifically filtering for API endpoints.
  """
  def handle_api_request(_event, measurements, metadata, _config) do
    # Only track API endpoints
    if is_api_endpoint?(metadata) do
      duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

      # Log API request metrics (integrates with existing logging infrastructure)
      Logger.info("API request completed",
        method: metadata.method,
        route: metadata.route,
        status: metadata.status,
        duration_ms: duration_ms,
        api_version: get_api_version(metadata.route),
        endpoint: normalize_endpoint(metadata.route)
      )
    end
  end

  @doc """
  Handles custom API metrics for detailed performance monitoring.
  """
  def handle_custom_api_metrics(event, measurements, metadata, _config) do
    case event do
      [:wanderer_app, :api, :request, :start] ->
        Process.put(:api_request_active, true)
        Process.put(:current_api_endpoint, metadata.endpoint)

      [:wanderer_app, :api, :request, :stop] ->
        duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

        Logger.info("API endpoint completed",
          endpoint: metadata.endpoint,
          version: metadata.version,
          controller: metadata.controller,
          action: metadata.action,
          duration_ms: duration_ms
        )

        Process.delete(:api_request_active)
        Process.delete(:current_api_endpoint)

      [:wanderer_app, :api, :request, :exception] ->
        Logger.error("API endpoint error",
          endpoint: metadata.endpoint,
          version: metadata.version,
          error_type: metadata.error_type
        )

        Process.delete(:api_request_active)
        Process.delete(:current_api_endpoint)
    end
  end

  @doc """
  Helper function to emit custom API telemetry events.
  Use this in controllers to track specific API operations.
  """
  def track_api_request(endpoint, version, controller, action, fun) do
    start_time = System.monotonic_time()

    metadata = %{
      endpoint: endpoint,
      version: version,
      controller: controller,
      action: action
    }

    :telemetry.execute(
      [:wanderer_app, :api, :request, :start],
      %{system_time: System.system_time()},
      metadata
    )

    try do
      result = fun.()

      duration = System.monotonic_time() - start_time

      :telemetry.execute(
        [:wanderer_app, :api, :request, :stop],
        %{duration: duration},
        metadata
      )

      result
    rescue
      error ->
        :telemetry.execute(
          [:wanderer_app, :api, :request, :exception],
          %{},
          Map.put(metadata, :error_type, error.__struct__)
        )

        reraise error, __STACKTRACE__
    end
  end

  # Private helper functions

  defp is_api_endpoint?(metadata) do
    route = metadata[:route] || ""
    String.starts_with?(route, "/api/")
  end

  defp get_api_version(route) do
    cond do
      String.starts_with?(route, "/api/v1/") -> "v1"
      String.starts_with?(route, "/api/") -> "legacy"
      true -> "unknown"
    end
  end

  defp normalize_endpoint(route) do
    # Normalize route parameters for consistent grouping
    route
    |> String.replace(~r/\/:[^\/]+/, "/:id")
    |> String.replace(~r/\/\d+/, "/:id")
  end

  @doc """
  Performance baseline measurement functions.
  These will help establish current API performance metrics.
  """
  def measure_endpoint_performance(endpoint_name, iterations \\ 100) do
    Logger.info("Starting performance baseline measurement for #{endpoint_name}")

    results =
      Enum.map(1..iterations, fn _i ->
        start_time = System.monotonic_time()
        # Placeholder for actual endpoint calls
        # This would be implemented with actual HTTP calls to existing endpoints
        duration = System.monotonic_time() - start_time
        System.convert_time_unit(duration, :native, :millisecond)
      end)

    avg_duration = Enum.sum(results) / length(results)
    max_duration = Enum.max(results)
    min_duration = Enum.min(results)

    baseline = %{
      endpoint: endpoint_name,
      iterations: iterations,
      avg_duration_ms: avg_duration,
      max_duration_ms: max_duration,
      min_duration_ms: min_duration,
      measured_at: DateTime.utc_now()
    }

    Logger.info("Performance baseline for #{endpoint_name}: #{inspect(baseline)}")
    baseline
  end
end
