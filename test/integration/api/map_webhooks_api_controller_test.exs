defmodule WandererAppWeb.MapWebhooksAPIControllerIntegrationTest do
  use WandererAppWeb.ApiCase, async: false

  import Mox

  alias WandererApp.Api.MapWebhookSubscription

  describe "GET /api/maps/:map_identifier/webhooks" do
    setup :setup_map_authentication

    test "returns empty list when no webhooks exist", %{conn: conn, map: map} do
      response =
        conn
        |> get("/api/maps/#{map.id}/webhooks")
        |> assert_json_response(200)

      assert %{"data" => []} = response
    end

    test "returns list of webhooks for the map", %{conn: conn, map: map} do
      # Create test webhooks
      {:ok, webhook1} =
        WandererApp.Api.create(MapWebhookSubscription, %{
          map_id: map.id,
          url: "https://example.com/webhook1",
          events: ["add_system", "map_kill"],
          active?: true
        })

      {:ok, webhook2} =
        WandererApp.Api.create(MapWebhookSubscription, %{
          map_id: map.id,
          url: "https://example.com/webhook2",
          events: ["*"],
          active?: false
        })

      response =
        conn
        |> get("/api/maps/#{map.id}/webhooks")
        |> assert_json_response(200)

      assert %{"data" => webhooks} = response
      assert length(webhooks) == 2

      # Find our webhooks in the response
      webhook1_data = Enum.find(webhooks, &(&1["id"] == webhook1.id))
      webhook2_data = Enum.find(webhooks, &(&1["id"] == webhook2.id))

      assert webhook1_data
      assert webhook2_data

      # Verify structure and data
      assert webhook1_data["url"] == "https://example.com/webhook1"
      assert webhook1_data["events"] == ["add_system", "map_kill"]
      assert webhook1_data["active"] == true

      assert webhook2_data["url"] == "https://example.com/webhook2"
      assert webhook2_data["events"] == ["*"]
      assert webhook2_data["active"] == false

      # Verify required fields are present
      for webhook_data <- [webhook1_data, webhook2_data] do
        required_fields = [
          "id",
          "map_id",
          "url",
          "events",
          "active",
          "consecutive_failures",
          "inserted_at",
          "updated_at"
        ]

        for field <- required_fields do
          assert Map.has_key?(webhook_data, field), "Missing required field: #{field}"
        end

        # Optional fields should be present but may be null
        optional_fields = ["last_delivery_at", "last_error"]

        for field <- optional_fields do
          assert Map.has_key?(webhook_data, field), "Missing optional field: #{field}"
        end
      end
    end

    test "works with map slug instead of UUID", %{conn: conn, map: map} do
      response =
        conn
        |> get("/api/maps/#{map.slug}/webhooks")
        |> assert_json_response(200)

      assert %{"data" => webhooks} = response
      assert is_list(webhooks)
    end
  end

  describe "GET /api/maps/:map_identifier/webhooks/:id" do
    setup :setup_map_authentication

    test "returns webhook details", %{conn: conn, map: map} do
      {:ok, webhook} =
        WandererApp.Api.create(MapWebhookSubscription, %{
          map_id: map.id,
          url: "https://example.com/webhook",
          events: ["add_system"],
          active?: true
        })

      response =
        conn
        |> get("/api/maps/#{map.id}/webhooks/#{webhook.id}")
        |> assert_json_response(200)

      assert %{"data" => webhook_data} = response
      assert webhook_data["id"] == webhook.id
      assert webhook_data["url"] == "https://example.com/webhook"
      assert webhook_data["events"] == ["add_system"]
      assert webhook_data["active"] == true
    end

    test "returns 404 for non-existent webhook", %{conn: conn, map: map} do
      non_existent_webhook_id = Ecto.UUID.generate()

      response =
        conn
        |> get("/api/maps/#{map.id}/webhooks/#{non_existent_webhook_id}")
        |> assert_json_response(404)

      assert %{"error" => "Webhook not found"} = response
    end

    test "returns 404 for webhook from different map", %{conn: conn, map: map} do
      # Create webhook for a different map
      other_map = insert(:map)

      {:ok, webhook} =
        WandererApp.Api.create(MapWebhookSubscription, %{
          map_id: other_map.id,
          url: "https://example.com/webhook",
          events: ["add_system"],
          active?: true
        })

      response =
        conn
        |> get("/api/maps/#{map.id}/webhooks/#{webhook.id}")
        |> assert_json_response(404)

      assert %{"error" => "Webhook not found"} = response
    end
  end

  describe "POST /api/maps/:map_identifier/webhooks" do
    setup :setup_map_authentication

    test "creates webhook with valid data", %{conn: conn, map: map} do
      webhook_data = %{
        url: "https://example.com/webhook",
        events: ["add_system", "map_kill"],
        active: true
      }

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/maps/#{map.id}/webhooks", webhook_data)
        |> assert_json_response(201)

      assert %{"data" => webhook} = response
      assert webhook["url"] == "https://example.com/webhook"
      assert webhook["events"] == ["add_system", "map_kill"]
      assert webhook["active"] == true
      assert webhook["map_id"] == map.id
      assert is_binary(webhook["id"])
    end

    test "creates webhook with wildcard events", %{conn: conn, map: map} do
      webhook_data = %{
        url: "https://example.com/webhook",
        events: ["*"]
      }

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/maps/#{map.id}/webhooks", webhook_data)
        |> assert_json_response(201)

      assert %{"data" => webhook} = response
      assert webhook["events"] == ["*"]
      # Default value
      assert webhook["active"] == true
    end

    test "returns error for missing required fields", %{conn: conn, map: map} do
      # Missing url
      webhook_data = %{events: ["add_system"]}

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/maps/#{map.id}/webhooks", webhook_data)
        |> assert_json_response(400)

      assert %{"error" => "Invalid webhook parameters"} = response

      # Missing events
      webhook_data = %{url: "https://example.com/webhook"}

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/maps/#{map.id}/webhooks", webhook_data)
        |> assert_json_response(400)

      assert %{"error" => "Invalid webhook parameters"} = response
    end

    test "returns error for invalid URL format", %{conn: conn, map: map} do
      webhook_data = %{
        # HTTP not HTTPS
        url: "http://example.com/webhook",
        events: ["add_system"]
      }

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/maps/#{map.id}/webhooks", webhook_data)
        |> assert_json_response(400)

      assert %{"error" => "Validation failed"} = response
    end

    test "returns error for invalid events", %{conn: conn, map: map} do
      webhook_data = %{
        url: "https://example.com/webhook",
        events: ["invalid_event"]
      }

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/maps/#{map.id}/webhooks", webhook_data)
        |> assert_json_response(400)

      assert %{"error" => "Validation failed"} = response
    end

    test "prevents duplicate URLs for the same map", %{conn: conn, map: map} do
      webhook_url = "https://example.com/webhook"

      # Create first webhook
      {:ok, _webhook} =
        WandererApp.Api.create(MapWebhookSubscription, %{
          map_id: map.id,
          url: webhook_url,
          events: ["add_system"],
          active?: true
        })

      # Try to create duplicate
      webhook_data = %{
        url: webhook_url,
        events: ["map_kill"]
      }

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/maps/#{map.id}/webhooks", webhook_data)
        |> assert_json_response(400)

      assert %{"error" => "Validation failed"} = response
    end
  end

  describe "PATCH /api/maps/:map_identifier/webhooks/:id" do
    setup :setup_map_authentication

    test "updates webhook successfully", %{conn: conn, map: map} do
      {:ok, webhook} =
        WandererApp.Api.create(MapWebhookSubscription, %{
          map_id: map.id,
          url: "https://example.com/webhook",
          events: ["add_system"],
          active?: true
        })

      update_data = %{
        events: ["*"],
        active: false
      }

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> patch("/api/maps/#{map.id}/webhooks/#{webhook.id}", update_data)
        |> assert_json_response(200)

      assert %{"data" => updated_webhook} = response
      assert updated_webhook["events"] == ["*"]
      assert updated_webhook["active"] == false
      # Unchanged
      assert updated_webhook["url"] == "https://example.com/webhook"
    end

    test "allows partial updates", %{conn: conn, map: map} do
      {:ok, webhook} =
        WandererApp.Api.create(MapWebhookSubscription, %{
          map_id: map.id,
          url: "https://example.com/webhook",
          events: ["add_system"],
          active?: true
        })

      # Only update active status
      update_data = %{active: false}

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> patch("/api/maps/#{map.id}/webhooks/#{webhook.id}", update_data)
        |> assert_json_response(200)

      assert %{"data" => updated_webhook} = response
      assert updated_webhook["active"] == false
      # Unchanged
      assert updated_webhook["events"] == ["add_system"]
      # Unchanged
      assert updated_webhook["url"] == "https://example.com/webhook"
    end

    test "returns 404 for non-existent webhook", %{conn: conn, map: map} do
      non_existent_webhook_id = Ecto.UUID.generate()
      update_data = %{active: false}

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> patch("/api/maps/#{map.id}/webhooks/#{non_existent_webhook_id}", update_data)
        |> assert_json_response(404)

      assert %{"error" => "Webhook not found"} = response
    end
  end

  describe "DELETE /api/maps/:map_identifier/webhooks/:id" do
    setup :setup_map_authentication

    test "deletes webhook successfully", %{conn: conn, map: map} do
      {:ok, webhook} =
        WandererApp.Api.create(MapWebhookSubscription, %{
          map_id: map.id,
          url: "https://example.com/webhook",
          events: ["add_system"],
          active?: true
        })

      conn
      |> delete("/api/maps/#{map.id}/webhooks/#{webhook.id}")
      |> response(204)

      # Verify webhook is deleted
      assert MapWebhookSubscription.by_id(webhook.id) == nil
    end

    test "returns 404 for non-existent webhook", %{conn: conn, map: map} do
      non_existent_webhook_id = Ecto.UUID.generate()

      response =
        conn
        |> delete("/api/maps/#{map.id}/webhooks/#{non_existent_webhook_id}")
        |> assert_json_response(404)

      assert %{"error" => "Webhook not found"} = response
    end
  end

  describe "POST /api/maps/:map_identifier/webhooks/:id/rotate-secret" do
    setup :setup_map_authentication

    test "rotates webhook secret successfully", %{conn: conn, map: map} do
      {:ok, webhook} =
        WandererApp.Api.create(MapWebhookSubscription, %{
          map_id: map.id,
          url: "https://example.com/webhook",
          events: ["add_system"],
          active?: true
        })

      original_secret = webhook.secret

      response =
        conn
        |> post("/api/maps/#{map.id}/webhooks/#{webhook.id}/rotate-secret")
        |> assert_json_response(200)

      assert %{"data" => %{"secret" => new_secret}} = response
      assert is_binary(new_secret)
      assert new_secret != original_secret

      # Verify the webhook was updated
      updated_webhook = MapWebhookSubscription.by_id(webhook.id)
      assert updated_webhook.secret != original_secret
    end

    test "returns 404 for non-existent webhook", %{conn: conn, map: map} do
      non_existent_webhook_id = Ecto.UUID.generate()

      response =
        conn
        |> post("/api/maps/#{map.id}/webhooks/#{non_existent_webhook_id}/rotate-secret")
        |> assert_json_response(404)

      assert %{"error" => "Webhook not found"} = response
    end
  end

  describe "authentication and authorization" do
    test "returns 401 for missing API key" do
      map = insert(:map)

      response =
        build_conn()
        |> get("/api/maps/#{map.id}/webhooks")
        |> assert_json_response(401)

      assert %{"error" => _} = response
    end

    test "returns authentication error for non-existent map with invalid API key" do
      non_existent_map_id = Ecto.UUID.generate()

      response =
        build_conn()
        |> get("/api/maps/#{non_existent_map_id}/webhooks")
        |> assert_json_response(401)

      assert %{"error" => _} = response
    end

    setup :setup_map_authentication

    test "websocket events are enabled in test environment", %{conn: conn, map: map} do
      # This endpoint requires the :api_websocket_events pipeline
      # which includes the CheckWebsocketDisabled plug
      # In test env, websocket events should be enabled

      response =
        conn
        |> get("/api/maps/#{map.id}/webhooks")
        |> assert_json_response(200)

      assert %{"data" => webhooks} = response
      assert is_list(webhooks)
    end
  end

  describe "webhook configuration edge cases" do
    setup :setup_map_authentication

    test "handles long URL within limits", %{conn: conn, map: map} do
      # Create URL close to 2000 character limit
      base_url = "https://example.com/webhook/"
      long_path = String.duplicate("a", 1950 - byte_size(base_url))
      long_url = base_url <> long_path

      webhook_data = %{
        url: long_url,
        events: ["add_system"]
      }

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/maps/#{map.id}/webhooks", webhook_data)
        |> assert_json_response(201)

      assert %{"data" => webhook} = response
      assert webhook["url"] == long_url
    end

    test "rejects empty events array", %{conn: conn, map: map} do
      webhook_data = %{
        url: "https://example.com/webhook",
        events: []
      }

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/maps/#{map.id}/webhooks", webhook_data)
        |> assert_json_response(400)

      assert %{"error" => "Validation failed"} = response
    end

    test "handles large events array within limits", %{conn: conn, map: map} do
      # Create events array with valid but many events
      events = ["add_system", "map_kill", "*"]

      webhook_data = %{
        url: "https://example.com/webhook",
        events: events
      }

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/maps/#{map.id}/webhooks", webhook_data)
        |> assert_json_response(201)

      assert %{"data" => webhook} = response
      assert Enum.sort(webhook["events"]) == Enum.sort(events)
    end
  end
end
