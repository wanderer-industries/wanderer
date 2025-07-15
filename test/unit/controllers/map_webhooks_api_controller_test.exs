defmodule WandererAppWeb.MapWebhooksAPIControllerTest do
  use WandererAppWeb.ConnCase, async: true

  alias WandererAppWeb.MapWebhooksAPIController

  describe "index/2 parameter handling" do
    test "handles missing map in assigns" do
      conn = build_conn()
      params = %{"map_identifier" => "test-map-id"}

      result = MapWebhooksAPIController.index(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 404

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "Map not found"} = response_body
    end

    test "handles map with invalid structure for Ash query" do
      map = %{id: Ecto.UUID.generate(), name: "Test Map"}
      conn = build_conn() |> assign(:map, map)

      params = %{"map_identifier" => "test-map-id"}

      # This test validates that the controller properly handles cases where
      # the map structure doesn't work with Ash queries (unit test limitation)
      # Updated: The controller now handles errors gracefully without raising
      result = MapWebhooksAPIController.index(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 200
      response_body = result.resp_body |> Jason.decode!()
      assert %{"data" => []} = response_body
    end
  end

  describe "show/2 parameter handling" do
    test "handles missing map in assigns" do
      conn = build_conn()
      params = %{"map_identifier" => "test-map-id", "id" => Ecto.UUID.generate()}

      result = MapWebhooksAPIController.show(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 404

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "Map not found"} = response_body
    end

    test "handles non-existent webhook" do
      map = %{id: Ecto.UUID.generate(), name: "Test Map"}
      conn = build_conn() |> assign(:map, map)

      params = %{"map_identifier" => "test-map-id", "id" => Ecto.UUID.generate()}

      result = MapWebhooksAPIController.show(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 404

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "Webhook not found"} = response_body
    end
  end

  describe "create/2 validation" do
    test "handles missing map in assigns" do
      conn = build_conn()

      params = %{
        "map_identifier" => "test-map-id",
        "url" => "https://example.com/webhook",
        "events" => ["add_system"]
      }

      result = MapWebhooksAPIController.create(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 404

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "Map not found"} = response_body
    end

    test "validates required parameters - missing url" do
      map = %{id: Ecto.UUID.generate(), name: "Test Map"}
      conn = build_conn() |> assign(:map, map)

      params = %{
        "map_identifier" => "test-map-id",
        "events" => ["add_system"]
      }

      result = MapWebhooksAPIController.create(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "Invalid webhook parameters"} = response_body
    end

    test "validates required parameters - missing events" do
      map = %{id: Ecto.UUID.generate(), name: "Test Map"}
      conn = build_conn() |> assign(:map, map)

      params = %{
        "map_identifier" => "test-map-id",
        "url" => "https://example.com/webhook"
      }

      result = MapWebhooksAPIController.create(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "Invalid webhook parameters"} = response_body
    end

    test "validates required parameters - both missing" do
      map = %{id: Ecto.UUID.generate(), name: "Test Map"}
      conn = build_conn() |> assign(:map, map)

      params = %{"map_identifier" => "test-map-id"}

      result = MapWebhooksAPIController.create(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "Invalid webhook parameters"} = response_body
    end

    test "accepts valid parameters" do
      map = %{id: Ecto.UUID.generate(), name: "Test Map"}
      conn = build_conn() |> assign(:map, map)

      params = %{
        "map_identifier" => "test-map-id",
        "url" => "https://example.com/webhook",
        "events" => ["add_system"]
      }

      result = MapWebhooksAPIController.create(conn, params)

      # This will fail with validation error since we're not actually creating in DB
      # but the parameter validation should pass
      assert %Plug.Conn{} = result
      # We expect either 400 (validation) or 500 (creation failure) but not parameter error
      assert result.status in [400, 500]

      response_body = result.resp_body |> Jason.decode!()
      # Should not be parameter validation error
      refute response_body["error"] == "Invalid webhook parameters"
    end

    test "handles default active parameter" do
      map = %{id: Ecto.UUID.generate(), name: "Test Map"}
      conn = build_conn() |> assign(:map, map)

      params = %{
        "map_identifier" => "test-map-id",
        "url" => "https://example.com/webhook",
        "events" => ["add_system"]
        # active not specified, should default to true
      }

      result = MapWebhooksAPIController.create(conn, params)

      assert %Plug.Conn{} = result
      # Parameter validation should pass even without explicit active field
      assert result.status in [400, 500]

      response_body = result.resp_body |> Jason.decode!()
      refute response_body["error"] == "Invalid webhook parameters"
    end

    test "accepts explicit active parameter" do
      map = %{id: Ecto.UUID.generate(), name: "Test Map"}
      conn = build_conn() |> assign(:map, map)

      params = %{
        "map_identifier" => "test-map-id",
        "url" => "https://example.com/webhook",
        "events" => ["add_system"],
        "active" => false
      }

      result = MapWebhooksAPIController.create(conn, params)

      assert %Plug.Conn{} = result
      assert result.status in [400, 500]

      response_body = result.resp_body |> Jason.decode!()
      refute response_body["error"] == "Invalid webhook parameters"
    end
  end

  describe "update/2 validation" do
    test "handles missing map in assigns" do
      conn = build_conn()

      params = %{
        "map_identifier" => "test-map-id",
        "id" => Ecto.UUID.generate(),
        "active" => false
      }

      result = MapWebhooksAPIController.update(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 404

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "Map not found"} = response_body
    end

    test "handles non-existent webhook" do
      map = %{id: Ecto.UUID.generate(), name: "Test Map"}
      conn = build_conn() |> assign(:map, map)

      params = %{
        "map_identifier" => "test-map-id",
        "id" => Ecto.UUID.generate(),
        "active" => false
      }

      result = MapWebhooksAPIController.update(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 404

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "Webhook not found"} = response_body
    end

    test "accepts empty update parameters" do
      map = %{id: Ecto.UUID.generate(), name: "Test Map"}
      conn = build_conn() |> assign(:map, map)

      params = %{
        "map_identifier" => "test-map-id",
        "id" => Ecto.UUID.generate()
      }

      result = MapWebhooksAPIController.update(conn, params)

      assert %Plug.Conn{} = result
      # Should reach webhook lookup, not parameter validation error
      assert result.status == 404

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "Webhook not found"} = response_body
    end

    test "accepts partial update parameters" do
      map = %{id: Ecto.UUID.generate(), name: "Test Map"}
      conn = build_conn() |> assign(:map, map)

      # Test individual update fields
      param_sets = [
        %{"active" => false},
        %{"url" => "https://newurl.com/webhook"},
        %{"events" => ["*"]},
        %{"active" => true, "events" => ["add_system"]},
        %{"url" => "https://other.com/hook", "active" => false}
      ]

      for update_params <- param_sets do
        params =
          Map.merge(
            %{
              "map_identifier" => "test-map-id",
              "id" => Ecto.UUID.generate()
            },
            update_params
          )

        result = MapWebhooksAPIController.update(conn, params)

        assert %Plug.Conn{} = result
        # Should reach webhook lookup, not parameter validation error
        assert result.status == 404

        response_body = result.resp_body |> Jason.decode!()
        assert %{"error" => "Webhook not found"} = response_body
      end
    end
  end

  describe "delete/2 parameter handling" do
    test "handles missing map in assigns" do
      conn = build_conn()

      params = %{
        "map_identifier" => "test-map-id",
        "id" => Ecto.UUID.generate()
      }

      result = MapWebhooksAPIController.delete(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 404

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "Map not found"} = response_body
    end

    test "handles non-existent webhook" do
      map = %{id: Ecto.UUID.generate(), name: "Test Map"}
      conn = build_conn() |> assign(:map, map)

      params = %{
        "map_identifier" => "test-map-id",
        "id" => Ecto.UUID.generate()
      }

      result = MapWebhooksAPIController.delete(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 404

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "Webhook not found"} = response_body
    end
  end

  describe "rotate_secret/2 parameter handling" do
    test "handles missing map in assigns" do
      conn = build_conn()

      params = %{
        "map_identifier" => "test-map-id",
        "map_webhooks_api_id" => Ecto.UUID.generate()
      }

      result = MapWebhooksAPIController.rotate_secret(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 404

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "Map not found"} = response_body
    end

    test "handles non-existent webhook" do
      map = %{id: Ecto.UUID.generate(), name: "Test Map"}
      conn = build_conn() |> assign(:map, map)

      params = %{
        "map_identifier" => "test-map-id",
        "map_webhooks_api_id" => Ecto.UUID.generate()
      }

      result = MapWebhooksAPIController.rotate_secret(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 404

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "Webhook not found"} = response_body
    end
  end

  describe "edge cases and error handling" do
    test "handles malformed webhook IDs" do
      map = %{id: Ecto.UUID.generate(), name: "Test Map"}
      conn = build_conn() |> assign(:map, map)

      # Test with invalid UUID format
      params = %{
        "map_identifier" => "test-map-id",
        "id" => "not-a-uuid"
      }

      result = MapWebhooksAPIController.show(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 404

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "Webhook not found"} = response_body
    end

    test "handles various invalid parameter formats" do
      map = %{id: Ecto.UUID.generate(), name: "Test Map"}
      conn = build_conn() |> assign(:map, map)

      # Test create with various invalid parameters
      invalid_param_sets = [
        %{"url" => nil, "events" => ["add_system"]},
        %{"url" => "", "events" => ["add_system"]},
        %{"url" => "https://example.com", "events" => nil},
        %{"url" => "https://example.com", "events" => "not_array"},
        %{"url" => 123, "events" => ["add_system"]},
        %{"url" => "https://example.com", "events" => []}
      ]

      for invalid_params <- invalid_param_sets do
        params =
          Map.merge(
            %{"map_identifier" => "test-map-id"},
            invalid_params
          )

        result = MapWebhooksAPIController.create(conn, params)

        assert %Plug.Conn{} = result
        # Should fail at parameter validation or later validation
        assert result.status in [400, 500]
      end
    end

    test "handles parameter extraction correctly" do
      map = %{id: Ecto.UUID.generate(), name: "Test Map"}
      conn = build_conn() |> assign(:map, map)

      # Test that extra parameters are ignored
      params = %{
        "map_identifier" => "test-map-id",
        "url" => "https://example.com/webhook",
        "events" => ["add_system"],
        "extra_param" => "should_be_ignored",
        "another_extra" => 42
      }

      result = MapWebhooksAPIController.create(conn, params)

      assert %Plug.Conn{} = result
      # Parameter validation should pass despite extra params
      assert result.status in [400, 500]

      response_body = result.resp_body |> Jason.decode!()
      refute response_body["error"] == "Invalid webhook parameters"
    end
  end
end
