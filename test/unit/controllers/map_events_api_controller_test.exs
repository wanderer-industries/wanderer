defmodule WandererAppWeb.MapEventsAPIControllerTest do
  use WandererAppWeb.ConnCase, async: true

  alias WandererAppWeb.MapEventsAPIController

  describe "list_events/2 parameter handling" do
    test "handles valid map_identifier but missing map in assigns" do
      conn = build_conn()
      params = %{"map_identifier" => "test-map-id"}

      result = MapEventsAPIController.list_events(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 404

      # Parse the response to verify error message
      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "Map not found"} = response_body
    end

    test "handles invalid since parameter" do
      map = %{id: Ecto.UUID.generate(), name: "Test Map"}
      conn = build_conn() |> assign(:map, map)

      params = %{
        "map_identifier" => "test-map-id",
        "since" => "invalid-datetime"
      }

      result = MapEventsAPIController.list_events(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "Invalid 'since' parameter. Must be ISO8601 datetime."} = response_body
    end

    test "handles invalid limit parameter" do
      map = %{id: Ecto.UUID.generate(), name: "Test Map"}
      conn = build_conn() |> assign(:map, map)

      params = %{
        "map_identifier" => "test-map-id",
        "limit" => "150"
      }

      result = MapEventsAPIController.list_events(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "Invalid 'limit' parameter. Must be between 1 and 100."} = response_body
    end

    test "returns empty events when MapEventRelay is not running" do
      map = %{id: Ecto.UUID.generate(), name: "Test Map"}
      conn = build_conn() |> assign(:map, map)

      params = %{"map_identifier" => "test-map-id"}

      result = MapEventsAPIController.list_events(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 200

      response_body = result.resp_body |> Jason.decode!()
      assert %{"data" => []} = response_body
    end

    test "handles valid since parameter" do
      map = %{id: Ecto.UUID.generate(), name: "Test Map"}
      conn = build_conn() |> assign(:map, map)

      params = %{
        "map_identifier" => "test-map-id",
        "since" => "2025-01-20T12:30:00Z"
      }

      result = MapEventsAPIController.list_events(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 200

      response_body = result.resp_body |> Jason.decode!()
      assert %{"data" => []} = response_body
    end

    test "handles valid limit parameter" do
      map = %{id: Ecto.UUID.generate(), name: "Test Map"}
      conn = build_conn() |> assign(:map, map)

      params = %{
        "map_identifier" => "test-map-id",
        "limit" => "50"
      }

      result = MapEventsAPIController.list_events(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 200

      response_body = result.resp_body |> Jason.decode!()
      assert %{"data" => []} = response_body
    end
  end

  describe "edge cases and error handling" do
    test "validates boundary values for limit parameter" do
      map = %{id: Ecto.UUID.generate(), name: "Test Map"}
      conn = build_conn() |> assign(:map, map)

      # Test exactly at boundaries
      boundary_tests = [
        # Just below minimum
        {"0", 400},
        # Minimum valid
        {"1", 200},
        # Maximum valid  
        {"100", 200},
        # Just above maximum
        {"101", 400}
      ]

      for {limit_value, expected_status} <- boundary_tests do
        params = %{
          "map_identifier" => "test-map-id",
          "limit" => limit_value
        }

        result = MapEventsAPIController.list_events(conn, params)

        assert %Plug.Conn{} = result
        assert result.status == expected_status
      end
    end

    test "handles multiple parameter combinations" do
      map = %{id: Ecto.UUID.generate(), name: "Test Map"}
      conn = build_conn() |> assign(:map, map)

      # Valid combination
      params = %{
        "map_identifier" => "test-map-id",
        "since" => "2025-01-20T12:30:00Z",
        "limit" => "25"
      }

      result = MapEventsAPIController.list_events(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 200

      response_body = result.resp_body |> Jason.decode!()
      assert %{"data" => []} = response_body
    end

    test "validates parameter types" do
      map = %{id: Ecto.UUID.generate(), name: "Test Map"}
      conn = build_conn() |> assign(:map, map)

      # Test with different invalid parameter formats
      invalid_params_list = [
        %{"map_identifier" => "test-map-id", "since" => "", "limit" => "50"},
        %{"map_identifier" => "test-map-id", "since" => "2025-01-20T12:30:00Z", "limit" => "abc"},
        %{"map_identifier" => "test-map-id", "since" => "not-a-date", "limit" => "50"}
      ]

      for params <- invalid_params_list do
        result = MapEventsAPIController.list_events(conn, params)

        assert %Plug.Conn{} = result
        assert result.status == 400
      end
    end
  end
end
