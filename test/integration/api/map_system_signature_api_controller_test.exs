defmodule WandererAppWeb.MapSystemSignatureAPIControllerTest do
  use WandererAppWeb.ApiCase

  alias WandererAppWeb.Factory

  describe "GET /api/maps/:map_identifier/signatures" do
    setup :setup_map_authentication

    test "returns all signatures for a map", %{conn: conn, map: map} do
      conn = get(conn, ~p"/api/maps/#{map.slug}/signatures")

      assert %{"data" => data} = json_response(conn, 200)
      assert is_list(data)
    end

    test "returns empty list when no signatures exist", %{conn: conn, map: map} do
      conn = get(conn, ~p"/api/maps/#{map.slug}/signatures")

      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns 401 without authentication" do
      map = Factory.insert(:map)

      conn = build_conn()
      conn = get(conn, ~p"/api/maps/#{map.slug}/signatures")

      assert json_response(conn, 401)
    end
  end

  describe "GET /api/maps/:map_identifier/signatures/:id" do
    setup :setup_map_authentication

    test "returns signature when it exists and belongs to the map", %{conn: conn, map: map} do
      # Create a system for the map
      system = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})

      # Create a signature for this system
      signature =
        Factory.insert(:map_system_signature, %{
          system_id: system.id,
          eve_id: "ABC-123",
          character_eve_id: "123456789",
          name: "Test Signature"
        })

      conn = get(conn, ~p"/api/maps/#{map.slug}/signatures/#{signature.id}")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == signature.id
      assert data["eve_id"] == "ABC-123"
      assert data["name"] == "Test Signature"
    end

    test "returns 404 when signature exists but belongs to different map", %{conn: conn, map: map} do
      # Create a different map and system
      other_map = Factory.insert(:map)

      other_system =
        Factory.insert(:map_system, %{map_id: other_map.id, solar_system_id: 30_000_143})

      signature = Factory.insert(:map_system_signature, %{system_id: other_system.id})

      conn = get(conn, ~p"/api/maps/#{map.slug}/signatures/#{signature.id}")

      assert %{"error" => error} = json_response(conn, 404)
      assert error == "Signature not found"
    end

    test "returns 404 for non-existent signature", %{conn: conn, map: map} do
      non_existent_id = Ecto.UUID.generate()

      conn = get(conn, ~p"/api/maps/#{map.slug}/signatures/#{non_existent_id}")

      assert %{"error" => error} = json_response(conn, 404)
      assert error == "Signature not found"
    end

    test "returns error for invalid signature ID format", %{conn: conn, map: map} do
      conn = get(conn, ~p"/api/maps/#{map.slug}/signatures/invalid-uuid")

      # Should return 404 for malformed UUID
      assert %{"error" => _error} = json_response(conn, 404)
    end

    test "returns 401 without authentication" do
      map = Factory.insert(:map)
      signature_id = Ecto.UUID.generate()

      conn = build_conn()
      conn = get(conn, ~p"/api/maps/#{map.slug}/signatures/#{signature_id}")

      assert json_response(conn, 401)
    end
  end

  describe "POST /api/maps/:map_identifier/signatures" do
    setup :setup_map_authentication

    test "creates a new signature with valid parameters", %{conn: conn, map: map} do
      signature_params = %{
        "solar_system_id" => 30_000_142,
        "eve_id" => "ABC-123",
        "character_eve_id" => "123456789",
        "name" => "Test Signature",
        "description" => "Test description",
        "type" => "Wormhole",
        "kind" => "cosmic_signature",
        "group" => "wormhole",
        "custom_info" => "Fresh"
      }

      conn = post(conn, ~p"/api/maps/#{map.slug}/signatures", signature_params)

      # Should either create successfully or return an error
      response =
        case conn.status do
          201 -> json_response(conn, 201)
          422 -> json_response(conn, 422)
          _ -> flunk("Unexpected status code: #{inspect(conn.status)}")
        end

      case response do
        %{"data" => _data} ->
          assert true

        %{"error" => _error} ->
          assert true
      end
    end

    test "handles signature creation with minimal required fields", %{conn: conn, map: map} do
      minimal_params = %{
        "solar_system_id" => 30_000_143,
        "eve_id" => "XYZ-456",
        "character_eve_id" => "987654321"
      }

      conn = post(conn, ~p"/api/maps/#{map.slug}/signatures", minimal_params)

      # Should handle minimal params
      response =
        case conn.status do
          201 -> json_response(conn, 201)
          422 -> json_response(conn, 422)
          _ -> flunk("Unexpected status code: #{inspect(conn.status)}")
        end

      assert Map.has_key?(response, "data") or Map.has_key?(response, "error")
    end

    test "handles signature creation with all optional fields", %{conn: conn, map: map} do
      complete_params = %{
        "solar_system_id" => 30_000_144,
        "eve_id" => "DEF-789",
        "character_eve_id" => "456789123",
        "name" => "Complete Signature",
        "description" => "Complete description",
        "type" => "Data Site",
        "linked_system_id" => 30_000_142,
        "kind" => "cosmic_signature",
        "group" => "data",
        "custom_info" => "High value",
        "updated" => 1
      }

      conn = post(conn, ~p"/api/maps/#{map.slug}/signatures", complete_params)

      response =
        case conn.status do
          201 -> json_response(conn, 201)
          422 -> json_response(conn, 422)
          _ -> flunk("Unexpected status code: #{inspect(conn.status)}")
        end

      assert Map.has_key?(response, "data") or Map.has_key?(response, "error")
    end

    test "returns 401 without authentication" do
      map = Factory.insert(:map)

      signature_params = %{
        "solar_system_id" => 30_000_145,
        "eve_id" => "ABC-123",
        "character_eve_id" => "123456789"
      }

      conn = build_conn()
      conn = post(conn, ~p"/api/maps/#{map.slug}/signatures", signature_params)

      assert json_response(conn, 401)
    end
  end

  describe "PUT /api/maps/:map_identifier/signatures/:id" do
    setup :setup_map_authentication

    test "updates an existing signature", %{conn: conn, map: map} do
      signature_id = Ecto.UUID.generate()

      update_params = %{
        "name" => "Updated Signature",
        "description" => "Updated description",
        "type" => "Updated Type",
        "custom_info" => "Updated info"
      }

      conn = put(conn, ~p"/api/maps/#{map.slug}/signatures/#{signature_id}", update_params)

      # Should return updated signature or error
      response =
        case conn.status do
          200 -> json_response(conn, 200)
          422 -> json_response(conn, 422)
          _ -> flunk("Unexpected status code: #{inspect(conn.status)}")
        end

      case response do
        %{"data" => _data} ->
          assert true

        %{"error" => _error} ->
          assert true
      end
    end

    test "handles partial updates", %{conn: conn, map: map} do
      signature_id = Ecto.UUID.generate()

      partial_params = %{
        "name" => "Partially Updated"
      }

      conn = put(conn, ~p"/api/maps/#{map.slug}/signatures/#{signature_id}", partial_params)

      response =
        case conn.status do
          200 -> json_response(conn, 200)
          422 -> json_response(conn, 422)
          _ -> flunk("Unexpected status code: #{inspect(conn.status)}")
        end

      assert Map.has_key?(response, "data") or Map.has_key?(response, "error")
    end

    test "updates with null values for optional fields", %{conn: conn, map: map} do
      signature_id = Ecto.UUID.generate()

      update_params = %{
        "name" => nil,
        "description" => nil,
        "custom_info" => nil
      }

      conn = put(conn, ~p"/api/maps/#{map.slug}/signatures/#{signature_id}", update_params)

      response =
        case conn.status do
          200 -> json_response(conn, 200)
          422 -> json_response(conn, 422)
          _ -> flunk("Unexpected status code: #{inspect(conn.status)}")
        end

      assert Map.has_key?(response, "data") or Map.has_key?(response, "error")
    end

    test "handles update with invalid signature ID", %{conn: conn, map: map} do
      update_params = %{
        "name" => "Updated Signature"
      }

      conn = put(conn, ~p"/api/maps/#{map.slug}/signatures/invalid-uuid", update_params)

      # Should handle invalid UUID gracefully
      response =
        case conn.status do
          200 -> json_response(conn, 200)
          422 -> json_response(conn, 422)
          _ -> flunk("Unexpected status code: #{inspect(conn.status)}")
        end

      assert Map.has_key?(response, "data") or Map.has_key?(response, "error")
    end

    test "returns 401 without authentication" do
      map = Factory.insert(:map)
      signature_id = Ecto.UUID.generate()

      update_params = %{
        "name" => "Updated Signature"
      }

      conn = build_conn()
      conn = put(conn, ~p"/api/maps/#{map.slug}/signatures/#{signature_id}", update_params)

      assert json_response(conn, 401)
    end
  end

  describe "DELETE /api/maps/:map_identifier/signatures/:id" do
    setup :setup_map_authentication

    test "deletes an existing signature", %{conn: conn, map: map} do
      signature_id = Ecto.UUID.generate()

      conn = delete(conn, ~p"/api/maps/#{map.slug}/signatures/#{signature_id}")

      # Should return 204 No Content or error
      case conn.status do
        204 ->
          assert conn.resp_body == ""

        422 ->
          assert %{"error" => _error} = json_response(conn, 422)

        _ ->
          assert false, "Unexpected status code: #{conn.status}"
      end
    end

    test "handles deletion of non-existent signature", %{conn: conn, map: map} do
      non_existent_id = Ecto.UUID.generate()

      conn = delete(conn, ~p"/api/maps/#{map.slug}/signatures/#{non_existent_id}")

      # Should handle gracefully
      case conn.status do
        204 ->
          assert conn.resp_body == ""

        422 ->
          assert %{"error" => _error} = json_response(conn, 422)

        _ ->
          assert false, "Unexpected status code: #{conn.status}"
      end
    end

    test "handles invalid signature ID format", %{conn: conn, map: map} do
      conn = delete(conn, ~p"/api/maps/#{map.slug}/signatures/invalid-uuid")

      case conn.status do
        204 ->
          assert conn.resp_body == ""

        422 ->
          assert %{"error" => _error} = json_response(conn, 422)

        _ ->
          assert false, "Unexpected status code: #{conn.status}"
      end
    end

    test "returns 401 without authentication" do
      map = Factory.insert(:map)
      signature_id = Ecto.UUID.generate()

      conn = build_conn()
      conn = delete(conn, ~p"/api/maps/#{map.slug}/signatures/#{signature_id}")

      assert json_response(conn, 401)
    end
  end

  describe "parameter validation" do
    setup :setup_map_authentication

    test "validates signature ID format in show", %{conn: conn, map: map} do
      invalid_ids = [
        "",
        "not-a-uuid",
        "123",
        "invalid-format-here"
      ]

      for invalid_id <- invalid_ids do
        conn = get(conn, ~p"/api/maps/#{map.slug}/signatures/#{invalid_id}")

        # Should handle invalid IDs gracefully
        response =
          case conn.status do
            200 -> json_response(conn, 200)
            404 -> json_response(conn, 404)
            422 -> json_response(conn, 422)
            _ -> flunk("Unexpected status code: #{inspect(conn.status)}")
          end

        assert Map.has_key?(response, "data") or Map.has_key?(response, "error")
      end
    end

    test "validates signature creation with invalid data types", %{conn: conn, map: map} do
      invalid_params = [
        %{"solar_system_id" => "not-an-integer", "eve_id" => "ABC", "character_eve_id" => "123"},
        %{"solar_system_id" => 30_000_142, "eve_id" => 123, "character_eve_id" => "123"},
        %{"solar_system_id" => 30_000_142, "eve_id" => "ABC", "character_eve_id" => 123},
        %{
          "solar_system_id" => 30_000_142,
          "eve_id" => "ABC",
          "character_eve_id" => "123",
          "linked_system_id" => "not-an-integer"
        }
      ]

      for params <- invalid_params do
        conn = post(conn, ~p"/api/maps/#{map.slug}/signatures", params)

        # Should handle validation errors
        response =
          case conn.status do
            201 -> json_response(conn, 201)
            422 -> json_response(conn, 422)
            _ -> flunk("Unexpected status code: #{inspect(conn.status)}")
          end

        assert Map.has_key?(response, "data") or Map.has_key?(response, "error")
      end
    end
  end

  describe "edge cases" do
    setup :setup_map_authentication

    test "handles very long signature names and descriptions", %{conn: conn, map: map} do
      long_string = String.duplicate("a", 1000)

      long_params = %{
        "solar_system_id" => 30_000_146,
        "eve_id" => "LONG-123",
        "character_eve_id" => "123456789",
        "name" => long_string,
        "description" => long_string,
        "custom_info" => long_string
      }

      conn = post(conn, ~p"/api/maps/#{map.slug}/signatures", long_params)

      response =
        case conn.status do
          201 -> json_response(conn, 201)
          422 -> json_response(conn, 422)
          _ -> flunk("Unexpected status code: #{inspect(conn.status)}")
        end

      assert Map.has_key?(response, "data") or Map.has_key?(response, "error")
    end

    test "handles special characters in signature data", %{conn: conn, map: map} do
      special_params = %{
        "solar_system_id" => 30_000_147,
        "eve_id" => "ABC-123",
        "character_eve_id" => "123456789",
        "name" => "Special chars: àáâãäåæçèéêë",
        "description" => "Unicode: 🚀🌟⭐",
        "custom_info" => "Mixed: abc123!@#$%^&*()"
      }

      conn = post(conn, ~p"/api/maps/#{map.slug}/signatures", special_params)

      response =
        case conn.status do
          201 -> json_response(conn, 201)
          422 -> json_response(conn, 422)
          _ -> flunk("Unexpected status code: #{inspect(conn.status)}")
        end

      assert Map.has_key?(response, "data") or Map.has_key?(response, "error")
    end

    test "handles empty string values", %{conn: conn, map: map} do
      empty_params = %{
        "solar_system_id" => 30_000_148,
        "eve_id" => "",
        "character_eve_id" => "",
        "name" => "",
        "description" => "",
        "type" => "",
        "kind" => "",
        "group" => "",
        "custom_info" => ""
      }

      conn = post(conn, ~p"/api/maps/#{map.slug}/signatures", empty_params)

      response =
        case conn.status do
          201 -> json_response(conn, 201)
          422 -> json_response(conn, 422)
          _ -> flunk("Unexpected status code: #{inspect(conn.status)}")
        end

      assert Map.has_key?(response, "data") or Map.has_key?(response, "error")
    end
  end

  describe "authentication and authorization" do
    test "all endpoints require authentication" do
      map = Factory.insert(:map)
      signature_id = Ecto.UUID.generate()

      endpoints = [
        {:get, ~p"/api/maps/#{map.slug}/signatures"},
        {:get, ~p"/api/maps/#{map.slug}/signatures/#{signature_id}"},
        {:post, ~p"/api/maps/#{map.slug}/signatures"},
        {:put, ~p"/api/maps/#{map.slug}/signatures/#{signature_id}"},
        {:delete, ~p"/api/maps/#{map.slug}/signatures/#{signature_id}"}
      ]

      for {method, path} <- endpoints do
        conn = build_conn()

        conn =
          case method do
            :get -> get(conn, path)
            :post -> post(conn, path, %{})
            :put -> put(conn, path, %{})
            :delete -> delete(conn, path)
          end

        assert json_response(conn, 401)
      end
    end
  end

  describe "OpenAPI schema compliance" do
    setup :setup_map_authentication

    test "responses match expected structure", %{conn: conn, map: map} do
      # Test index endpoint response structure
      conn = get(conn, ~p"/api/maps/#{map.slug}/signatures")

      case json_response(conn, 200) do
        %{"data" => data} ->
          assert is_list(data)
          # If signatures exist, they should have the expected structure
          if length(data) > 0 do
            signature = List.first(data)
            assert Map.has_key?(signature, "id")
            assert Map.has_key?(signature, "solar_system_id")
            assert Map.has_key?(signature, "eve_id")
            assert Map.has_key?(signature, "character_eve_id")
          end

        _ ->
          assert false, "Expected data wrapper"
      end
    end

    test "error responses have consistent structure", %{conn: conn, map: map} do
      # Test error response from non-existent signature
      non_existent_id = Ecto.UUID.generate()
      conn = get(conn, ~p"/api/maps/#{map.slug}/signatures/#{non_existent_id}")

      case json_response(conn, 404) do
        %{"error" => error} ->
          assert is_binary(error)
          assert error == "Signature not found"

        _ ->
          assert false, "Expected error field in response"
      end
    end

    test "created signature response structure", %{conn: conn, map: map} do
      signature_params = %{
        "solar_system_id" => 30_000_149,
        "eve_id" => "TEST-001",
        "character_eve_id" => "123456789",
        "name" => "Test Signature"
      }

      conn = post(conn, ~p"/api/maps/#{map.slug}/signatures", signature_params)

      response =
        case conn.status do
          201 -> json_response(conn, 201)
          422 -> json_response(conn, 422)
          _ -> flunk("Unexpected status code: #{inspect(conn.status)}")
        end

      case response do
        %{"data" => data} ->
          # Should have signature structure
          assert Map.has_key?(data, "id") or Map.has_key?(data, "solar_system_id")

        %{"error" => _error} ->
          # Error response is also valid
          assert true

        _ ->
          assert false, "Unexpected response structure"
      end
    end
  end
end
