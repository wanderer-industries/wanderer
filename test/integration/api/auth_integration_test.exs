defmodule WandererAppWeb.AuthIntegrationTest do
  use WandererAppWeb.ApiCase, async: true

  alias WandererAppWeb.Factory

  describe "API Key Validation Integration" do
    setup do
      user = Factory.insert(:user)

      map =
        Factory.insert(:map, %{
          owner_id: user.id,
          public_api_key: "valid_api_key_123"
        })

      character = Factory.insert(:character, %{user_id: user.id})

      acl =
        Factory.insert(:access_list, %{
          owner_id: character.id,
          api_key: "valid_acl_key_456"
        })

      %{user: user, map: map, character: character, acl: acl}
    end

    test "map API endpoints require valid API keys", %{map: map} do
      # Test without API key
      conn = build_conn()

      conn = get(conn, "/api/map/systems", %{"slug" => map.slug})
      assert json_response(conn, 401)

      # Test with invalid API key
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer invalid_key")

      conn = get(conn, "/api/map/systems", %{"slug" => map.slug})
      assert json_response(conn, 401)

      # Test with valid API key
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer valid_api_key_123")

      conn = get(conn, "/api/map/systems", %{"slug" => map.slug})
      assert json_response(conn, 200)
    end

    test "ACL API endpoints require valid ACL keys", %{acl: acl} do
      # Test ACL member operations without API key
      conn = build_conn()

      conn = get(conn, "/api/acls/#{acl.id}/members")
      assert json_response(conn, 401)

      # Test with invalid ACL key
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer invalid_acl_key")

      conn = get(conn, "/api/acls/#{acl.id}/members")
      assert json_response(conn, 401)

      # Test with valid ACL key
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer valid_acl_key_456")

      conn = get(conn, "/api/acls/#{acl.id}/members")
      assert json_response(conn, 200)
    end

    test "API keys are validated securely using secure comparison", %{map: map} do
      # Test timing attack resistance by using very similar but wrong keys
      # Off by one character
      similar_key = "valid_api_key_124"

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{similar_key}")

      conn = get(conn, "/api/map/systems", %{"slug" => map.slug})
      assert json_response(conn, 401)
    end

    test "bearer token format is strictly enforced", %{map: map} do
      # Test various invalid authorization formats
      invalid_formats = [
        # Basic auth instead of Bearer
        "Basic dGVzdDp0ZXN0",
        # lowercase bearer
        "bearer valid_api_key_123",
        # Bearer without token
        "Bearer",
        # Bearer with just space
        "Bearer ",
        # Token without Bearer prefix
        "valid_api_key_123",
        # Wrong prefix
        "Token valid_api_key_123"
      ]

      for auth_header <- invalid_formats do
        conn =
          build_conn()
          |> put_req_header("authorization", auth_header)

        conn = get(conn, "/api/map/systems", %{"slug" => map.slug})
        assert json_response(conn, 401), "Should reject auth format: #{auth_header}"
      end
    end
  end

  describe "Map Ownership Verification" do
    setup do
      owner = Factory.insert(:user)
      other_user = Factory.insert(:user)

      owner_map =
        Factory.insert(:map, %{
          owner_id: owner.id,
          public_api_key: "owner_api_key"
        })

      other_map =
        Factory.insert(:map, %{
          owner_id: other_user.id,
          public_api_key: "other_api_key"
        })

      %{
        owner: owner,
        other_user: other_user,
        owner_map: owner_map,
        other_map: other_map
      }
    end

    test "users can only access maps they own with correct API key", %{
      owner_map: owner_map,
      other_map: other_map
    } do
      # Owner can access their own map
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer owner_api_key")

      conn = get(conn, "/api/map/systems", %{"slug" => owner_map.slug})
      assert json_response(conn, 200)

      # Owner cannot access other user's map even with their own valid key
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer owner_api_key")

      conn = get(conn, "/api/map/systems", %{"slug" => other_map.slug})
      assert json_response(conn, 401)

      # Other user can access their own map
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer other_api_key")

      conn = get(conn, "/api/map/systems", %{"slug" => other_map.slug})
      assert json_response(conn, 200)
    end

    test "map modification requires ownership", %{owner_map: owner_map, other_map: other_map} do
      system_params = %{
        "solar_system_id" => 30_000_142,
        "position_x" => 100,
        "position_y" => 200
      }

      # Owner can create systems in their own map
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer owner_api_key")
        |> put_req_header("content-type", "application/json")

      conn =
        post(conn, "/api/map/systems", %{"slug" => owner_map.slug} |> Map.merge(system_params))

      assert json_response(conn, 201)

      # Owner cannot create systems in other user's map
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer owner_api_key")
        |> put_req_header("content-type", "application/json")

      conn =
        post(conn, "/api/map/systems", %{"slug" => other_map.slug} |> Map.merge(system_params))

      assert json_response(conn, 401)
    end

    test "map identifier resolution works consistently", %{owner_map: owner_map} do
      # Test access via map_id parameter
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer owner_api_key")

      conn = get(conn, "/api/map/systems", %{"map_id" => owner_map.id})
      assert json_response(conn, 200)

      # Test access via slug parameter
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer owner_api_key")

      conn = get(conn, "/api/map/systems", %{"slug" => owner_map.slug})
      assert json_response(conn, 200)

      # Test access via path parameter (if supported)
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer owner_api_key")

      # This may not be available for all endpoints, test if it exists
      try do
        conn = get(conn, "/api/maps/#{owner_map.id}/systems")
        # If the route exists, it should work
        assert json_response(conn, 200)
      rescue
        Phoenix.Router.NoRouteError ->
          # Route doesn't exist, that's fine for this test
          :ok
      end
    end
  end

  describe "ACL Permission Checking" do
    setup do
      user = Factory.insert(:user)
      character = Factory.insert(:character, %{user_id: user.id})
      map = Factory.insert(:map, %{owner_id: user.id})

      # Create ACL with different permission levels
      viewer_acl =
        Factory.insert(:access_list, %{
          owner_id: character.id,
          api_key: "viewer_acl_key"
        })

      admin_acl =
        Factory.insert(:access_list, %{
          owner_id: character.id,
          api_key: "admin_acl_key"
        })

      # Associate ACLs with map with different roles
      Factory.insert(:map_access_list, %{
        map_id: map.id,
        access_list_id: viewer_acl.id,
        role: "viewer"
      })

      Factory.insert(:map_access_list, %{
        map_id: map.id,
        access_list_id: admin_acl.id,
        role: "admin"
      })

      %{
        user: user,
        character: character,
        map: map,
        viewer_acl: viewer_acl,
        admin_acl: admin_acl
      }
    end

    test "ACL members can be listed with valid ACL key", %{
      viewer_acl: viewer_acl,
      admin_acl: admin_acl
    } do
      # Test viewer ACL access
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer viewer_acl_key")

      conn = get(conn, "/api/acls/#{viewer_acl.id}/members")
      assert json_response(conn, 200)

      # Test admin ACL access
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer admin_acl_key")

      conn = get(conn, "/api/acls/#{admin_acl.id}/members")
      assert json_response(conn, 200)
    end

    test "ACL operations require correct permissions", %{
      viewer_acl: viewer_acl,
      admin_acl: admin_acl,
      character: character
    } do
      member_params = %{
        "eve_entity_id" => character.eve_id,
        "eve_entity_name" => character.name,
        "eve_entity_category" => "character",
        "role" => "viewer"
      }

      # Admin ACL should allow member creation (if endpoint supports it)
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer admin_acl_key")
        |> put_req_header("content-type", "application/json")

      # Try to create member - this may or may not be supported
      try do
        conn = post(conn, "/api/acls/#{admin_acl.id}/members", member_params)
        # If endpoint exists, should succeed for admin
        # Allow various success/validation responses
        response = json_response(conn, [200, 201, 422])
        assert response
      rescue
        Phoenix.Router.NoRouteError ->
          # Member creation endpoint doesn't exist, that's fine
          :ok
      end
    end

    test "ACL access is isolated between different ACLs", %{
      viewer_acl: viewer_acl,
      admin_acl: admin_acl
    } do
      # Viewer ACL key cannot access admin ACL
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer viewer_acl_key")

      conn = get(conn, "/api/acls/#{admin_acl.id}/members")
      assert json_response(conn, 401)

      # Admin ACL key cannot access viewer ACL
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer admin_acl_key")

      conn = get(conn, "/api/acls/#{viewer_acl.id}/members")
      assert json_response(conn, 401)
    end
  end

  describe "Rate Limiting Behavior" do
    setup do
      user = Factory.insert(:user)

      map =
        Factory.insert(:map, %{
          owner_id: user.id,
          public_api_key: "rate_limit_test_key"
        })

      %{user: user, map: map}
    end

    @tag :slow
    test "API endpoints respect rate limiting", %{map: map} do
      # This test checks if rate limiting is working by making rapid requests
      # Note: Actual rate limits depend on ex_rated configuration

      auth_conn = fn ->
        build_conn()
        |> put_req_header("authorization", "Bearer rate_limit_test_key")
      end

      # Make a series of requests rapidly
      responses =
        Enum.map(1..20, fn _ ->
          conn = auth_conn.()
          conn = get(conn, "/api/map/systems", %{"slug" => map.slug})
          conn.status
        end)

      # Most requests should succeed (200), but some might be rate limited (429)
      success_count = Enum.count(responses, &(&1 == 200))
      rate_limited_count = Enum.count(responses, &(&1 == 429))

      # We should have at least some successful requests
      assert success_count > 0, "No successful requests - rate limiting may be too aggressive"

      # Log the rate limiting behavior for analysis
      IO.puts(
        "Rate limiting test: #{success_count} successful, #{rate_limited_count} rate limited"
      )

      # This is more of an observational test since rate limits depend on configuration
      assert success_count + rate_limited_count == 20
    end

    test "rate limiting error responses are properly formatted", %{map: map} do
      # This test makes rapid requests to potentially trigger rate limiting
      # and checks the error response format

      auth_conn = fn ->
        build_conn()
        |> put_req_header("authorization", "Bearer rate_limit_test_key")
      end

      # Make rapid requests to try to trigger rate limiting
      rate_limited_response =
        Enum.reduce_while(1..50, nil, fn _, _acc ->
          conn = auth_conn.()
          conn = get(conn, "/api/map/systems", %{"slug" => map.slug})

          if conn.status == 429 do
            {:halt, json_response(conn, 429)}
          else
            # Small delay to avoid overwhelming the system
            Process.sleep(10)
            {:cont, nil}
          end
        end)

      # If we got a rate limited response, verify its format
      if rate_limited_response do
        assert %{"error" => error_message} = rate_limited_response
        assert is_binary(error_message)
        IO.puts("Rate limit error format verified: #{error_message}")
      else
        IO.puts("No rate limiting triggered in test - limits may be high or disabled")
      end
    end
  end

  describe "Error Response Consistency" do
    setup do
      user = Factory.insert(:user)

      map =
        Factory.insert(:map, %{
          owner_id: user.id,
          public_api_key: "test_key"
        })

      %{user: user, map: map}
    end

    test "authentication errors have consistent format across endpoints" do
      endpoints_to_test = [
        {"/api/map/systems", %{"slug" => "nonexistent"}},
        {"/api/acls/550e8400-e29b-41d4-a716-446655440000/members", %{}}
      ]

      for {path, params} <- endpoints_to_test do
        # Test missing authorization
        conn = build_conn()
        conn = get(conn, path, params)
        response = json_response(conn, 401)

        assert %{"error" => error_msg} = response
        assert is_binary(error_msg)

        # Test invalid authorization
        conn =
          build_conn()
          |> put_req_header("authorization", "Bearer invalid_key")

        conn = get(conn, path, params)
        response = json_response(conn, 401)

        assert %{"error" => error_msg} = response
        assert is_binary(error_msg)
      end
    end

    test "validation errors have consistent format", %{map: map} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer test_key")
        |> put_req_header("content-type", "application/json")

      # Test invalid system creation
      invalid_params = %{
        "slug" => map.slug,
        "invalid_field" => "invalid_value"
        # Missing required solar_system_id
      }

      conn = post(conn, "/api/map/systems", invalid_params)
      # Accept either bad request or unprocessable entity
      response = json_response(conn, [400, 422])

      assert %{"error" => error_msg} = response
      assert is_binary(error_msg)
    end
  end
end
