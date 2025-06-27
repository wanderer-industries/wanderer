defmodule WandererAppWeb.MapSystemSignatureAPIControllerTest do
  use WandererAppWeb.ApiCase

  alias WandererApp.Factory

  describe "GET /api/maps/:map_identifier/signatures (index)" do
    setup :setup_map_authentication

    test "returns all signatures for a map", %{conn: conn, map: map} do
      # Create test systems
      system1 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})
      system2 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_143})

      # Create test signatures
      sig1 =
        Factory.insert(:map_system_signature, %{
          system_id: system1.id,
          eve_id: "ABC-123",
          character_eve_id: "123456789",
          name: "Wormhole K162",
          type: "Wormhole",
          group: "wormhole"
        })

      sig2 =
        Factory.insert(:map_system_signature, %{
          system_id: system2.id,
          eve_id: "XYZ-456",
          character_eve_id: "987654321",
          name: "Data Site",
          type: "Data Site",
          group: "cosmic_signature"
        })

      conn = get(conn, ~p"/api/maps/#{map.slug}/signatures")

      assert %{"data" => signatures} = json_response(conn, 200)
      assert length(signatures) == 2

      # Verify signature data
      eve_ids = Enum.map(signatures, & &1["eve_id"])
      assert "ABC-123" in eve_ids
      assert "XYZ-456" in eve_ids
    end

    test "returns empty array when no signatures exist", %{conn: conn, map: map} do
      conn = get(conn, ~p"/api/maps/#{map.slug}/signatures")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns 401 without API key", %{map: map} do
      conn = build_conn()
      conn = get(conn, ~p"/api/maps/#{map.slug}/signatures")
      assert json_response(conn, 401)
    end

    test "returns 404 for non-existent map", %{conn: conn} do
      conn = get(conn, ~p"/api/maps/non-existent/signatures")
      assert json_response(conn, 404)
    end
  end

  describe "GET /api/maps/:map_identifier/signatures/:id (show)" do
    setup :setup_map_authentication

    test "returns a specific signature", %{conn: conn, map: map} do
      system = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})

      signature =
        Factory.insert(:map_system_signature, %{
          system_id: system.id,
          eve_id: "ABC-123",
          character_eve_id: "123456789",
          name: "Wormhole K162",
          description: "Leads to unknown space",
          type: "Wormhole",
          linked_system_id: 30_000_144,
          kind: "cosmic_signature",
          group: "wormhole",
          custom_info: "Fresh",
          updated: 1
        })

      conn = get(conn, ~p"/api/maps/#{map.slug}/signatures/#{signature.id}")

      assert %{
               "data" => data
             } = json_response(conn, 200)

      assert data["id"] == signature.id
      assert data["eve_id"] == "ABC-123"
      assert data["name"] == "Wormhole K162"
      assert data["description"] == "Leads to unknown space"
      assert data["type"] == "Wormhole"
      assert data["linked_system_id"] == 30_000_144
      assert data["custom_info"] == "Fresh"
    end

    test "returns 404 for non-existent signature", %{conn: conn, map: map} do
      conn = get(conn, ~p"/api/maps/#{map.slug}/signatures/non-existent-id")
      assert json_response(conn, 404)
    end

    test "returns 404 for signature from different map", %{conn: conn, map: map} do
      # Create another map and system
      other_map = Factory.insert(:map)
      other_system = Factory.insert(:map_system, %{map_id: other_map.id})

      signature =
        Factory.insert(:map_system_signature, %{
          system_id: other_system.id,
          eve_id: "ABC-123"
        })

      conn = get(conn, ~p"/api/maps/#{map.slug}/signatures/#{signature.id}")
      assert json_response(conn, 404)
    end
  end

  describe "POST /api/maps/:map_identifier/signatures (create)" do
    setup :setup_map_authentication

    test "creates a new signature", %{conn: conn, map: map} do
      system = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})

      signature_params = %{
        "system_id" => system.id,
        "eve_id" => "NEW-789",
        "character_eve_id" => "123456789",
        "name" => "New Wormhole",
        "description" => "Recently discovered",
        "type" => "Wormhole",
        "linked_system_id" => 30_000_145,
        "kind" => "cosmic_signature",
        "group" => "wormhole",
        "custom_info" => "Unstable"
      }

      conn = post(conn, ~p"/api/maps/#{map.slug}/signatures", signature_params)

      assert %{
               "data" => data
             } = json_response(conn, 201)

      assert data["eve_id"] == "NEW-789"
      assert data["name"] == "New Wormhole"
      assert data["description"] == "Recently discovered"
      assert data["custom_info"] == "Unstable"
    end

    test "validates required fields", %{conn: conn, map: map} do
      invalid_params = %{
        "name" => "Missing required fields"
      }

      conn = post(conn, ~p"/api/maps/#{map.slug}/signatures", invalid_params)
      assert json_response(conn, 422)
    end

    test "validates system belongs to map", %{conn: conn, map: map} do
      # Create system in different map
      other_map = Factory.insert(:map)
      other_system = Factory.insert(:map_system, %{map_id: other_map.id})

      signature_params = %{
        "system_id" => other_system.id,
        "eve_id" => "NEW-789",
        "character_eve_id" => "123456789"
      }

      conn = post(conn, ~p"/api/maps/#{map.slug}/signatures", signature_params)
      assert json_response(conn, 422)
    end
  end

  describe "PUT /api/maps/:map_identifier/signatures/:id (update)" do
    setup :setup_map_authentication

    test "updates signature attributes", %{conn: conn, map: map} do
      system = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})

      signature =
        Factory.insert(:map_system_signature, %{
          system_id: system.id,
          eve_id: "ABC-123",
          character_eve_id: "123456789",
          name: "Original Name",
          type: "Wormhole",
          custom_info: "Original info"
        })

      update_params = %{
        "name" => "Updated Name",
        "description" => "Updated description",
        "type" => "Data Site",
        "custom_info" => "Updated info",
        "linked_system_id" => 30_000_146
      }

      conn = put(conn, ~p"/api/maps/#{map.slug}/signatures/#{signature.id}", update_params)

      assert %{
               "data" => data
             } = json_response(conn, 200)

      assert data["name"] == "Updated Name"
      assert data["description"] == "Updated description"
      assert data["type"] == "Data Site"
      assert data["custom_info"] == "Updated info"
      assert data["linked_system_id"] == 30_000_146
    end

    test "preserves eve_id on update", %{conn: conn, map: map} do
      system = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})

      signature =
        Factory.insert(:map_system_signature, %{
          system_id: system.id,
          eve_id: "ABC-123",
          character_eve_id: "123456789"
        })

      update_params = %{
        "name" => "Updated Name"
      }

      conn = put(conn, ~p"/api/maps/#{map.slug}/signatures/#{signature.id}", update_params)

      assert %{
               "data" => data
             } = json_response(conn, 200)

      assert data["eve_id"] == "ABC-123"
    end

    test "returns 404 for non-existent signature", %{conn: conn, map: map} do
      update_params = %{
        "name" => "Updated Name"
      }

      conn = put(conn, ~p"/api/maps/#{map.slug}/signatures/non-existent-id", update_params)
      assert json_response(conn, 404)
    end

    test "validates signature belongs to map", %{conn: conn, map: map} do
      # Create signature in different map
      other_map = Factory.insert(:map)
      other_system = Factory.insert(:map_system, %{map_id: other_map.id})

      signature =
        Factory.insert(:map_system_signature, %{
          system_id: other_system.id,
          eve_id: "ABC-123"
        })

      update_params = %{
        "name" => "Should not update"
      }

      conn = put(conn, ~p"/api/maps/#{map.slug}/signatures/#{signature.id}", update_params)
      assert json_response(conn, 422)
    end
  end

  describe "DELETE /api/maps/:map_identifier/signatures/:id (delete)" do
    setup :setup_map_authentication

    test "deletes a signature", %{conn: conn, map: map} do
      system = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})

      signature =
        Factory.insert(:map_system_signature, %{
          system_id: system.id,
          eve_id: "ABC-123",
          character_eve_id: "123456789"
        })

      conn = delete(conn, ~p"/api/maps/#{map.slug}/signatures/#{signature.id}")

      assert response(conn, 204)

      # Verify signature was deleted
      conn2 = get(conn, ~p"/api/maps/#{map.slug}/signatures/#{signature.id}")
      assert json_response(conn2, 404)
    end

    test "returns error for non-existent signature", %{conn: conn, map: map} do
      conn = delete(conn, ~p"/api/maps/#{map.slug}/signatures/non-existent-id")
      assert json_response(conn, 422)
    end

    test "validates signature belongs to map", %{conn: conn, map: map} do
      # Create signature in different map
      other_map = Factory.insert(:map)
      other_system = Factory.insert(:map_system, %{map_id: other_map.id})

      signature =
        Factory.insert(:map_system_signature, %{
          system_id: other_system.id,
          eve_id: "ABC-123"
        })

      conn = delete(conn, ~p"/api/maps/#{map.slug}/signatures/#{signature.id}")
      assert json_response(conn, 422)
    end
  end
end
