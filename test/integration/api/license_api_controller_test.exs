defmodule WandererAppWeb.LicenseApiControllerTest do
  use WandererAppWeb.ApiCase

  alias WandererApp.Factory
  import Mox

  setup :verify_on_exit!

  # Note: These tests require LM_AUTH_KEY authentication
  # The actual authentication logic would be tested separately

  describe "POST /api/licenses (create)" do
    setup do
      # Mock LM authentication (would be handled by plug in real implementation)
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer test-lm-auth-key")

      %{conn: conn}
    end

    test "creates a license for a map with active subscription", %{conn: conn} do
      map =
        Factory.insert(:map, %{
          subscription_active: true,
          subscription_expires_at: DateTime.add(DateTime.utc_now(), 30, :day)
        })

      # Mock LicenseManager.create_license_for_map
      expect(WandererApp.License.LicenseManager.Mock, :create_license_for_map, fn ^map.id ->
        {:ok,
         %{
           id: "license-uuid-123",
           license_key: "BOT-ABCD1234EFGH",
           is_valid: true,
           expire_at: ~U[2024-12-31 23:59:59Z],
           map_id: map.id
         }}
      end)

      license_params = %{
        "map_id" => map.id
      }

      conn = post(conn, ~p"/api/licenses", license_params)

      assert %{
               "id" => "license-uuid-123",
               "license_key" => "BOT-ABCD1234EFGH",
               "is_valid" => true,
               "expire_at" => "2024-12-31T23:59:59Z",
               "map_id" => ^map.id
             } = json_response(conn, 201)
    end

    test "returns error for map without active subscription", %{conn: conn} do
      map = Factory.insert(:map, %{subscription_active: false})

      # Mock LicenseManager.create_license_for_map to return subscription error
      expect(WandererApp.License.LicenseManager.Mock, :create_license_for_map, fn ^map.id ->
        {:error, :no_active_subscription}
      end)

      license_params = %{
        "map_id" => map.id
      }

      conn = post(conn, ~p"/api/licenses", license_params)

      assert %{
               "error" => "Map does not have an active subscription"
             } = json_response(conn, 400)
    end

    test "returns error for non-existent map", %{conn: conn} do
      non_existent_id = "00000000-0000-0000-0000-000000000000"

      # Mock Map.by_id to return not found
      expect(WandererApp.Api.Map.Mock, :by_id, fn ^non_existent_id ->
        {:error, :not_found}
      end)

      license_params = %{
        "map_id" => non_existent_id
      }

      conn = post(conn, ~p"/api/licenses", license_params)

      assert %{
               "error" => "Map not found"
             } = json_response(conn, 404)
    end

    test "requires map_id parameter", %{conn: conn} do
      conn = post(conn, ~p"/api/licenses", %{})

      assert %{
               "error" => "Missing required parameter: map_id"
             } = json_response(conn, 400)
    end

    test "handles license creation failure", %{conn: conn} do
      map = Factory.insert(:map)

      # Mock LicenseManager.create_license_for_map to return generic error
      expect(WandererApp.License.LicenseManager.Mock, :create_license_for_map, fn ^map.id ->
        {:error, :database_error}
      end)

      license_params = %{
        "map_id" => map.id
      }

      conn = post(conn, ~p"/api/licenses", license_params)

      assert %{
               "error" => "Failed to create license"
             } = json_response(conn, 500)
    end
  end

  describe "PUT /api/licenses/:id/validity (update_validity)" do
    setup do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer test-lm-auth-key")

      %{conn: conn}
    end

    test "updates license validity", %{conn: conn} do
      license_id = "license-uuid-123"

      # Mock License.by_id
      expect(WandererApp.Api.License.Mock, :by_id, fn ^license_id ->
        {:ok, %{id: license_id, is_valid: true}}
      end)

      # Mock LicenseManager.invalidate_license
      expect(WandererApp.License.LicenseManager.Mock, :invalidate_license, fn ^license_id ->
        {:ok,
         %{
           id: license_id,
           license_key: "BOT-ABCD1234EFGH",
           is_valid: false,
           expire_at: ~U[2024-12-31 23:59:59Z],
           map_id: "map-uuid-123"
         }}
      end)

      update_params = %{
        "is_valid" => false
      }

      conn = put(conn, ~p"/api/licenses/#{license_id}/validity", update_params)

      assert %{
               "id" => ^license_id,
               "is_valid" => false
             } = json_response(conn, 200)
    end

    test "returns error for non-existent license", %{conn: conn} do
      license_id = "non-existent-license"

      # Mock License.by_id to return not found
      expect(WandererApp.Api.License.Mock, :by_id, fn ^license_id ->
        {:error, :not_found}
      end)

      update_params = %{
        "is_valid" => false
      }

      conn = put(conn, ~p"/api/licenses/#{license_id}/validity", update_params)

      assert %{
               "error" => "License not found"
             } = json_response(conn, 404)
    end

    test "requires is_valid parameter", %{conn: conn} do
      license_id = "license-uuid-123"

      conn = put(conn, ~p"/api/licenses/#{license_id}/validity", %{})

      assert %{
               "error" => "Missing required parameter: is_valid"
             } = json_response(conn, 400)
    end
  end

  describe "PUT /api/licenses/:id/expiration (update_expiration)" do
    setup do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer test-lm-auth-key")

      %{conn: conn}
    end

    test "updates license expiration", %{conn: conn} do
      license_id = "license-uuid-123"
      new_expiration = "2025-12-31T23:59:59Z"

      # Mock License.by_id
      expect(WandererApp.Api.License.Mock, :by_id, fn ^license_id ->
        {:ok, %{id: license_id}}
      end)

      # Mock LicenseManager.update_expiration
      expect(WandererApp.License.LicenseManager.Mock, :update_expiration, fn ^license_id,
                                                                             ^new_expiration ->
        {:ok,
         %{
           id: license_id,
           license_key: "BOT-ABCD1234EFGH",
           is_valid: true,
           expire_at: ~U[2025-12-31 23:59:59Z],
           map_id: "map-uuid-123"
         }}
      end)

      update_params = %{
        "expire_at" => new_expiration
      }

      conn = put(conn, ~p"/api/licenses/#{license_id}/expiration", update_params)

      assert %{
               "id" => ^license_id,
               "expire_at" => "2025-12-31T23:59:59Z"
             } = json_response(conn, 200)
    end

    test "returns error for non-existent license", %{conn: conn} do
      license_id = "non-existent-license"

      # Mock License.by_id to return not found
      expect(WandererApp.Api.License.Mock, :by_id, fn ^license_id ->
        {:error, :not_found}
      end)

      update_params = %{
        "expire_at" => "2025-12-31T23:59:59Z"
      }

      conn = put(conn, ~p"/api/licenses/#{license_id}/expiration", update_params)

      assert %{
               "error" => "License not found"
             } = json_response(conn, 404)
    end

    test "requires expire_at parameter", %{conn: conn} do
      license_id = "license-uuid-123"

      conn = put(conn, ~p"/api/licenses/#{license_id}/expiration", %{})

      assert %{
               "error" => "Missing required parameter: expire_at"
             } = json_response(conn, 400)
    end
  end

  describe "GET /api/licenses/map/:map_id (get_by_map_id)" do
    setup do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer test-lm-auth-key")

      %{conn: conn}
    end

    test "returns license for a map", %{conn: conn} do
      map_id = "map-uuid-123"

      # Mock LicenseManager.get_license_by_map_id
      expect(WandererApp.License.LicenseManager.Mock, :get_license_by_map_id, fn ^map_id ->
        {:ok,
         %{
           id: "license-uuid-123",
           license_key: "BOT-ABCD1234EFGH",
           is_valid: true,
           expire_at: ~U[2024-12-31 23:59:59Z],
           map_id: map_id
         }}
      end)

      conn = get(conn, ~p"/api/licenses/map/#{map_id}")

      assert %{
               "id" => "license-uuid-123",
               "license_key" => "BOT-ABCD1234EFGH",
               "is_valid" => true,
               "map_id" => ^map_id
             } = json_response(conn, 200)
    end

    test "returns error when no license found for map", %{conn: conn} do
      map_id = "map-without-license"

      # Mock LicenseManager.get_license_by_map_id to return not found
      expect(WandererApp.License.LicenseManager.Mock, :get_license_by_map_id, fn ^map_id ->
        {:error, :license_not_found}
      end)

      conn = get(conn, ~p"/api/licenses/map/#{map_id}")

      assert %{
               "error" => "No license found for this map"
             } = json_response(conn, 404)
    end
  end

  describe "GET /api/license/validate (validate)" do
    test "validates a license key" do
      # Mock license validation (would be handled by license auth plug)
      license = %{
        id: "license-uuid-123",
        license_key: "BOT-ABCD1234EFGH",
        is_valid: true,
        expire_at: ~U[2024-12-31 23:59:59Z],
        map_id: "map-uuid-123"
      }

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer BOT-ABCD1234EFGH")
        # Would be set by authentication plug
        |> assign(:license, license)

      conn = get(conn, ~p"/api/license/validate")

      assert %{
               "license_valid" => true,
               "expire_at" => "2024-12-31T23:59:59Z",
               "map_id" => "map-uuid-123"
             } = json_response(conn, 200)
    end

    test "validates an invalid license" do
      license = %{
        id: "license-uuid-123",
        license_key: "BOT-INVALID1234",
        is_valid: false,
        expire_at: ~U[2024-12-31 23:59:59Z],
        map_id: "map-uuid-123"
      }

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer BOT-INVALID1234")
        |> assign(:license, license)

      conn = get(conn, ~p"/api/license/validate")

      assert %{
               "license_valid" => false,
               "expire_at" => "2024-12-31T23:59:59Z",
               "map_id" => "map-uuid-123"
             } = json_response(conn, 200)
    end

    test "validates an expired license" do
      license = %{
        id: "license-uuid-123",
        license_key: "BOT-EXPIRED1234",
        is_valid: true,
        # Expired
        expire_at: ~U[2023-12-31 23:59:59Z],
        map_id: "map-uuid-123"
      }

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer BOT-EXPIRED1234")
        |> assign(:license, license)

      conn = get(conn, ~p"/api/license/validate")

      assert %{
               # is_valid flag, expiration would be checked separately
               "license_valid" => true,
               "expire_at" => "2023-12-31T23:59:59Z",
               "map_id" => "map-uuid-123"
             } = json_response(conn, 200)
    end
  end
end
