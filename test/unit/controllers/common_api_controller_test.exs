defmodule WandererAppWeb.CommonAPIControllerUnitTest do
  use WandererAppWeb.ConnCase, async: true

  alias WandererAppWeb.CommonAPIController

  describe "show_system_static/2 parameter validation" do
    test "handles missing id parameter" do
      conn = build_conn()
      params = %{}

      result = CommonAPIController.show_system_static(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => error_msg} = response_body
      assert is_binary(error_msg)
      assert String.contains?(error_msg, "id")
    end

    test "handles valid solar system id" do
      conn = build_conn()
      params = %{"id" => "30000142"}

      result = CommonAPIController.show_system_static(conn, params)

      assert %Plug.Conn{} = result
      # Should return 200 with data or 404 if system not found
      assert result.status in [200, 404]

      response_body = result.resp_body |> Jason.decode!()

      case result.status do
        200 ->
          assert %{"data" => data} = response_body
          assert is_map(data)
          assert Map.has_key?(data, "solar_system_id")
          assert Map.has_key?(data, "solar_system_name")

        404 ->
          assert %{"error" => "System not found"} = response_body
      end
    end

    test "handles invalid solar system id format" do
      conn = build_conn()
      params = %{"id" => "invalid"}

      result = CommonAPIController.show_system_static(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => error_msg} = response_body
      assert is_binary(error_msg)
    end

    test "handles empty id parameter" do
      conn = build_conn()
      params = %{"id" => ""}

      result = CommonAPIController.show_system_static(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => error_msg} = response_body
      assert is_binary(error_msg)
    end

    test "handles nil id parameter" do
      conn = build_conn()
      params = %{"id" => nil}

      result = CommonAPIController.show_system_static(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => error_msg} = response_body
      assert is_binary(error_msg)
    end

    test "handles various id formats" do
      conn = build_conn()

      # Test different ID formats
      id_formats = [
        "30000142",
        "30000001",
        "31000005",
        "0",
        "-1",
        "999999999",
        "123abc",
        "30000142.5",
        "1e6"
      ]

      for id_value <- id_formats do
        params = %{"id" => id_value}
        result = CommonAPIController.show_system_static(conn, params)

        assert %Plug.Conn{} = result
        # Should either return data, not found, or bad request
        assert result.status in [200, 400, 404]

        response_body = result.resp_body |> Jason.decode!()
        assert is_map(response_body)

        case result.status do
          200 ->
            assert %{"data" => _data} = response_body

          400 ->
            assert %{"error" => _error_msg} = response_body

          404 ->
            assert %{"error" => "System not found"} = response_body
        end
      end
    end

    test "handles extra parameters" do
      conn = build_conn()

      params = %{
        "id" => "30000142",
        "extra_field" => "should_be_ignored",
        "nested" => %{"data" => "value"},
        "array" => [1, 2, 3]
      }

      result = CommonAPIController.show_system_static(conn, params)

      assert %Plug.Conn{} = result
      # Extra parameters should be ignored
      assert result.status in [200, 404]

      response_body = result.resp_body |> Jason.decode!()
      assert is_map(response_body)
    end
  end

  describe "response structure validation" do
    test "validates successful response structure" do
      conn = build_conn()
      # Use Jita as it's likely to exist in test data
      params = %{"id" => "30000142"}

      result = CommonAPIController.show_system_static(conn, params)

      if result.status == 200 do
        response_body = result.resp_body |> Jason.decode!()
        assert %{"data" => data} = response_body
        assert is_map(data)

        # Required fields according to schema
        assert Map.has_key?(data, "solar_system_id")
        assert Map.has_key?(data, "solar_system_name")

        # Validate data types
        assert is_integer(data["solar_system_id"])
        assert is_binary(data["solar_system_name"])

        # Optional fields that might be present
        optional_fields = [
          "region_id",
          "constellation_id",
          "solar_system_name_lc",
          "constellation_name",
          "region_name",
          "system_class",
          "security",
          "type_description",
          "class_title",
          "is_shattered",
          "effect_name",
          "effect_power",
          "statics",
          "static_details",
          "wandering",
          "triglavian_invasion_status",
          "sun_type_id"
        ]

        # Validate optional fields if present
        Enum.each(optional_fields, fn field ->
          if Map.has_key?(data, field) do
            case field do
              field
              when field in [
                     "region_id",
                     "constellation_id",
                     "system_class",
                     "effect_power",
                     "sun_type_id"
                   ] ->
                if not is_nil(data[field]) do
                  assert is_integer(data[field])
                end

              field
              when field in [
                     "solar_system_name_lc",
                     "constellation_name",
                     "region_name",
                     "security",
                     "type_description",
                     "class_title",
                     "effect_name",
                     "triglavian_invasion_status"
                   ] ->
                if not is_nil(data[field]) do
                  assert is_binary(data[field])
                end

              "is_shattered" ->
                if not is_nil(data[field]) do
                  assert is_boolean(data[field])
                end

              field when field in ["statics", "wandering"] ->
                if not is_nil(data[field]) do
                  assert is_list(data[field])
                end

              "static_details" ->
                if not is_nil(data[field]) do
                  assert is_list(data[field])
                  # Validate static details structure
                  Enum.each(data[field], fn static ->
                    assert is_map(static)
                    assert Map.has_key?(static, "name")
                    assert Map.has_key?(static, "destination")
                    assert Map.has_key?(static, "properties")
                  end)
                end
            end
          end
        end)
      end
    end

    test "validates error response structure" do
      conn = build_conn()
      params = %{"id" => "invalid"}

      result = CommonAPIController.show_system_static(conn, params)

      assert result.status == 400
      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => error_msg} = response_body
      assert is_binary(error_msg)
      assert String.length(error_msg) > 0
    end

    test "validates not found response structure" do
      conn = build_conn()
      # Use a system ID that's unlikely to exist
      params = %{"id" => "999999999"}

      result = CommonAPIController.show_system_static(conn, params)

      # Could be 400 (invalid) or 404 (not found)
      if result.status == 404 do
        response_body = result.resp_body |> Jason.decode!()
        assert %{"error" => "System not found"} = response_body
      end
    end
  end

  describe "edge cases and error handling" do
    test "handles malformed parameter structures" do
      conn = build_conn()

      # Test various malformed parameter structures
      malformed_params = [
        %{"id" => %{"nested" => "object"}},
        %{"id" => [1, 2, 3]},
        %{"id" => %{}},
        %{"malformed" => %{"data" => "value"}}
      ]

      for params <- malformed_params do
        result = CommonAPIController.show_system_static(conn, params)

        assert %Plug.Conn{} = result
        # Should handle malformed structures gracefully
        assert result.status in [400, 404]

        response_body = result.resp_body |> Jason.decode!()
        assert %{"error" => _error_msg} = response_body
      end
    end

    test "handles concurrent parameter access" do
      conn = build_conn()

      # Test with complex nested parameter structure
      params = %{
        "id" => "30000142",
        "nested_data" => %{
          "deep" => %{
            "structure" => "value"
          }
        },
        "array_field" => [1, 2, 3, %{"object" => "in_array"}],
        "extra_top_level" => "ignored"
      }

      result = CommonAPIController.show_system_static(conn, params)

      assert %Plug.Conn{} = result
      # Should handle complex structure gracefully
      assert result.status in [200, 404]

      response_body = result.resp_body |> Jason.decode!()
      assert is_map(response_body)
    end

    test "handles very large parameter objects" do
      conn = build_conn()

      # Create a large parameter object
      large_data = 1..100 |> Enum.into(%{}, fn i -> {"field_#{i}", "value_#{i}"} end)

      params = Map.merge(%{"id" => "30000142"}, large_data)

      result = CommonAPIController.show_system_static(conn, params)

      assert %Plug.Conn{} = result
      # Should handle large objects gracefully
      assert result.status in [200, 404]

      response_body = result.resp_body |> Jason.decode!()
      assert is_map(response_body)
    end

    test "handles special characters and unicode in id" do
      conn = build_conn()

      # Test with special characters and unicode
      special_ids = [
        "30000142测试",
        "30000142🚀",
        "30000142!@#$%",
        "30000142\n\r\t",
        "30000142\0",
        "30000142 spaces",
        "30000142\x00\x01\x02"
      ]

      for id <- special_ids do
        params = %{"id" => id}
        result = CommonAPIController.show_system_static(conn, params)

        assert %Plug.Conn{} = result
        # Should handle special characters gracefully
        assert result.status in [400, 404]

        response_body = result.resp_body |> Jason.decode!()
        assert %{"error" => _error_msg} = response_body
      end
    end

    test "performance with repeated requests" do
      conn = build_conn()
      params = %{"id" => "30000142"}

      # Make multiple requests to test consistency
      results =
        for _i <- 1..5 do
          CommonAPIController.show_system_static(conn, params)
        end

      # All results should have consistent structure and status
      first_status = List.first(results).status

      Enum.each(results, fn result ->
        assert %Plug.Conn{} = result
        # Should be consistent
        assert result.status == first_status
        assert result.status in [200, 404]

        response_body = result.resp_body |> Jason.decode!()
        assert is_map(response_body)
      end)
    end

    test "handles request with different connection states" do
      # Test with basic connection
      conn1 = build_conn()
      result1 = CommonAPIController.show_system_static(conn1, %{"id" => "30000142"})
      assert %Plug.Conn{} = result1
      assert result1.status in [200, 404]

      # Test with connection that has assigns
      conn2 = build_conn() |> assign(:user_id, "123") |> assign(:map_id, Ecto.UUID.generate())
      result2 = CommonAPIController.show_system_static(conn2, %{"id" => "30000142"})
      assert %Plug.Conn{} = result2
      assert result2.status in [200, 404]

      # Test with connection that has different headers
      conn3 = build_conn() |> put_req_header("accept", "application/xml")
      result3 = CommonAPIController.show_system_static(conn3, %{"id" => "30000142"})
      assert %Plug.Conn{} = result3
      assert result3.status in [200, 404]
    end

    test "validates static details structure when present" do
      conn = build_conn()
      params = %{"id" => "30000142"}

      result = CommonAPIController.show_system_static(conn, params)

      if result.status == 200 do
        response_body = result.resp_body |> Jason.decode!()
        %{"data" => data} = response_body

        # If static_details is present, validate its structure
        if Map.has_key?(data, "static_details") and not is_nil(data["static_details"]) do
          static_details = data["static_details"]
          assert is_list(static_details)

          Enum.each(static_details, fn static ->
            assert is_map(static)
            assert Map.has_key?(static, "name")
            assert Map.has_key?(static, "destination")
            assert Map.has_key?(static, "properties")

            # Validate destination structure
            destination = static["destination"]
            assert is_map(destination)
            assert Map.has_key?(destination, "id")
            assert Map.has_key?(destination, "name")
            assert Map.has_key?(destination, "short_name")

            # Validate properties structure
            properties = static["properties"]
            assert is_map(properties)
            assert Map.has_key?(properties, "lifetime")
            assert Map.has_key?(properties, "max_mass")
            assert Map.has_key?(properties, "max_jump_mass")
            assert Map.has_key?(properties, "mass_regeneration")
          end)
        end
      end
    end
  end
end
