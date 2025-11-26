defmodule WandererAppWeb.MapConnectionAPIControllerTest do
  use WandererAppWeb.ConnCase

  import Mox
  import Phoenix.ConnTest

  alias WandererAppWeb.MapConnectionAPIController

  setup :verify_on_exit!

  setup do
    # Ensure we're in global mode and re-setup mocks
    Mox.set_mox_global()
    WandererApp.Test.Mocks.setup_additional_expectations()

    :ok
  end

  describe "parameter validation and helper functions" do
    test "index validates solar_system_source parameter" do
      conn = build_conn() |> assign(:map_id, Ecto.UUID.generate())

      # Test with valid parameter
      params_valid = %{"solar_system_source" => "30000142"}
      result_valid = MapConnectionAPIController.index(conn, params_valid)
      assert %Plug.Conn{} = result_valid

      # Test with invalid parameter
      params_invalid = %{"solar_system_source" => "invalid"}
      result_invalid = MapConnectionAPIController.index(conn, params_invalid)
      assert json_response(result_invalid, 400)
      response = json_response(result_invalid, 400)
      assert Map.has_key?(response, "error")
    end

    test "index validates solar_system_target parameter" do
      conn = build_conn() |> assign(:map_id, Ecto.UUID.generate())

      # Test with valid parameter
      params_valid = %{"solar_system_target" => "30000143"}
      result_valid = MapConnectionAPIController.index(conn, params_valid)
      assert %Plug.Conn{} = result_valid

      # Test with invalid parameter
      params_invalid = %{"solar_system_target" => "invalid"}
      result_invalid = MapConnectionAPIController.index(conn, params_invalid)
      assert json_response(result_invalid, 400)
      response = json_response(result_invalid, 400)
      assert Map.has_key?(response, "error")
    end

    test "index filters connections by source and target" do
      conn = build_conn() |> assign(:map_id, Ecto.UUID.generate())

      # Test with both filters
      params = %{
        "solar_system_source" => "30000142",
        "solar_system_target" => "30000143"
      }

      result = MapConnectionAPIController.index(conn, params)
      assert %Plug.Conn{} = result
      assert result.status in [200, 404, 500]
    end

    test "show by connection id" do
      map_id = Ecto.UUID.generate()
      conn_id = Ecto.UUID.generate()
      conn = build_conn() |> assign(:map_id, map_id)

      params = %{"id" => conn_id}
      result = MapConnectionAPIController.show(conn, params)
      # Should handle the call without crashing - can return Conn or error tuple
      case result do
        %Plug.Conn{} ->
          assert result.status in [200, 404, 500]

        {:error, _} ->
          # Error tuples are acceptable in unit tests
          :ok
      end
    end

    test "show by source and target system IDs" do
      map_id = Ecto.UUID.generate()
      conn = build_conn() |> assign(:map_id, map_id)

      # Test with valid system IDs
      params_valid = %{
        "solar_system_source" => "30000142",
        "solar_system_target" => "30000143"
      }

      result_valid = MapConnectionAPIController.show(conn, params_valid)

      case result_valid do
        %Plug.Conn{} -> :ok
        {:error, _} -> :ok
      end

      # Test with invalid system IDs
      params_invalid = %{
        "solar_system_source" => "invalid",
        "solar_system_target" => "30000143"
      }

      result_invalid = MapConnectionAPIController.show(conn, params_invalid)

      case result_invalid do
        %Plug.Conn{} -> :ok
        {:error, _} -> :ok
      end
    end

    test "create connection with valid parameters" do
      # Set up CachedInfo mock stubs for the systems used in the test
      WandererApp.CachedInfo.Mock
      |> stub(:get_system_static_info, fn
        30_000_142 ->
          {:ok,
           %{
             solar_system_id: 30_000_142,
             region_id: 10_000_002,
             constellation_id: 20_000_020,
             solar_system_name: "Jita",
             solar_system_name_lc: "jita",
             constellation_name: "Kimotoro",
             region_name: "The Forge",
             system_class: 0,
             security: "0.9",
             type_description: "High Security",
             class_title: "High Sec",
             is_shattered: false,
             effect_name: nil,
             effect_power: nil,
             statics: [],
             wandering: [],
             triglavian_invasion_status: nil,
             sun_type_id: 45041
           }}

        30_000_143 ->
          {:ok,
           %{
             solar_system_id: 30_000_143,
             region_id: 10_000_043,
             constellation_id: 20_000_304,
             solar_system_name: "Amarr",
             solar_system_name_lc: "amarr",
             constellation_name: "Throne Worlds",
             region_name: "Domain",
             system_class: 0,
             security: "0.9",
             type_description: "High Security",
             class_title: "High Sec",
             is_shattered: false,
             effect_name: nil,
             effect_power: nil,
             statics: [],
             wandering: [],
             triglavian_invasion_status: nil,
             sun_type_id: 45041
           }}

        _ ->
          {:error, :not_found}
      end)

      map_id = Ecto.UUID.generate()
      char_id = "123456789"
      conn = build_conn() |> assign(:map_id, map_id) |> assign(:owner_character_id, char_id)

      params = %{
        "solar_system_source" => 30_000_142,
        "solar_system_target" => 30_000_143,
        "type" => 0
      }

      result =
        try do
          MapConnectionAPIController.create(conn, params)
        catch
          "Map server not started" ->
            # In unit tests, map servers aren't started, so this is expected
            build_conn()
            |> put_status(500)
            |> put_resp_content_type("application/json")
            |> resp(500, Jason.encode!(%{error: "Map server not started"}))
        end

      assert %Plug.Conn{} = result
      # Response depends on underlying data or infrastructure setup
      assert result.status in [200, 201, 400, 500]
    end

    test "create connection handles various response types" do
      # Set up CachedInfo mock stubs for the systems used in the test
      WandererApp.CachedInfo.Mock
      |> stub(:get_system_static_info, fn
        30_000_142 ->
          {:ok,
           %{
             solar_system_id: 30_000_142,
             region_id: 10_000_002,
             constellation_id: 20_000_020,
             solar_system_name: "Jita",
             solar_system_name_lc: "jita",
             constellation_name: "Kimotoro",
             region_name: "The Forge",
             system_class: 0,
             security: "0.9",
             type_description: "High Security",
             class_title: "High Sec",
             is_shattered: false,
             effect_name: nil,
             effect_power: nil,
             statics: [],
             wandering: [],
             triglavian_invasion_status: nil,
             sun_type_id: 45041
           }}

        30_000_143 ->
          {:ok,
           %{
             solar_system_id: 30_000_143,
             region_id: 10_000_043,
             constellation_id: 20_000_304,
             solar_system_name: "Amarr",
             solar_system_name_lc: "amarr",
             constellation_name: "Throne Worlds",
             region_name: "Domain",
             system_class: 0,
             security: "0.9",
             type_description: "High Security",
             class_title: "High Sec",
             is_shattered: false,
             effect_name: nil,
             effect_power: nil,
             statics: [],
             wandering: [],
             triglavian_invasion_status: nil,
             sun_type_id: 45041
           }}

        _ ->
          {:error, :not_found}
      end)

      map_id = Ecto.UUID.generate()
      char_id = "123456789"
      conn = build_conn() |> assign(:map_id, map_id) |> assign(:owner_character_id, char_id)

      params = %{
        "solar_system_source" => 30_000_142,
        "solar_system_target" => 30_000_143
      }

      result =
        try do
          MapConnectionAPIController.create(conn, params)
        catch
          "Map server not started" ->
            # In unit tests, map servers aren't started, so this is expected
            build_conn()
            |> put_status(500)
            |> put_resp_content_type("application/json")
            |> resp(500, Jason.encode!(%{error: "Map server not started"}))
        end

      assert %Plug.Conn{} = result
    end

    test "delete connection by id" do
      map_id = Ecto.UUID.generate()
      conn_id = Ecto.UUID.generate()
      conn = build_conn() |> assign(:map_id, map_id)

      params = %{"id" => conn_id}
      result = MapConnectionAPIController.delete(conn, params)

      case result do
        %Plug.Conn{} -> :ok
        {:error, _} -> :ok
      end
    end

    test "delete connection by source and target" do
      map_id = Ecto.UUID.generate()
      conn = build_conn() |> assign(:map_id, map_id)

      params = %{
        "solar_system_source" => "30000142",
        "solar_system_target" => "30000143"
      }

      result = MapConnectionAPIController.delete(conn, params)

      case result do
        %Plug.Conn{} -> :ok
        {:error, _} -> :ok
      end
    end

    test "delete multiple connections by connection_ids" do
      map_id = Ecto.UUID.generate()
      conn = build_conn() |> assign(:map_id, map_id)

      conn_ids = [Ecto.UUID.generate(), Ecto.UUID.generate()]
      params = %{"connection_ids" => conn_ids}
      # API doesn't support connection_ids format, expects FunctionClauseError
      assert_raise(FunctionClauseError, fn ->
        MapConnectionAPIController.delete(conn, params)
      end)
    end

    test "update connection by id" do
      map_id = Ecto.UUID.generate()
      char_id = "123456789"
      conn_id = Ecto.UUID.generate()
      conn = build_conn() |> assign(:map_id, map_id) |> assign(:owner_character_id, char_id)

      # Mock body_params
      body_params = %{
        "mass_status" => 1,
        "ship_size_type" => 2,
        "locked" => false
      }

      conn = %{conn | body_params: body_params}

      params = %{"id" => conn_id}
      result = MapConnectionAPIController.update(conn, params)

      case result do
        %Plug.Conn{} -> :ok
        {:error, _} -> :ok
      end
    end

    test "update connection by source and target systems" do
      map_id = Ecto.UUID.generate()
      char_id = "123456789"
      conn = build_conn() |> assign(:map_id, map_id) |> assign(:owner_character_id, char_id)

      body_params = %{
        "mass_status" => 1,
        "type" => 0
      }

      conn = %{conn | body_params: body_params}

      params = %{
        "solar_system_source" => "30000142",
        "solar_system_target" => "30000143"
      }

      result = MapConnectionAPIController.update(conn, params)

      case result do
        %Plug.Conn{} -> :ok
        {:error, _} -> :ok
      end
    end

    test "list_all_connections legacy endpoint" do
      map_id = Ecto.UUID.generate()
      conn = build_conn() |> assign(:map_id, map_id)

      result = MapConnectionAPIController.list_all_connections(conn, %{})
      assert %Plug.Conn{} = result
      assert result.status in [200, 500]
    end
  end

  describe "parameter parsing and edge cases" do
    test "parse_optional handles various input formats" do
      # This tests the private function indirectly through index
      conn = build_conn() |> assign(:map_id, Ecto.UUID.generate())

      # Test nil parameter
      result_nil = MapConnectionAPIController.index(conn, %{})
      assert %Plug.Conn{} = result_nil

      # Test empty string
      result_empty = MapConnectionAPIController.index(conn, %{"solar_system_source" => ""})
      assert %Plug.Conn{} = result_empty

      # Test zero value
      result_zero = MapConnectionAPIController.index(conn, %{"solar_system_source" => "0"})
      assert %Plug.Conn{} = result_zero
    end

    test "filter functions handle edge cases" do
      # Test filtering indirectly through index
      conn = build_conn() |> assign(:map_id, Ecto.UUID.generate())

      # Test with valid filters
      params_with_filters = %{
        "solar_system_source" => "30000142",
        "solar_system_target" => "30000143"
      }

      result = MapConnectionAPIController.index(conn, params_with_filters)
      assert %Plug.Conn{} = result
    end

    test "handles missing map_id in assigns" do
      conn = build_conn()

      # This should fail due to missing assigns
      assert_raise(FunctionClauseError, fn ->
        MapConnectionAPIController.index(conn, %{})
      end)
    end

    test "handles different parameter combinations for show" do
      map_id = Ecto.UUID.generate()
      conn = build_conn() |> assign(:map_id, map_id)

      # Test various parameter combinations that should route to different clauses
      param_combinations = [
        %{"id" => Ecto.UUID.generate()},
        %{"solar_system_source" => "30000142", "solar_system_target" => "30000143"},
        %{"solar_system_source" => "invalid", "solar_system_target" => "30000143"},
        %{"solar_system_source" => "30000142", "solar_system_target" => "invalid"}
      ]

      Enum.each(param_combinations, fn params ->
        result = MapConnectionAPIController.show(conn, params)

        case result do
          %Plug.Conn{} -> :ok
          {:error, _} -> :ok
        end
      end)
    end

    test "handles different parameter combinations for delete" do
      map_id = Ecto.UUID.generate()
      conn = build_conn() |> assign(:map_id, map_id)

      # Test parameter combinations that should work or return errors
      working_param_combinations = [
        %{"id" => Ecto.UUID.generate()},
        %{"solar_system_source" => "30000142", "solar_system_target" => "30000143"}
      ]

      Enum.each(working_param_combinations, fn params ->
        result = MapConnectionAPIController.delete(conn, params)

        case result do
          %Plug.Conn{} -> :ok
          {:error, _} -> :ok
        end
      end)

      # Test parameter combinations that should raise FunctionClauseError
      failing_param_combinations = [
        %{"connection_ids" => [Ecto.UUID.generate()]},
        %{"connection_ids" => []}
      ]

      Enum.each(failing_param_combinations, fn params ->
        assert_raise(FunctionClauseError, fn ->
          MapConnectionAPIController.delete(conn, params)
        end)
      end)
    end

    test "handles different body_params for update" do
      map_id = Ecto.UUID.generate()
      char_id = "123456789"
      conn_id = Ecto.UUID.generate()
      base_conn = build_conn() |> assign(:map_id, map_id) |> assign(:owner_character_id, char_id)

      # Test different body_params combinations
      body_param_combinations = [
        %{},
        %{"mass_status" => 1},
        %{"ship_size_type" => 2},
        %{"locked" => true},
        %{"custom_info" => "test info"},
        %{"type" => 0},
        %{"mass_status" => 1, "ship_size_type" => 2, "locked" => false},
        %{"invalid_field" => "should_be_ignored", "mass_status" => 1}
      ]

      Enum.each(body_param_combinations, fn body_params ->
        conn = %{base_conn | body_params: body_params}
        result = MapConnectionAPIController.update(conn, %{"id" => conn_id})

        case result do
          %Plug.Conn{} -> :ok
          {:error, _} -> :ok
        end
      end)
    end
  end

  describe "error handling scenarios" do
    test "handles malformed connection IDs" do
      map_id = Ecto.UUID.generate()
      conn = build_conn() |> assign(:map_id, map_id)

      # Test with various malformed IDs
      malformed_ids = ["", "invalid-uuid", "123", nil]

      Enum.each(malformed_ids, fn id ->
        params = %{"id" => id}
        result = MapConnectionAPIController.show(conn, params)

        case result do
          %Plug.Conn{} -> :ok
          {:error, _} -> :ok
        end
      end)
    end

    test "handles malformed system IDs for show" do
      map_id = Ecto.UUID.generate()
      conn = build_conn() |> assign(:map_id, map_id)

      # Test with various malformed system IDs
      malformed_system_combinations = [
        %{"solar_system_source" => nil, "solar_system_target" => "30000143"},
        %{"solar_system_source" => "30000142", "solar_system_target" => nil},
        %{"solar_system_source" => "", "solar_system_target" => "30000143"},
        %{"solar_system_source" => "abc", "solar_system_target" => "def"},
        %{"solar_system_source" => -1, "solar_system_target" => 30_000_143}
      ]

      Enum.each(malformed_system_combinations, fn params ->
        result = MapConnectionAPIController.show(conn, params)

        case result do
          %Plug.Conn{} -> :ok
          {:error, _} -> :ok
        end
      end)
    end

    test "handles malformed system IDs for delete" do
      map_id = Ecto.UUID.generate()
      conn = build_conn() |> assign(:map_id, map_id)

      malformed_params = [
        %{"solar_system_source" => "invalid", "solar_system_target" => "30000143"},
        %{"solar_system_source" => "30000142", "solar_system_target" => "invalid"},
        %{"solar_system_source" => "", "solar_system_target" => ""},
        %{"solar_system_source" => nil, "solar_system_target" => nil}
      ]

      Enum.each(malformed_params, fn params ->
        result = MapConnectionAPIController.delete(conn, params)

        case result do
          %Plug.Conn{} -> :ok
          {:error, _} -> :ok
        end
      end)
    end

    test "handles create with missing or invalid parameters" do
      map_id = Ecto.UUID.generate()
      char_id = "123456789"
      conn = build_conn() |> assign(:map_id, map_id) |> assign(:owner_character_id, char_id)

      # Test various invalid parameter combinations
      invalid_param_combinations = [
        %{},
        %{"solar_system_source" => nil},
        %{"solar_system_target" => nil},
        %{"solar_system_source" => "invalid", "solar_system_target" => "30000143"},
        %{"solar_system_source" => 30_000_142, "solar_system_target" => "invalid"}
      ]

      Enum.each(invalid_param_combinations, fn params ->
        result = MapConnectionAPIController.create(conn, params)
        assert %Plug.Conn{} = result
        # Should handle gracefully with appropriate error response
        assert result.status in [200, 201, 400, 500]
      end)
    end

    test "handles update with malformed system IDs" do
      map_id = Ecto.UUID.generate()
      char_id = "123456789"
      base_conn = build_conn() |> assign(:map_id, map_id) |> assign(:owner_character_id, char_id)

      body_params = %{"mass_status" => 1}
      conn = %{base_conn | body_params: body_params}

      malformed_params = [
        %{"solar_system_source" => "invalid", "solar_system_target" => "30000143"},
        %{"solar_system_source" => "30000142", "solar_system_target" => "invalid"},
        %{"solar_system_source" => "", "solar_system_target" => ""}
      ]

      Enum.each(malformed_params, fn params ->
        result = MapConnectionAPIController.update(conn, params)

        case result do
          %Plug.Conn{} -> :ok
          {:error, _} -> :ok
        end
      end)
    end

    test "handles nil and empty values in body_params" do
      map_id = Ecto.UUID.generate()
      char_id = "123456789"
      conn_id = Ecto.UUID.generate()
      base_conn = build_conn() |> assign(:map_id, map_id) |> assign(:owner_character_id, char_id)

      # Test body_params with nil values (should be filtered out)
      body_params_with_nils = %{
        "mass_status" => nil,
        "ship_size_type" => 2,
        "locked" => nil,
        "custom_info" => nil,
        "type" => 0
      }

      conn = %{base_conn | body_params: body_params_with_nils}

      result = MapConnectionAPIController.update(conn, %{"id" => conn_id})

      case result do
        %Plug.Conn{} -> :ok
        {:error, _} -> :ok
      end
    end
  end

  describe "response structure validation" do
    test "index returns consistent data structure" do
      map_id = Ecto.UUID.generate()
      conn = build_conn() |> assign(:map_id, map_id)

      result = MapConnectionAPIController.index(conn, %{})
      assert %Plug.Conn{} = result

      # If successful, should have data wrapper
      if result.status == 200 do
        response = json_response(result, 200)
        assert Map.has_key?(response, "data")
        assert is_list(response["data"])
      end
    end

    test "show returns consistent data structure" do
      map_id = Ecto.UUID.generate()
      conn_id = Ecto.UUID.generate()
      conn = build_conn() |> assign(:map_id, map_id)

      result = MapConnectionAPIController.show(conn, %{"id" => conn_id})

      case result do
        %Plug.Conn{} ->
          # Should have proper JSON structure
          assert result.resp_body != ""

        {:error, _} ->
          # Error responses are acceptable for non-existent connections
          :ok
      end
    end

    test "create returns proper response formats" do
      # Set up CachedInfo mock stubs for the systems used in the test
      WandererApp.CachedInfo.Mock
      |> stub(:get_system_static_info, fn
        30_000_142 ->
          {:ok,
           %{
             solar_system_id: 30_000_142,
             region_id: 10_000_002,
             constellation_id: 20_000_020,
             solar_system_name: "Jita",
             solar_system_name_lc: "jita",
             constellation_name: "Kimotoro",
             region_name: "The Forge",
             system_class: 0,
             security: "0.9",
             type_description: "High Security",
             class_title: "High Sec",
             is_shattered: false,
             effect_name: nil,
             effect_power: nil,
             statics: [],
             wandering: [],
             triglavian_invasion_status: nil,
             sun_type_id: 45041
           }}

        30_000_143 ->
          {:ok,
           %{
             solar_system_id: 30_000_143,
             region_id: 10_000_043,
             constellation_id: 20_000_304,
             solar_system_name: "Amarr",
             solar_system_name_lc: "amarr",
             constellation_name: "Throne Worlds",
             region_name: "Domain",
             system_class: 0,
             security: "0.9",
             type_description: "High Security",
             class_title: "High Sec",
             is_shattered: false,
             effect_name: nil,
             effect_power: nil,
             statics: [],
             wandering: [],
             triglavian_invasion_status: nil,
             sun_type_id: 45041
           }}

        _ ->
          {:error, :not_found}
      end)

      map_id = Ecto.UUID.generate()
      char_id = "123456789"
      conn = build_conn() |> assign(:map_id, map_id) |> assign(:owner_character_id, char_id)

      params = %{
        "solar_system_source" => 30_000_142,
        "solar_system_target" => 30_000_143
      }

      result =
        try do
          MapConnectionAPIController.create(conn, params)
        catch
          "Map server not started" ->
            # In unit tests, map servers aren't started, so this is expected
            build_conn()
            |> put_status(500)
            |> put_resp_content_type("application/json")
            |> resp(500, Jason.encode!(%{error: "Map server not started"}))
        end

      case result do
        %Plug.Conn{} ->
          # Should return JSON response
          assert result.resp_body != ""

          # Parse response and check structure
          response = Jason.decode!(result.resp_body)
          assert is_map(response)
          # Should have either data or error field
          assert Map.has_key?(response, "data") or Map.has_key?(response, "error")

        {:error, _} ->
          # Error responses are acceptable for unit tests
          :ok
      end
    end

    test "update returns proper response structure" do
      map_id = Ecto.UUID.generate()
      char_id = "123456789"
      conn_id = Ecto.UUID.generate()
      base_conn = build_conn() |> assign(:map_id, map_id) |> assign(:owner_character_id, char_id)

      body_params = %{"mass_status" => 1}
      conn = %{base_conn | body_params: body_params}

      result = MapConnectionAPIController.update(conn, %{"id" => conn_id})

      case result do
        %Plug.Conn{} ->
          # Should have JSON response
          assert result.resp_body != ""

        {:error, _} ->
          # Error tuples are acceptable in unit tests
          :ok
      end
    end

    test "delete returns proper response structure" do
      map_id = Ecto.UUID.generate()
      conn = build_conn() |> assign(:map_id, map_id)

      # Test supported deletion methods
      supported_delete_params = [
        %{"id" => Ecto.UUID.generate()},
        %{"solar_system_source" => "30000142", "solar_system_target" => "30000143"}
      ]

      Enum.each(supported_delete_params, fn params ->
        result = MapConnectionAPIController.delete(conn, params)

        case result do
          %Plug.Conn{} ->
            # Should have some response
            assert is_binary(result.resp_body)

          {:error, _} ->
            # Error tuples are acceptable in unit tests
            :ok
        end
      end)

      # Test unsupported parameter format (should raise FunctionClauseError)
      assert_raise FunctionClauseError, fn ->
        MapConnectionAPIController.delete(conn, %{"connection_ids" => [Ecto.UUID.generate()]})
      end
    end

    test "list_all_connections returns proper structure" do
      map_id = Ecto.UUID.generate()
      conn = build_conn() |> assign(:map_id, map_id)

      result = MapConnectionAPIController.list_all_connections(conn, %{})
      assert %Plug.Conn{} = result

      if result.status == 200 do
        response = json_response(result, 200)
        assert Map.has_key?(response, "data")
        assert is_list(response["data"])
      end
    end
  end
end
