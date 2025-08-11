defmodule WandererAppWeb.Plugs.ApiVersioning do
  @moduledoc """
  API versioning middleware that handles version negotiation and routing.

  This plug provides:
  - Version detection from URL path, headers, or parameters
  - Version validation and compatibility checking
  - Deprecation warnings and migration notices
  - Default version handling
  - Version-specific feature flags
  """

  import Plug.Conn

  alias WandererApp.SecurityAudit
  alias WandererApp.Audit.RequestContext

  @supported_versions ["1"]
  @default_version "1"
  @deprecated_versions []
  @minimum_version "1"
  @maximum_version "1"

  # Version detection methods (in order of precedence)
  @version_methods [:path, :header, :query_param, :default]

  def init(opts) do
    opts
    |> Keyword.put_new(:supported_versions, @supported_versions)
    |> Keyword.put_new(:default_version, @default_version)
    |> Keyword.put_new(:deprecated_versions, @deprecated_versions)
    |> Keyword.put_new(:minimum_version, @minimum_version)
    |> Keyword.put_new(:maximum_version, @maximum_version)
    |> Keyword.put_new(:version_methods, @version_methods)
    |> Keyword.put_new(:deprecation_warnings, true)
    |> Keyword.put_new(:strict_versioning, false)
  end

  def call(conn, opts) do
    start_time = System.monotonic_time(:millisecond)

    # Fetch query params if they haven't been fetched yet
    conn =
      if conn.query_params == %Plug.Conn.Unfetched{} do
        Plug.Conn.fetch_query_params(conn)
      else
        conn
      end

    case detect_api_version(conn, opts) do
      {:ok, version, method} ->
        conn =
          conn
          |> assign(:api_version, version)
          |> assign(:version_method, method)

        # Validate version and handle errors
        case validate_version(conn, version, opts) do
          %{halted: true} = halted_conn ->
            halted_conn

          validated_conn ->
            validated_conn
            |> add_version_headers(version)
            |> handle_deprecation_warnings(version, opts)
            |> log_version_usage(version, method, start_time)
        end

      {:error, reason} ->
        handle_version_error(conn, reason, opts)
    end
  end

  # Version detection
  defp detect_api_version(conn, opts) do
    methods = Keyword.get(opts, :version_methods, @version_methods)
    default_version = Keyword.get(opts, :default_version, @default_version)

    Enum.reduce_while(methods, {:error, :no_version_found}, fn method, _acc ->
      case detect_version_by_method(conn, method, opts) do
        {:ok, version} -> {:halt, {:ok, version, method}}
        {:error, _} -> {:cont, {:error, :no_version_found}}
      end
    end)
    |> case do
      {:error, :no_version_found} ->
        {:ok, default_version, :default}

      result ->
        result
    end
  end

  defp detect_version_by_method(conn, :path, _opts) do
    case conn.path_info do
      ["api", "v" <> version | _] ->
        {:ok, version}

      ["api", version | _] when version in ["1"] ->
        {:ok, version}

      _ ->
        {:error, :no_path_version}
    end
  end

  defp detect_version_by_method(conn, :header, _opts) do
    case get_req_header(conn, "api-version") do
      [version] ->
        {:ok, version}

      [] ->
        # Try Accept header with versioning
        case get_req_header(conn, "accept") do
          [accept_header] ->
            cond do
              String.starts_with?(accept_header, "application/vnd.wanderer.v") and
                  String.ends_with?(accept_header, "+json") ->
                version =
                  accept_header
                  |> String.replace_prefix("application/vnd.wanderer.v", "")
                  |> String.replace_suffix("+json", "")

                {:ok, version}

              String.starts_with?(accept_header, "application/json; version=") ->
                version = String.replace_prefix(accept_header, "application/json; version=", "")
                {:ok, version}

              true ->
                {:error, :no_header_version}
            end

          _ ->
            {:error, :no_header_version}
        end
    end
  end

  defp detect_version_by_method(conn, :query_param, _opts) do
    case conn.query_params["version"] || conn.query_params["api_version"] do
      nil -> {:error, :no_query_version}
      version -> {:ok, version}
    end
  end

  defp detect_version_by_method(_conn, :default, opts) do
    default_version = Keyword.get(opts, :default_version, @default_version)
    {:ok, default_version}
  end

  # Version validation
  defp validate_version(conn, version, opts) do
    supported_versions = Keyword.get(opts, :supported_versions, @supported_versions)
    minimum_version = Keyword.get(opts, :minimum_version, @minimum_version)
    maximum_version = Keyword.get(opts, :maximum_version, @maximum_version)
    strict_versioning = Keyword.get(opts, :strict_versioning, false)

    cond do
      version in supported_versions ->
        conn

      strict_versioning ->
        conn
        |> send_version_error(400, "Unsupported API version", %{
          requested: version,
          supported: supported_versions,
          minimum: minimum_version,
          maximum: maximum_version
        })
        |> halt()

      version_too_old?(version, minimum_version) ->
        conn
        |> send_version_error(410, "API version no longer supported", %{
          requested: version,
          minimum_supported: minimum_version,
          upgrade_required: true
        })
        |> halt()

      version_too_new?(version, maximum_version) ->
        # Gracefully handle newer versions by falling back to latest supported
        latest_version = maximum_version

        conn
        |> assign(:api_version, latest_version)
        |> put_resp_header("api-version-fallback", "true")
        |> put_resp_header("api-version-requested", version)
        |> put_resp_header("api-version-used", latest_version)

      true ->
        # Unknown version format, use default
        default_version = Keyword.get(opts, :default_version, @default_version)

        conn
        |> assign(:api_version, default_version)
        |> put_resp_header("api-version-warning", "unknown-version")
    end
  end

  defp version_too_old?(requested, minimum) do
    compare_versions(requested, minimum) == :lt
  end

  defp version_too_new?(requested, maximum) do
    compare_versions(requested, maximum) == :gt
  end

  defp compare_versions(v1, v2) do
    v1_parts = String.split(v1, ".") |> Enum.map(&String.to_integer/1)
    v2_parts = String.split(v2, ".") |> Enum.map(&String.to_integer/1)

    case Version.compare(
           Version.parse!("#{Enum.join(v1_parts, ".")}.0"),
           Version.parse!("#{Enum.join(v2_parts, ".")}.0")
         ) do
      :eq -> :eq
      :gt -> :gt
      :lt -> :lt
    end
  rescue
    _ ->
      # If version comparison fails, treat as equal
      :eq
  end

  # Version headers
  defp add_version_headers(conn, version) do
    conn
    |> put_resp_header("api-version", version)
    |> put_resp_header("api-supported-versions", Enum.join(@supported_versions, ", "))
    |> put_resp_header("api-deprecation-info", get_deprecation_info(version))
  end

  defp get_deprecation_info(version) do
    if version in @deprecated_versions do
      "deprecated; upgrade-by=2025-12-31; link=https://docs.wanderer.com/api/migration"
    else
      "false"
    end
  end

  # Deprecation warnings
  defp handle_deprecation_warnings(conn, version, opts) do
    deprecated_versions = Keyword.get(opts, :deprecated_versions, @deprecated_versions)
    show_warnings = Keyword.get(opts, :deprecation_warnings, true)

    if version in deprecated_versions and show_warnings do
      conn
      |> put_resp_header("warning", build_deprecation_warning(version))
      |> log_deprecation_usage(version)
    else
      conn
    end
  end

  defp build_deprecation_warning(version) do
    "299 wanderer-api \"API version #{version} is deprecated. Please upgrade to version #{@default_version}. See https://docs.wanderer.com/api/migration for details.\""
  end

  defp log_deprecation_usage(conn, version) do
    user_id = get_user_id(conn)
    request_details = RequestContext.build_request_details(conn)

    SecurityAudit.log_event(
      :deprecated_api_usage,
      user_id,
      Map.put(request_details, :version, version)
    )

    conn
  end

  # Version-specific routing support
  def version_supports_feature?(version, feature) do
    case {version, feature} do
      # Version 1 features (consolidated all previous features)
      {v, :basic_crud} when v in ["1"] -> true
      {v, :pagination} when v in ["1"] -> true
      {v, :filtering} when v in ["1"] -> true
      {v, :sorting} when v in ["1"] -> true
      {v, :sparse_fieldsets} when v in ["1"] -> true
      {v, :includes} when v in ["1"] -> true
      {v, :bulk_operations} when v in ["1"] -> true
      {v, :webhooks} when v in ["1"] -> true
      {v, :real_time_events} when v in ["1"] -> true
      # Future features (not yet implemented)
      {_v, :graphql} -> false
      {_v, :subscriptions} -> false
      _ -> false
    end
  end

  def get_version_config(version) do
    %{
      "1" => %{
        features: [
          :basic_crud,
          :pagination,
          :filtering,
          :sorting,
          :sparse_fieldsets,
          :includes,
          :bulk_operations,
          :webhooks,
          :real_time_events
        ],
        max_page_size: 500,
        default_page_size: 50,
        supports_includes: true,
        supports_sparse_fields: true
      }
    }[version] || get_version_config(@default_version)
  end

  # Error handling
  defp handle_version_error(conn, reason, _opts) do
    request_details = RequestContext.build_request_details(conn)

    SecurityAudit.log_event(
      :api_version_error,
      get_user_id(conn),
      request_details
      |> Map.put(:reason, reason)
      |> Map.put(:headers, get_version_headers(conn))
    )

    conn
    |> send_version_error(400, "Invalid API version", %{
      reason: reason,
      supported_versions: @supported_versions,
      default_version: @default_version
    })
    |> halt()
  end

  defp send_version_error(conn, status, message, details) do
    error_response = %{
      error: message,
      status: status,
      details: details,
      supported_versions: @supported_versions,
      documentation: "https://docs.wanderer.com/api/versioning",
      timestamp: DateTime.utc_now()
    }

    conn
    |> put_status(status)
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(error_response))
  end

  # Logging and metrics
  defp log_version_usage(conn, version, method, start_time) do
    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time

    # Emit telemetry for version usage
    :telemetry.execute(
      [:wanderer_app, :api_versioning],
      %{duration: duration, count: 1},
      %{
        version: version,
        method: method,
        path: conn.request_path,
        user_id: get_user_id(conn)
      }
    )

    conn
  end

  # Helper functions
  defp get_user_id(conn) do
    case conn.assigns[:current_user] do
      %{id: user_id} -> user_id
      _ -> nil
    end
  end

  defp get_version_headers(conn) do
    %{
      "api-version" => get_req_header(conn, "api-version"),
      "accept" => get_req_header(conn, "accept"),
      "user-agent" => get_req_header(conn, "user-agent")
    }
  end

  # Public API for checking version compatibility
  def compatible_version?(requested_version, minimum_version \\ @minimum_version) do
    compare_versions(requested_version, minimum_version) != :lt
  end

  def get_migration_path(from_version, to_version \\ @default_version) do
    %{
      from: from_version,
      to: to_version,
      breaking_changes: get_breaking_changes(from_version, to_version),
      migration_guide: "https://docs.wanderer.com/api/migration/#{from_version}-to-#{to_version}",
      estimated_effort: estimate_migration_effort(from_version, to_version)
    }
  end

  defp get_breaking_changes(from_version, to_version) do
    %{
      {"1.0", "1"} => [
        "All API endpoints now use /api/v1/ prefix",
        "Pagination parameters changed from page/per_page to page[number]/page[size]",
        "Error response format updated to JSON:API spec",
        "Date fields now return ISO 8601 format",
        "Relationship URLs moved to links object",
        "All features (filtering, sorting, includes, bulk operations) are now available"
      ],
      {"1.1", "1"} => [
        "All API endpoints now use /api/v1/ prefix",
        "Relationship URLs moved to links object",
        "All features (includes, bulk operations, webhooks) are now available"
      ],
      {"1.2", "1"} => [
        "All API endpoints now use /api/v1/ prefix",
        "Version consolidated - no functional changes"
      ]
    }[{from_version, to_version}] || []
  end

  defp estimate_migration_effort(from_version, to_version) do
    case {from_version, to_version} do
      {"1.0", "1"} -> "high"
      {"1.1", "1"} -> "medium"
      {"1.2", "1"} -> "low"
      _ -> "unknown"
    end
  end
end
