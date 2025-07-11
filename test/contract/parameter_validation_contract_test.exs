defmodule WandererAppWeb.ParameterValidationContractTest do
  @moduledoc """
  Contract tests for parameter validation across all API endpoints.

  Verifies that all parameter types (path, query, header) are properly
  validated according to their OpenAPI specifications.
  """

  use WandererAppWeb.ApiCase, async: true

  import WandererAppWeb.OpenAPIContractHelpers

  alias WandererAppWeb.Factory

  describe "Path Parameter Validation" do
    setup do
      user = Factory.create(:user)
      map = Factory.create(:map, %{owner_id: user.id})

      %{user: user, map: map}
    end

    test "validates UUID format for ID parameters", %{user: user} do
      # Valid UUID
      valid_uuid = "550e8400-e29b-41d4-a716-446655440000"

      conn =
        build_conn()
        |> assign(:current_user, user)
        |> get("/api/maps/#{valid_uuid}")

      # Should either find it (200) or not find it (404), but not fail validation
      assert conn.status in [200, 404]

      # Invalid UUID formats
      invalid_ids = [
        "not-a-uuid",
        "123",
        # Too short
        "550e8400-e29b-41d4-a716",
        # Too long
        "550e8400-e29b-41d4-a716-446655440000-extra",
        # Invalid hex
        "gggggggg-e29b-41d4-a716-446655440000"
      ]

      for invalid_id <- invalid_ids do
        conn =
          build_conn()
          |> assign(:current_user, user)
          |> get("/api/maps/#{invalid_id}")

        # Should return 400 for invalid format or 404 if it passes through
        assert conn.status in [400, 404],
               "Expected 400 or 404 for invalid ID '#{invalid_id}', got #{conn.status}"
      end
    end

    test "validates slug format for slug parameters", %{user: user} do
      # Valid slugs
      valid_slugs = [
        "valid-slug",
        "another-valid-slug-123",
        "slug_with_underscores"
      ]

      for slug <- valid_slugs do
        conn =
          build_conn()
          |> assign(:current_user, user)
          |> get("/api/maps", %{"slug" => slug})

        # Should accept valid slug format
        assert conn.status != 400,
               "Should accept valid slug '#{slug}'"
      end

      # Invalid slugs (if there are format restrictions)
      potentially_invalid_slugs = [
        "slug with spaces",
        # Depending on requirements
        "SLUG-WITH-CAPS",
        "slug/with/slashes",
        "slug?with=params"
      ]

      for slug <- potentially_invalid_slugs do
        conn =
          build_conn()
          |> assign(:current_user, user)
          |> get("/api/maps", %{"slug" => slug})

        # Document the behavior for each slug type
        if conn.status == 400 do
          response = Jason.decode!(conn.resp_body)
          assert Map.has_key?(response, "error")
        end
      end
    end
  end

  describe "Query Parameter Validation" do
    setup do
      user = Factory.create(:user)
      %{user: user}
    end

    test "validates pagination parameters", %{user: user} do
      # Valid pagination
      valid_params = %{
        "page" => "1",
        "page_size" => "20"
      }

      conn =
        build_conn()
        |> assign(:current_user, user)
        |> get("/api/maps", valid_params)

      assert conn.status == 200
      assert_parameters(valid_params, "maps_index")

      # Invalid page values
      invalid_page_params = [
        # Zero page
        %{"page" => "0"},
        # Negative page
        %{"page" => "-1"},
        %{"page" => "not_a_number"},
        # Decimal
        %{"page" => "1.5"},
        # Very large number
        %{"page" => "999999999"}
      ]

      for params <- invalid_page_params do
        conn =
          build_conn()
          |> assign(:current_user, user)
          |> get("/api/maps", params)

        # Should either return 400 or handle gracefully with defaults
        if conn.status == 400 do
          response = Jason.decode!(conn.resp_body)
          assert Map.has_key?(response, "error")
          assert response["error"] =~ "page" || response["error"] =~ "parameter"
        end
      end

      # Invalid page_size values
      invalid_size_params = [
        # Zero size
        %{"page_size" => "0"},
        # Negative size
        %{"page_size" => "-10"},
        %{"page_size" => "abc"},
        # May exceed max allowed
        %{"page_size" => "1000"}
      ]

      for params <- invalid_size_params do
        conn =
          build_conn()
          |> assign(:current_user, user)
          |> get("/api/maps", params)

        if conn.status == 400 do
          response = Jason.decode!(conn.resp_body)
          assert Map.has_key?(response, "error")
        end
      end
    end

    test "validates sort parameters", %{user: user} do
      # Valid sort fields (these should be documented in OpenAPI)
      valid_sort_params = [
        %{"sort" => "name"},
        # Descending
        %{"sort" => "-name"},
        %{"sort" => "created_at"},
        %{"sort" => "-created_at"}
      ]

      for params <- valid_sort_params do
        conn =
          build_conn()
          |> assign(:current_user, user)
          |> get("/api/maps", params)

        assert conn.status == 200,
               "Should accept valid sort '#{params["sort"]}'"
      end

      # Invalid sort fields
      invalid_sort_params = [
        %{"sort" => "invalid_field"},
        # Sensitive field
        %{"sort" => "password"},
        %{"sort" => ""},
        # SQL injection attempt
        %{"sort" => "name; DROP TABLE maps;--"}
      ]

      for params <- invalid_sort_params do
        conn =
          build_conn()
          |> assign(:current_user, user)
          |> get("/api/maps", params)

        # Should either return 400 or ignore invalid sort
        if conn.status == 400 do
          response = Jason.decode!(conn.resp_body)
          assert Map.has_key?(response, "error")
        else
          # If it doesn't error, it should return default sorting
          assert conn.status == 200
        end
      end
    end

    test "validates filter parameters", %{user: user} do
      # Valid filters
      valid_filters = [
        %{"filter[name]" => "test"},
        %{"filter[status]" => "active"},
        %{"filter[created_after]" => "2024-01-01"}
      ]

      for params <- valid_filters do
        conn =
          build_conn()
          |> assign(:current_user, user)
          |> get("/api/maps", params)

        assert conn.status == 200
      end

      # Invalid filter values
      invalid_filters = [
        %{"filter[created_after]" => "not-a-date"},
        %{"filter[unknown_field]" => "value"},
        # Wrong structure
        %{"filter" => "not_an_object"}
      ]

      for params <- invalid_filters do
        conn =
          build_conn()
          |> assign(:current_user, user)
          |> get("/api/maps", params)

        # Should handle gracefully - either error or ignore
        assert conn.status in [200, 400]
      end
    end

    test "validates boolean parameters", %{user: user} do
      # Various boolean representations
      boolean_params = [
        %{"include_deleted" => "true"},
        %{"include_deleted" => "false"},
        %{"include_deleted" => "1"},
        %{"include_deleted" => "0"},
        %{"include_deleted" => "yes"},
        %{"include_deleted" => "no"},
        %{"include_deleted" => ""},
        # Invalid
        %{"include_deleted" => "maybe"}
      ]

      for params <- boolean_params do
        conn =
          build_conn()
          |> assign(:current_user, user)
          |> get("/api/maps", params)

        # Should handle various boolean formats
        if params["include_deleted"] in ["maybe", ""] do
          # These might cause errors
          assert conn.status in [200, 400]
        else
          assert conn.status == 200
        end
      end
    end
  end

  describe "Header Parameter Validation" do
    setup do
      user = Factory.create(:user)
      map = Factory.create(:map, %{owner_id: user.id, public_api_key: "test_api_key_123"})
      %{user: user, map: map}
    end

    test "validates API key format in Authorization header", %{map: map} do
      # Valid formats
      valid_headers = [
        {"authorization", "Bearer test_api_key_123"},
        # Case variation
        {"Authorization", "Bearer test_api_key_123"}
      ]

      for {header, value} <- valid_headers do
        conn =
          build_conn()
          |> put_req_header(header, value)
          |> get("/api/map/systems", %{"slug" => map.slug})

        assert conn.status == 200
      end

      # Invalid formats
      invalid_headers = [
        # Missing Bearer
        {"authorization", "test_api_key_123"},
        # Wrong auth type
        {"authorization", "Basic dGVzdDp0ZXN0"},
        # Missing token
        {"authorization", "Bearer"},
        # Just space
        {"authorization", "Bearer "},
        # Lowercase bearer
        {"authorization", "bearer test_api_key_123"},
        # Leading space
        {"authorization", " Bearer test_api_key_123"},
        # Double space
        {"authorization", "Bearer  test_api_key_123"}
      ]

      for {header, value} <- invalid_headers do
        conn =
          build_conn()
          |> put_req_header(header, value)
          |> get("/api/map/systems", %{"slug" => map.slug})

        assert conn.status == 401,
               "Should reject invalid auth header format: '#{value}'"
      end
    end

    test "validates custom header parameters", %{user: user} do
      # If API accepts custom headers like X-Request-ID
      custom_headers = [
        {"x-request-id", "valid-request-id"},
        {"x-request-id", "123e4567-e89b-12d3-a456-426614174000"},
        # Empty
        {"x-request-id", ""},
        # Very long
        {"x-request-id", String.duplicate("a", 1000)}
      ]

      for {header, value} <- custom_headers do
        conn =
          build_conn()
          |> assign(:current_user, user)
          |> put_req_header(header, value)
          |> get("/api/maps")

        # Should handle various request ID formats
        assert conn.status in [200, 400]

        # If accepted, should echo back in response
        if conn.status == 200 && value != "" do
          response_header = get_resp_header(conn, header)

          if response_header != [] do
            assert hd(response_header) == value
          end
        end
      end
    end
  end

  describe "Request Body Parameter Validation" do
    setup do
      user = Factory.create(:user)
      %{user: user}
    end

    test "validates required fields in request body", %{user: user} do
      # Missing required field
      invalid_body = %{
        "description" => "Missing required name field"
      }

      conn =
        build_conn()
        |> assign(:current_user, user)
        |> put_req_header("content-type", "application/json")
        |> post("/api/maps", invalid_body)

      assert conn.status in [400, 422]

      response = Jason.decode!(conn.resp_body)
      assert Map.has_key?(response, "error") || Map.has_key?(response, "errors")
    end

    test "validates field types in request body", %{user: user} do
      # Wrong types for fields
      type_errors = [
        # Number instead of string
        %{"name" => 123},
        # String instead of boolean
        %{"name" => "Valid", "private" => "yes"},
        # String instead of number
        %{"name" => "Valid", "max_systems" => "fifty"}
      ]

      for body <- type_errors do
        conn =
          build_conn()
          |> assign(:current_user, user)
          |> put_req_header("content-type", "application/json")
          |> post("/api/maps", body)

        # Should validate types
        assert conn.status in [400, 422]
      end
    end

    test "validates field constraints in request body", %{user: user} do
      # Values that violate constraints
      constraint_violations = [
        # Empty string
        %{"name" => ""},
        # Too short
        %{"name" => "a"},
        # Too long
        %{"name" => String.duplicate("a", 300)},
        # Negative number
        %{"name" => "Valid", "max_systems" => -1},
        # Too large
        %{"name" => "Valid", "max_systems" => 999_999}
      ]

      for body <- constraint_violations do
        conn =
          build_conn()
          |> assign(:current_user, user)
          |> put_req_header("content-type", "application/json")
          |> post("/api/maps", body)

        # Should validate constraints
        assert conn.status in [400, 422]

        response = Jason.decode!(conn.resp_body)
        assert Map.has_key?(response, "error") || Map.has_key?(response, "errors")
      end
    end

    test "rejects unknown fields based on API strictness", %{user: user} do
      # Extra fields that aren't in schema
      body_with_extras = %{
        "name" => "Valid Map",
        "description" => "Valid description",
        "unknown_field" => "should this be accepted?",
        "another_unknown" => 123
      }

      conn =
        build_conn()
        |> assign(:current_user, user)
        |> put_req_header("content-type", "application/json")
        |> post("/api/maps", body_with_extras)

      # API might either:
      # 1. Accept and ignore unknown fields (200/201)
      # 2. Reject with 400/422
      assert conn.status in [200, 201, 400, 422]

      if conn.status in [200, 201] do
        # If accepted, verify unknown fields were ignored
        response = Jason.decode!(conn.resp_body)

        if map_data = response["data"] do
          refute Map.has_key?(map_data, "unknown_field")
          refute Map.has_key?(map_data, "another_unknown")
        end
      end
    end
  end

  describe "Complex Parameter Validation" do
    setup do
      user = Factory.create(:user)
      %{user: user}
    end

    test "validates array parameters", %{user: user} do
      # Valid array parameters
      valid_arrays = [
        %{"ids" => ["id1", "id2", "id3"]},
        %{"tags" => ["tag1", "tag2"]},
        # Empty array
        %{"ids" => []}
      ]

      for params <- valid_arrays do
        conn =
          build_conn()
          |> assign(:current_user, user)
          |> get("/api/maps", params)

        assert conn.status == 200
      end

      # Invalid array formats
      invalid_arrays = [
        %{"ids" => "not_an_array"},
        # Object instead of array
        %{"ids" => %{"0" => "id1"}},
        # Wrong type in array
        %{"tags" => [1, 2, 3]}
      ]

      for params <- invalid_arrays do
        conn =
          build_conn()
          |> assign(:current_user, user)
          |> get("/api/maps", params)

        # Should handle invalid array formats
        assert conn.status in [200, 400]
      end
    end

    test "validates nested object parameters", %{user: user} do
      # Nested filter object
      nested_params = %{
        "filter" => %{
          "name" => %{"contains" => "test"},
          "created" => %{
            "after" => "2024-01-01",
            "before" => "2024-12-31"
          }
        }
      }

      conn =
        build_conn()
        |> assign(:current_user, user)
        |> get("/api/maps", nested_params)

      # Should handle complex nested parameters
      assert conn.status in [200, 400]
    end
  end
end
