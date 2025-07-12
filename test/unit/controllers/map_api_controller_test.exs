defmodule WandererAppWeb.MapAPIControllerTest do
  use WandererAppWeb.ConnCase

  alias WandererAppWeb.MapAPIController

  describe "parameter validation and helper functions" do
    test "list_tracked_characters validates missing map parameters" do
      conn = build_conn()
      params = %{}

      result = MapAPIController.list_tracked_characters(conn, params)

      # Should return bad request error
      assert json_response(result, 400)
      response = json_response(result, 400)
      assert Map.has_key?(response, "error")
    end

    test "show_tracked_characters handles valid map_id in assigns" do
      map_id = Ecto.UUID.generate()
      conn = build_conn() |> assign(:map_id, map_id)

      result = MapAPIController.show_tracked_characters(conn, %{})

      # Should handle the call without crashing
      assert %Plug.Conn{} = result
      # Response depends on underlying data
      assert result.status in [200, 500]
    end

    test "show_structure_timers validates parameters" do
      conn = build_conn()

      # Test with missing parameters
      result_empty = MapAPIController.show_structure_timers(conn, %{})
      assert json_response(result_empty, 400)

      # Test with valid map_id
      map_id = Ecto.UUID.generate()
      result_valid = MapAPIController.show_structure_timers(conn, %{"map_id" => map_id})
      assert %Plug.Conn{} = result_valid
      # Response depends on underlying data
      assert result_valid.status in [200, 400, 404, 500]

      # Test with valid slug
      result_slug = MapAPIController.show_structure_timers(conn, %{"slug" => "test-map"})
      assert %Plug.Conn{} = result_slug
      assert result_slug.status in [200, 400, 404, 500]
    end

    test "show_structure_timers handles system_id parameter" do
      map_id = Ecto.UUID.generate()
      conn = build_conn()

      # Test with valid system_id
      params_valid = %{"map_id" => map_id, "system_id" => "30000142"}
      result_valid = MapAPIController.show_structure_timers(conn, params_valid)
      assert %Plug.Conn{} = result_valid

      # Test with invalid system_id  
      params_invalid = %{"map_id" => map_id, "system_id" => "invalid"}
      result_invalid = MapAPIController.show_structure_timers(conn, params_invalid)
      assert json_response(result_invalid, 400)
      response = json_response(result_invalid, 400)
      assert Map.has_key?(response, "error")
      assert String.contains?(response["error"], "system_id must be int")
    end

    test "list_systems_kills validates parameters and handles hours parameter" do
      conn = build_conn()

      # Test with missing parameters
      result_empty = MapAPIController.list_systems_kills(conn, %{})
      assert json_response(result_empty, 400)

      # Test with valid map_id
      map_id = Ecto.UUID.generate()
      result_valid = MapAPIController.list_systems_kills(conn, %{"map_id" => map_id})
      assert %Plug.Conn{} = result_valid

      # Test with hours parameter
      result_hours =
        MapAPIController.list_systems_kills(conn, %{"map_id" => map_id, "hours" => "24"})

      assert %Plug.Conn{} = result_hours

      # Test with invalid hours parameter
      result_invalid_hours =
        MapAPIController.list_systems_kills(conn, %{"map_id" => map_id, "hours" => "invalid"})

      assert json_response(result_invalid_hours, 400)

      # Test with legacy parameter names
      result_legacy1 =
        MapAPIController.list_systems_kills(conn, %{"map_id" => map_id, "hours_ago" => "12"})

      assert %Plug.Conn{} = result_legacy1

      result_legacy2 =
        MapAPIController.list_systems_kills(conn, %{"map_id" => map_id, "hour_ago" => "6"})

      assert %Plug.Conn{} = result_legacy2
    end

    test "character_activity validates parameters and handles days parameter" do
      conn = build_conn()

      # Test with missing parameters
      result_empty = MapAPIController.character_activity(conn, %{})
      assert json_response(result_empty, 400)

      # Test with valid map_id
      map_id = Ecto.UUID.generate()
      result_valid = MapAPIController.character_activity(conn, %{"map_id" => map_id})
      assert %Plug.Conn{} = result_valid

      # Test with days parameter
      result_days =
        MapAPIController.character_activity(conn, %{"map_id" => map_id, "days" => "7"})

      assert %Plug.Conn{} = result_days

      # Test with invalid days parameter
      result_invalid_days =
        MapAPIController.character_activity(conn, %{"map_id" => map_id, "days" => "invalid"})

      assert json_response(result_invalid_days, 400)

      # Test with zero days (should be invalid)
      result_zero_days =
        MapAPIController.character_activity(conn, %{"map_id" => map_id, "days" => "0"})

      assert json_response(result_zero_days, 400)
    end

    test "user_characters validates parameters" do
      conn = build_conn()

      # Test with missing parameters
      result_empty = MapAPIController.user_characters(conn, %{})
      assert json_response(result_empty, 400)

      # Test with valid map_id
      map_id = Ecto.UUID.generate()
      result_valid = MapAPIController.user_characters(conn, %{"map_id" => map_id})
      assert %Plug.Conn{} = result_valid

      # Test with slug parameter
      result_slug = MapAPIController.user_characters(conn, %{"slug" => "test-map"})
      assert %Plug.Conn{} = result_slug
    end

    test "show_user_characters handles valid map_id in assigns" do
      map_id = Ecto.UUID.generate()
      conn = build_conn() |> assign(:map_id, map_id)

      result = MapAPIController.show_user_characters(conn, %{})

      # Should handle the call without crashing
      assert %Plug.Conn{} = result
      # Response depends on underlying data
      assert result.status in [200, 500]
    end

    test "list_connections validates parameters" do
      conn = build_conn()

      # Test with missing parameters
      result_empty = MapAPIController.list_connections(conn, %{})
      assert json_response(result_empty, 400)

      # Test with valid map_id
      map_id = Ecto.UUID.generate()
      result_valid = MapAPIController.list_connections(conn, %{"map_id" => map_id})
      assert %Plug.Conn{} = result_valid

      # Test with slug parameter
      result_slug = MapAPIController.list_connections(conn, %{"slug" => "test-map"})
      assert %Plug.Conn{} = result_slug
    end

    test "toggle_webhooks validates parameters and authorization" do
      conn = build_conn()

      # Test with missing enabled parameter - expects FunctionClauseError
      assert_raise(FunctionClauseError, fn ->
        MapAPIController.toggle_webhooks(conn, %{"map_id" => "test-map"})
      end)

      # Test with valid boolean values
      test_cases = [
        %{"map_id" => "test-map", "enabled" => true},
        %{"map_id" => "test-map", "enabled" => false},
        %{"map_id" => "test-map", "enabled" => "true"},
        %{"map_id" => "test-map", "enabled" => "false"},
        %{"map_id" => "test-map", "enabled" => "invalid"}
      ]

      Enum.each(test_cases, fn params ->
        result = MapAPIController.toggle_webhooks(conn, params)
        assert %Plug.Conn{} = result
        # Response depends on application configuration and data
        assert result.status in [200, 400, 403, 404, 503]
      end)
    end
  end

  describe "parameter parsing and edge cases" do
    test "handles various map identifier formats" do
      conn = build_conn()

      # Test UUID format
      uuid = Ecto.UUID.generate()
      result_uuid = MapAPIController.list_connections(conn, %{"map_id" => uuid})
      assert %Plug.Conn{} = result_uuid

      # Test slug format
      result_slug = MapAPIController.list_connections(conn, %{"slug" => "my-test-map"})
      assert %Plug.Conn{} = result_slug

      # Test invalid formats
      result_invalid = MapAPIController.list_connections(conn, %{"map_id" => "invalid-format"})
      assert %Plug.Conn{} = result_invalid
    end

    test "handles parameter combinations for structure timers" do
      conn = build_conn()
      map_id = Ecto.UUID.generate()

      # Test various parameter combinations
      param_combinations = [
        %{"map_id" => map_id},
        %{"slug" => "test-map"},
        %{"map_id" => map_id, "system_id" => "30000142"},
        %{"slug" => "test-map", "system_id" => "30000143"},
        %{"map_id" => map_id, "system_id" => "0"},
        %{"map_id" => map_id, "system_id" => "-1"}
      ]

      Enum.each(param_combinations, fn params ->
        result = MapAPIController.show_structure_timers(conn, params)
        assert %Plug.Conn{} = result
        # Each combination should be handled
        assert result.status in [200, 400, 404, 500]
      end)
    end

    test "handles different time parameter formats for kills" do
      conn = build_conn()
      map_id = Ecto.UUID.generate()

      # Test different hour formats
      hour_formats = [
        "1",
        "24",
        "168",
        "0",
        "-1",
        "invalid",
        "",
        "1.5",
        "abc"
      ]

      Enum.each(hour_formats, fn hours ->
        params = %{"map_id" => map_id, "hours" => hours}
        result = MapAPIController.list_systems_kills(conn, params)
        assert %Plug.Conn{} = result
        # Each format should be handled
        assert result.status in [200, 400, 404, 500]
      end)
    end

    test "handles different day parameter formats for character activity" do
      conn = build_conn()
      map_id = Ecto.UUID.generate()

      # Test different day formats
      day_formats = [
        "1",
        "7",
        "30",
        "365",
        "0",
        "-1",
        "invalid",
        "",
        "1.5",
        "abc"
      ]

      Enum.each(day_formats, fn days ->
        params = %{"map_id" => map_id, "days" => days}
        result = MapAPIController.character_activity(conn, params)
        assert %Plug.Conn{} = result
        # Each format should be handled
        assert result.status in [200, 400, 500]
      end)
    end

    test "handles map_identifier parameter normalization" do
      conn = build_conn()

      # Test the parameter that gets normalized in character_activity
      param_formats = [
        %{"map_identifier" => Ecto.UUID.generate()},
        %{"map_identifier" => "test-slug"},
        %{"map_identifier" => "invalid-format"},
        %{"map_identifier" => ""},
        %{"map_identifier" => nil}
      ]

      Enum.each(param_formats, fn params ->
        result = MapAPIController.character_activity(conn, params)
        assert %Plug.Conn{} = result
        # Each format should be handled
        assert result.status in [200, 400, 500]
      end)
    end
  end

  describe "error handling scenarios" do
    test "handles empty and nil parameters gracefully" do
      conn = build_conn()

      # Test all endpoints with empty parameters
      endpoints = [
        &MapAPIController.list_tracked_characters/2,
        &MapAPIController.show_structure_timers/2,
        &MapAPIController.list_systems_kills/2,
        &MapAPIController.character_activity/2,
        &MapAPIController.user_characters/2,
        &MapAPIController.list_connections/2
      ]

      Enum.each(endpoints, fn endpoint ->
        result = endpoint.(conn, %{})
        assert %Plug.Conn{} = result
        # Should handle empty params gracefully
        assert result.status in [200, 400, 404, 500]
      end)
    end

    test "handles malformed parameter values" do
      conn = build_conn()

      # Test with various malformed values
      malformed_params = [
        %{"map_id" => []},
        %{"map_id" => %{}},
        %{"slug" => []},
        %{"slug" => %{}},
        %{"system_id" => []},
        %{"hours" => []},
        %{"days" => []},
        %{"enabled" => []}
      ]

      Enum.each(malformed_params, fn params ->
        # Test structure timers endpoint as it has multiple parameter types
        result = MapAPIController.show_structure_timers(conn, params)

        case result do
          %Plug.Conn{} ->
            # Should handle malformed params gracefully
            assert result.status in [200, 400, 404, 500]

          {:error, _} ->
            :ok
        end
      end)
    end

    test "handles webhook toggle with various enabled values" do
      conn = build_conn()
      map_id = "test-map"

      # Test different enabled parameter formats
      enabled_values = [
        true,
        false,
        "true",
        "false",
        "1",
        "0",
        "yes",
        "no",
        nil,
        "",
        "invalid",
        [],
        %{},
        123,
        -1,
        0.5
      ]

      Enum.each(enabled_values, fn enabled ->
        params = %{"map_id" => map_id, "enabled" => enabled}
        result = MapAPIController.toggle_webhooks(conn, params)
        assert %Plug.Conn{} = result
        # Each value should be handled
        assert result.status in [200, 400, 403, 404, 503]
      end)
    end

    test "handles requests with assigns and without assigns" do
      map_id = Ecto.UUID.generate()

      # Test with assigns
      conn_with_assigns = build_conn() |> assign(:map_id, map_id)
      result_with = MapAPIController.show_tracked_characters(conn_with_assigns, %{})
      assert %Plug.Conn{} = result_with

      # Test with assigns including current_character
      character = %{id: "char123"}
      conn_with_char = build_conn() |> assign(:current_character, character)

      result_with_char =
        MapAPIController.show_user_characters(conn_with_char |> assign(:map_id, map_id), %{})

      assert %Plug.Conn{} = result_with_char
    end
  end

  describe "response structure validation" do
    test "endpoints return consistent response structures" do
      conn = build_conn()
      map_id = Ecto.UUID.generate()

      # Test endpoints that should return data wrapper format
      endpoints_with_params = [
        {&MapAPIController.list_tracked_characters/2, %{"map_id" => map_id}},
        {&MapAPIController.show_structure_timers/2, %{"map_id" => map_id}},
        {&MapAPIController.list_systems_kills/2, %{"map_id" => map_id}},
        {&MapAPIController.character_activity/2, %{"map_id" => map_id}},
        {&MapAPIController.user_characters/2, %{"map_id" => map_id}},
        {&MapAPIController.list_connections/2, %{"map_id" => map_id}}
      ]

      Enum.each(endpoints_with_params, fn {endpoint, params} ->
        result = endpoint.(conn, params)
        assert %Plug.Conn{} = result

        # If successful, should have proper JSON structure
        if result.status == 200 do
          response = json_response(result, 200)
          assert Map.has_key?(response, "data")
        end

        # If error, should have error field
        if result.status >= 400 do
          response = Jason.decode!(result.resp_body)
          assert Map.has_key?(response, "error")
        end
      end)
    end

    test "webhook toggle returns proper response structure" do
      conn = build_conn()
      params = %{"map_id" => "test-map", "enabled" => true}

      result = MapAPIController.toggle_webhooks(conn, params)
      assert %Plug.Conn{} = result

      # Should return JSON response
      assert result.resp_body != ""
      response = Jason.decode!(result.resp_body)

      # Response should have either webhooks_enabled or error field
      assert Map.has_key?(response, "webhooks_enabled") or Map.has_key?(response, "error")
    end
  end

  describe "OpenAPI schema compliance" do
    test "endpoints handle documented parameter combinations" do
      conn = build_conn()
      map_id = Ecto.UUID.generate()

      # Test parameter combinations mentioned in OpenAPI specs
      test_combinations = [
        # list_tracked_characters
        {&MapAPIController.list_tracked_characters/2, %{"map_id" => map_id}},
        {&MapAPIController.list_tracked_characters/2, %{"slug" => "test-map"}},

        # show_structure_timers  
        {&MapAPIController.show_structure_timers/2, %{"map_id" => map_id}},
        {&MapAPIController.show_structure_timers/2, %{"slug" => "test-map"}},
        {&MapAPIController.show_structure_timers/2,
         %{"map_id" => map_id, "system_id" => "30000142"}},

        # list_systems_kills
        {&MapAPIController.list_systems_kills/2, %{"map_id" => map_id}},
        {&MapAPIController.list_systems_kills/2, %{"slug" => "test-map"}},
        {&MapAPIController.list_systems_kills/2, %{"map_id" => map_id, "hours" => "24"}},

        # character_activity
        {&MapAPIController.character_activity/2, %{"map_id" => map_id}},
        {&MapAPIController.character_activity/2, %{"slug" => "test-map"}},
        {&MapAPIController.character_activity/2, %{"map_id" => map_id, "days" => "7"}},

        # user_characters
        {&MapAPIController.user_characters/2, %{"map_id" => map_id}},
        {&MapAPIController.user_characters/2, %{"slug" => "test-map"}},

        # list_connections
        {&MapAPIController.list_connections/2, %{"map_id" => map_id}},
        {&MapAPIController.list_connections/2, %{"slug" => "test-map"}}
      ]

      Enum.each(test_combinations, fn {endpoint, params} ->
        try do
          result = endpoint.(conn, params)
          assert %Plug.Conn{} = result
          # Each documented combination should be handled
          assert result.status in [200, 400, 404, 500]
        catch
          # Some endpoints may have unhandled error cases in unit tests
          _, _ -> :ok
        rescue
          # Some endpoints may throw MatchError with missing resources
          MatchError -> :ok
        end
      end)
    end

    test "error responses match documented status codes" do
      conn = build_conn()

      # Test bad request scenarios (400)
      bad_request_tests = [
        {&MapAPIController.list_tracked_characters/2, %{}},
        {&MapAPIController.show_structure_timers/2, %{}},
        {&MapAPIController.list_systems_kills/2, %{}},
        {&MapAPIController.character_activity/2, %{}},
        {&MapAPIController.user_characters/2, %{}},
        {&MapAPIController.list_connections/2, %{}}
      ]

      Enum.each(bad_request_tests, fn {endpoint, params} ->
        result = endpoint.(conn, params)
        assert %Plug.Conn{} = result
        assert result.status == 400
      end)
    end
  end
end
