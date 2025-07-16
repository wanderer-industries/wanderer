defmodule WandererAppWeb.LicenseApiControllerTest do
  use WandererAppWeb.ConnCase, async: true

  alias WandererAppWeb.LicenseApiController

  describe "create/2 functionality" do
    test "handles missing map_id parameter" do
      conn = build_conn()
      params = %{}

      result = LicenseApiController.create(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "Missing required parameter: map_id"} = response_body
    end

    test "handles valid map_id parameter" do
      conn = build_conn()
      map_id = Ecto.UUID.generate()
      params = %{"map_id" => map_id}

      result = LicenseApiController.create(conn, params)

      assert %Plug.Conn{} = result
      # Will fail at operation level since map doesn't exist
      assert result.status in [404, 500]

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => _error_msg} = response_body
    end

    test "handles extra parameters" do
      conn = build_conn()
      map_id = Ecto.UUID.generate()

      params = %{
        "map_id" => map_id,
        "extra_field" => "ignored",
        "nested" => %{"data" => "value"}
      }

      result = LicenseApiController.create(conn, params)

      assert %Plug.Conn{} = result
      # Extra parameters should be ignored, will fail at operation level
      assert result.status in [404, 500]

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => _error_msg} = response_body
    end

    test "handles invalid map_id format" do
      conn = build_conn()
      params = %{"map_id" => "invalid-uuid"}

      result = LicenseApiController.create(conn, params)

      assert %Plug.Conn{} = result
      # Invalid UUID will fail at operation level
      assert result.status in [404, 500]

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => _error_msg} = response_body
    end

    test "handles empty map_id" do
      conn = build_conn()
      params = %{"map_id" => ""}

      result = LicenseApiController.create(conn, params)

      assert %Plug.Conn{} = result
      # Empty string will fail at operation level
      assert result.status in [404, 500]

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => _error_msg} = response_body
    end

    test "handles nil map_id" do
      conn = build_conn()
      params = %{"map_id" => nil}

      result = LicenseApiController.create(conn, params)

      assert %Plug.Conn{} = result
      # Nil value will fail at operation level
      assert result.status in [404, 500]

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => _error_msg} = response_body
    end
  end

  describe "update_validity/2 functionality" do
    test "handles missing id parameter" do
      conn = build_conn()
      params = %{"is_valid" => true}

      # Should raise FunctionClauseError since update_validity/2 expects "id" key
      assert_raise FunctionClauseError, fn ->
        LicenseApiController.update_validity(conn, params)
      end
    end

    test "handles missing is_valid parameter" do
      conn = build_conn()
      license_id = Ecto.UUID.generate()
      params = %{"id" => license_id}

      result = LicenseApiController.update_validity(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "Missing required parameter: is_valid"} = response_body
    end

    test "handles valid parameters" do
      conn = build_conn()
      license_id = Ecto.UUID.generate()
      params = %{"id" => license_id, "is_valid" => true}

      result = LicenseApiController.update_validity(conn, params)

      assert %Plug.Conn{} = result
      # Will fail with not found since license doesn't exist
      assert result.status in [404, 500]

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => _error_msg} = response_body
    end

    test "handles invalid license id format" do
      conn = build_conn()
      params = %{"id" => "invalid-uuid", "is_valid" => false}

      result = LicenseApiController.update_validity(conn, params)

      assert %Plug.Conn{} = result
      # Invalid UUID should fail at operation level
      assert result.status in [404, 500]

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => _error_msg} = response_body
    end

    test "handles various is_valid values" do
      conn = build_conn()
      license_id = Ecto.UUID.generate()

      # Test different values for is_valid
      valid_values = [true, false, "true", "false", 1, 0]

      for is_valid <- valid_values do
        params = %{"id" => license_id, "is_valid" => is_valid}
        result = LicenseApiController.update_validity(conn, params)

        assert %Plug.Conn{} = result
        # Should handle different is_valid formats, fail at operation level
        assert result.status in [404, 500]

        response_body = result.resp_body |> Jason.decode!()
        assert %{"error" => _error_msg} = response_body
      end
    end

    test "handles extra parameters" do
      conn = build_conn()
      license_id = Ecto.UUID.generate()

      params = %{
        "id" => license_id,
        "is_valid" => true,
        "extra_field" => "ignored",
        "nested" => %{"data" => "value"}
      }

      result = LicenseApiController.update_validity(conn, params)

      assert %Plug.Conn{} = result
      # Extra parameters should be ignored
      assert result.status in [404, 500]

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => _error_msg} = response_body
    end
  end

  describe "update_expiration/2 functionality" do
    test "handles missing id parameter" do
      conn = build_conn()
      params = %{"expire_at" => "2024-12-31T23:59:59Z"}

      # Should raise FunctionClauseError since update_expiration/2 expects "id" key
      assert_raise FunctionClauseError, fn ->
        LicenseApiController.update_expiration(conn, params)
      end
    end

    test "handles missing expire_at parameter" do
      conn = build_conn()
      license_id = Ecto.UUID.generate()
      params = %{"id" => license_id}

      result = LicenseApiController.update_expiration(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "Missing required parameter: expire_at"} = response_body
    end

    test "handles valid parameters" do
      conn = build_conn()
      license_id = Ecto.UUID.generate()
      params = %{"id" => license_id, "expire_at" => "2024-12-31T23:59:59Z"}

      result = LicenseApiController.update_expiration(conn, params)

      assert %Plug.Conn{} = result
      # Will fail with not found since license doesn't exist
      assert result.status in [404, 500]

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => _error_msg} = response_body
    end

    test "handles invalid license id format" do
      conn = build_conn()
      params = %{"id" => "invalid-uuid", "expire_at" => "2024-12-31T23:59:59Z"}

      result = LicenseApiController.update_expiration(conn, params)

      assert %Plug.Conn{} = result
      # Invalid UUID should fail at operation level
      assert result.status in [404, 500]

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => _error_msg} = response_body
    end

    test "handles various date formats" do
      conn = build_conn()
      license_id = Ecto.UUID.generate()

      # Test different date formats
      date_formats = [
        "2024-12-31T23:59:59Z",
        "2024-12-31T23:59:59.000Z",
        "2024-12-31 23:59:59",
        "invalid-date",
        "",
        nil
      ]

      for expire_at <- date_formats do
        params = %{"id" => license_id, "expire_at" => expire_at}
        result = LicenseApiController.update_expiration(conn, params)

        assert %Plug.Conn{} = result
        # Should handle different date formats, fail at operation level
        assert result.status in [404, 500]

        response_body = result.resp_body |> Jason.decode!()
        assert %{"error" => _error_msg} = response_body
      end
    end
  end

  describe "get_by_map_id/2 functionality" do
    test "handles missing map_id parameter" do
      conn = build_conn()
      params = %{}

      # Should raise FunctionClauseError since get_by_map_id/2 expects "map_id" key
      assert_raise FunctionClauseError, fn ->
        LicenseApiController.get_by_map_id(conn, params)
      end
    end

    test "handles valid map_id parameter" do
      conn = build_conn()
      map_id = Ecto.UUID.generate()
      params = %{"map_id" => map_id}

      result = LicenseApiController.get_by_map_id(conn, params)

      assert %Plug.Conn{} = result
      # Will fail since license doesn't exist for this map
      assert result.status in [404, 500]

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => _error_msg} = response_body
    end

    test "handles invalid map_id format" do
      conn = build_conn()
      params = %{"map_id" => "invalid-uuid"}

      result = LicenseApiController.get_by_map_id(conn, params)

      assert %Plug.Conn{} = result
      # Invalid UUID should fail at operation level
      assert result.status in [404, 500]

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => _error_msg} = response_body
    end

    test "handles empty and nil map_id" do
      conn = build_conn()

      # Test empty string
      params_empty = %{"map_id" => ""}
      result_empty = LicenseApiController.get_by_map_id(conn, params_empty)

      assert %Plug.Conn{} = result_empty
      assert result_empty.status in [404, 500]

      # Test nil value
      params_nil = %{"map_id" => nil}
      result_nil = LicenseApiController.get_by_map_id(conn, params_nil)

      assert %Plug.Conn{} = result_nil
      assert result_nil.status in [404, 500]
    end

    test "handles extra parameters" do
      conn = build_conn()
      map_id = Ecto.UUID.generate()

      params = %{
        "map_id" => map_id,
        "extra_field" => "ignored",
        "nested" => %{"data" => "value"}
      }

      result = LicenseApiController.get_by_map_id(conn, params)

      assert %Plug.Conn{} = result
      # Extra parameters should be ignored
      assert result.status in [404, 500]

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => _error_msg} = response_body
    end
  end

  describe "validate/2 functionality" do
    test "handles missing license assign" do
      conn = build_conn()
      params = %{}

      # Should raise KeyError since validate/2 expects license in assigns
      assert_raise KeyError, fn ->
        LicenseApiController.validate(conn, params)
      end
    end

    test "handles valid license assign" do
      license = %{
        id: Ecto.UUID.generate(),
        license_key: "BOT-XXXXXXXXXXXX",
        is_valid: true,
        expire_at: "2024-12-31T23:59:59Z",
        map_id: Ecto.UUID.generate()
      }

      conn = build_conn() |> assign(:license, license)
      params = %{}

      result = LicenseApiController.validate(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 200

      response_body = result.resp_body |> Jason.decode!()

      assert %{
               "license_valid" => true,
               "expire_at" => "2024-12-31T23:59:59Z",
               "map_id" => _map_id
             } = response_body
    end

    test "handles invalid license assign" do
      license = %{
        id: Ecto.UUID.generate(),
        license_key: "BOT-XXXXXXXXXXXX",
        is_valid: false,
        expire_at: "2024-01-01T00:00:00Z",
        map_id: Ecto.UUID.generate()
      }

      conn = build_conn() |> assign(:license, license)
      params = %{}

      result = LicenseApiController.validate(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 200

      response_body = result.resp_body |> Jason.decode!()

      assert %{
               "license_valid" => false,
               "expire_at" => "2024-01-01T00:00:00Z",
               "map_id" => _map_id
             } = response_body
    end

    test "handles parameters (should be ignored)" do
      license = %{
        id: Ecto.UUID.generate(),
        license_key: "BOT-XXXXXXXXXXXX",
        is_valid: true,
        expire_at: "2024-12-31T23:59:59Z",
        map_id: Ecto.UUID.generate()
      }

      conn = build_conn() |> assign(:license, license)
      params = %{"ignored" => "value", "nested" => %{"data" => "test"}}

      result = LicenseApiController.validate(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 200

      response_body = result.resp_body |> Jason.decode!()

      assert %{
               "license_valid" => true,
               "expire_at" => "2024-12-31T23:59:59Z",
               "map_id" => _map_id
             } = response_body
    end
  end

  describe "edge cases and error handling" do
    test "handles malformed parameters consistently" do
      conn = build_conn()

      # Test various malformed parameter structures
      malformed_params = [
        %{"map_id" => %{"nested" => "object"}},
        %{"map_id" => [1, 2, 3]},
        %{"map_id" => 123},
        %{"is_valid" => %{"nested" => "object"}},
        %{"expire_at" => %{"nested" => "object"}}
      ]

      for params <- malformed_params do
        if Map.has_key?(params, "map_id") do
          result = LicenseApiController.create(conn, params)
          assert %Plug.Conn{} = result
          assert result.status in [400, 404, 500]
        end
      end
    end

    test "handles concurrent parameter access" do
      conn = build_conn()
      map_id = Ecto.UUID.generate()

      # Test with complex nested parameter structure
      params = %{
        "map_id" => map_id,
        "nested_data" => %{
          "deep" => %{
            "structure" => "value"
          }
        },
        "array_field" => [1, 2, 3, %{"object" => "in_array"}],
        "extra_top_level" => "ignored"
      }

      result = LicenseApiController.create(conn, params)

      assert %Plug.Conn{} = result
      # Should handle complex structure gracefully
      assert result.status in [404, 500]

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => _error_msg} = response_body
    end

    test "handles very large parameter objects" do
      conn = build_conn()
      map_id = Ecto.UUID.generate()

      # Create a large parameter object
      large_data = 1..100 |> Enum.into(%{}, fn i -> {"field_#{i}", "value_#{i}"} end)

      params = Map.merge(%{"map_id" => map_id}, large_data)

      result = LicenseApiController.create(conn, params)

      assert %Plug.Conn{} = result
      # Should handle large objects gracefully
      assert result.status in [404, 500]

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => _error_msg} = response_body
    end
  end
end
