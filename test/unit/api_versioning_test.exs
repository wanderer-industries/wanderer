defmodule WandererApp.ApiVersioningTest do
  @moduledoc """
  Tests for the API versioning system.
  """

  use WandererAppWeb.ConnCase, async: true

  alias WandererAppWeb.Plugs.ApiVersioning

  describe "ApiVersioning plug" do
    test "detects version from URL path" do
      conn =
        build_conn(:get, "/api/v1.2/maps")
        |> ApiVersioning.call(ApiVersioning.init([]))

      assert conn.assigns[:api_version] == "1.2"
      assert conn.assigns[:version_method] == :path
    end

    test "detects version from API-Version header" do
      conn =
        build_conn(:get, "/api/maps")
        |> put_req_header("api-version", "1.1")
        |> ApiVersioning.call(ApiVersioning.init([]))

      assert conn.assigns[:api_version] == "1.1"
      assert conn.assigns[:version_method] == :header
    end

    test "detects version from Accept header" do
      conn =
        build_conn(:get, "/api/maps")
        |> put_req_header("accept", "application/vnd.wanderer.v1.0+json")
        |> ApiVersioning.call(ApiVersioning.init([]))

      assert conn.assigns[:api_version] == "1.0"
      assert conn.assigns[:version_method] == :header
    end

    test "detects version from query parameter" do
      conn =
        build_conn(:get, "/api/maps?version=1.2")
        |> Plug.Conn.fetch_query_params()
        |> ApiVersioning.call(ApiVersioning.init([]))

      assert conn.assigns[:api_version] == "1.2"
      assert conn.assigns[:version_method] == :query_param
    end

    test "uses default version when none specified" do
      conn =
        build_conn(:get, "/api/maps")
        |> Plug.Conn.fetch_query_params()
        |> ApiVersioning.call(ApiVersioning.init([]))

      assert conn.assigns[:api_version] == "1.2"
      assert conn.assigns[:version_method] == :default
    end

    test "adds version headers to response" do
      conn =
        build_conn(:get, "/api/maps")
        |> Plug.Conn.fetch_query_params()
        |> ApiVersioning.call(ApiVersioning.init([]))

      assert get_resp_header(conn, "api-version") == ["1.2"]
      assert get_resp_header(conn, "api-supported-versions") == ["1.0, 1.1, 1.2"]
    end

    test "handles deprecated version with warning" do
      conn =
        build_conn(:get, "/api/maps")
        |> put_req_header("api-version", "1.0")
        |> Plug.Conn.fetch_query_params()
        |> ApiVersioning.call(ApiVersioning.init([]))

      assert conn.assigns[:api_version] == "1.0"
      warning_header = get_resp_header(conn, "warning")
      assert length(warning_header) > 0
      assert String.contains?(hd(warning_header), "deprecated")
    end

    test "handles unsupported version in strict mode" do
      conn =
        build_conn(:get, "/api/maps")
        |> put_req_header("api-version", "2.0")
        |> Plug.Conn.fetch_query_params()
        |> ApiVersioning.call(ApiVersioning.init(strict_versioning: true))

      assert conn.halted
      assert conn.status == 400

      response = json_response(conn, 400)
      assert response["error"] == "Unsupported API version"
      assert response["details"]["requested"] == "2.0"
    end

    test "falls back to latest version for newer unsupported versions" do
      conn =
        build_conn(:get, "/api/maps")
        |> put_req_header("api-version", "2.0")
        |> Plug.Conn.fetch_query_params()
        |> ApiVersioning.call(ApiVersioning.init([]))

      assert conn.assigns[:api_version] == "1.2"
      assert get_resp_header(conn, "api-version-fallback") == ["true"]
      assert get_resp_header(conn, "api-version-requested") == ["2.0"]
      assert get_resp_header(conn, "api-version-used") == ["1.2"]
    end

    test "rejects very old unsupported versions" do
      conn =
        build_conn(:get, "/api/maps")
        |> put_req_header("api-version", "0.9")
        |> Plug.Conn.fetch_query_params()
        |> ApiVersioning.call(ApiVersioning.init([]))

      assert conn.halted
      assert conn.status == 410

      response = json_response(conn, 410)
      assert response["error"] == "API version no longer supported"
      assert response["details"]["requested"] == "0.9"
      assert response["details"]["upgrade_required"] == true
    end
  end

  describe "version feature detection" do
    test "version 1.0 supports basic features only" do
      assert ApiVersioning.version_supports_feature?("1.0", :basic_crud)
      assert ApiVersioning.version_supports_feature?("1.0", :pagination)
      refute ApiVersioning.version_supports_feature?("1.0", :filtering)
      refute ApiVersioning.version_supports_feature?("1.0", :includes)
    end

    test "version 1.1 adds filtering and sparse fieldsets" do
      assert ApiVersioning.version_supports_feature?("1.1", :basic_crud)
      assert ApiVersioning.version_supports_feature?("1.1", :pagination)
      assert ApiVersioning.version_supports_feature?("1.1", :filtering)
      assert ApiVersioning.version_supports_feature?("1.1", :sorting)
      assert ApiVersioning.version_supports_feature?("1.1", :sparse_fieldsets)
      refute ApiVersioning.version_supports_feature?("1.1", :includes)
      refute ApiVersioning.version_supports_feature?("1.1", :bulk_operations)
    end

    test "version 1.2 supports all implemented features" do
      assert ApiVersioning.version_supports_feature?("1.2", :basic_crud)
      assert ApiVersioning.version_supports_feature?("1.2", :pagination)
      assert ApiVersioning.version_supports_feature?("1.2", :filtering)
      assert ApiVersioning.version_supports_feature?("1.2", :sorting)
      assert ApiVersioning.version_supports_feature?("1.2", :sparse_fieldsets)
      assert ApiVersioning.version_supports_feature?("1.2", :includes)
      assert ApiVersioning.version_supports_feature?("1.2", :bulk_operations)
      assert ApiVersioning.version_supports_feature?("1.2", :webhooks)
      assert ApiVersioning.version_supports_feature?("1.2", :real_time_events)
    end

    test "no version supports unimplemented features" do
      refute ApiVersioning.version_supports_feature?("1.0", :graphql)
      refute ApiVersioning.version_supports_feature?("1.1", :graphql)
      refute ApiVersioning.version_supports_feature?("1.2", :graphql)
      refute ApiVersioning.version_supports_feature?("1.2", :subscriptions)
    end
  end

  describe "version configuration" do
    test "returns correct config for version 1.0" do
      config = ApiVersioning.get_version_config("1.0")

      assert config.max_page_size == 100
      assert config.default_page_size == 20
      assert :basic_crud in config.features
      assert :pagination in config.features
      refute config.supports_includes
      refute config.supports_sparse_fields
    end

    test "returns correct config for version 1.1" do
      config = ApiVersioning.get_version_config("1.1")

      assert config.max_page_size == 200
      assert config.default_page_size == 25
      assert :filtering in config.features
      assert :sorting in config.features
      assert :sparse_fieldsets in config.features
      refute config.supports_includes
      assert config.supports_sparse_fields
    end

    test "returns correct config for version 1.2" do
      config = ApiVersioning.get_version_config("1.2")

      assert config.max_page_size == 500
      assert config.default_page_size == 50
      assert :includes in config.features
      assert :bulk_operations in config.features
      assert :webhooks in config.features
      assert config.supports_includes
      assert config.supports_sparse_fields
    end

    test "returns default config for unknown version" do
      config = ApiVersioning.get_version_config("unknown")

      # Should return same as default version (1.2)
      default_config = ApiVersioning.get_version_config("1.2")
      assert config == default_config
    end
  end

  describe "migration path" do
    test "provides migration info from 1.0 to 1.2" do
      migration = ApiVersioning.get_migration_path("1.0", "1.2")

      assert migration.from == "1.0"
      assert migration.to == "1.2"
      assert migration.estimated_effort == "high"
      assert is_list(migration.breaking_changes)
      assert length(migration.breaking_changes) > 0
      assert String.contains?(migration.migration_guide, "1.0-to-1.2")
    end

    test "provides migration info from 1.1 to 1.2" do
      migration = ApiVersioning.get_migration_path("1.1", "1.2")

      assert migration.from == "1.1"
      assert migration.to == "1.2"
      assert migration.estimated_effort == "low"
    end

    test "uses default target version when not specified" do
      migration = ApiVersioning.get_migration_path("1.0")

      assert migration.from == "1.0"
      assert migration.to == "1.2"
    end
  end

  describe "version comparison" do
    test "correctly identifies compatible versions" do
      assert ApiVersioning.compatible_version?("1.2", "1.0")
      assert ApiVersioning.compatible_version?("1.1", "1.0")
      assert ApiVersioning.compatible_version?("1.0", "1.0")
      refute ApiVersioning.compatible_version?("0.9", "1.0")
    end
  end
end
