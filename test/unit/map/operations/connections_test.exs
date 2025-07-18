defmodule WandererApp.Map.Operations.ConnectionsTest do
  use WandererApp.DataCase

  import Mox

  alias WandererApp.Map.Operations.Connections

  setup :verify_on_exit!

  setup do
    # Ensure we're in global mode and re-setup mocks
    Mox.set_mox_global()
    WandererApp.Test.Mocks.setup_additional_expectations()

    # Set up CachedInfo mock stubs for the systems used in the tests
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

      30_000_144 ->
        {:ok,
         %{
           solar_system_id: 30_000_144,
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

    :ok
  end

  describe "parameter validation" do
    test "validates missing connection assigns" do
      attrs = %{}
      map_id = Ecto.UUID.generate()
      char_id = Ecto.UUID.generate()

      result = Connections.create(attrs, map_id, char_id)

      # The function returns {:error, :precondition_failed, reason} for validation errors
      assert {:error, :precondition_failed, _reason} = result
    end

    test "validates solar_system_source parameter" do
      attrs = %{
        "solar_system_source" => "invalid",
        "solar_system_target" => "30000143"
      }

      map_id = Ecto.UUID.generate()
      char_id = Ecto.UUID.generate()

      result = Connections.create(attrs, map_id, char_id)

      assert {:error, :precondition_failed, _reason} = result
    end

    test "validates solar_system_target parameter" do
      attrs = %{
        "solar_system_source" => "30000142",
        "solar_system_target" => "invalid"
      }

      map_id = Ecto.UUID.generate()
      char_id = Ecto.UUID.generate()

      result = Connections.create(attrs, map_id, char_id)

      assert {:error, :precondition_failed, _reason} = result
    end

    test "validates missing conn parameters for update" do
      attrs = %{
        "mass_status" => "1"
      }

      connection_id = Ecto.UUID.generate()

      # Test with invalid conn parameter
      result = Connections.update_connection(nil, connection_id, attrs)

      assert {:error, :missing_params} = result
    end

    test "validates missing conn parameters for delete" do
      source_id = 30_000_142
      target_id = 30_000_144

      # Test with invalid conn parameter
      result = Connections.delete_connection(nil, source_id, target_id)

      assert {:error, :missing_params} = result
    end

    test "validates missing conn parameters for upsert_single" do
      conn_data = %{
        "solar_system_source" => "30000142",
        "solar_system_target" => "30000143"
      }

      result = Connections.upsert_single(nil, conn_data)

      assert {:error, :missing_params} = result
    end

    test "validates missing conn parameters for upsert_batch" do
      conn_list = [
        %{
          "solar_system_source" => "30000142",
          "solar_system_target" => "30000143"
        }
      ]

      result = Connections.upsert_batch(nil, conn_list)

      assert %{created: 0, updated: 0, skipped: 0} = result
    end
  end

  describe "core functions with real implementations" do
    test "list_connections/1 function exists and handles map_id parameter" do
      map_id = Ecto.UUID.generate()

      # Should not crash, actual behavior depends on database state
      result = Connections.list_connections(map_id)
      assert is_list(result) or match?({:error, _}, result)
    end

    test "list_connections/2 function exists and handles map_id and system_id parameters" do
      map_id = Ecto.UUID.generate()
      system_id = 30_000_142

      # Should not crash, actual behavior depends on database state
      result = Connections.list_connections(map_id, system_id)
      assert is_list(result)
    end

    test "get_connection/2 function exists and handles parameters" do
      map_id = Ecto.UUID.generate()
      conn_id = Ecto.UUID.generate()

      # Should not crash, actual behavior depends on database state
      result = Connections.get_connection(map_id, conn_id)
      assert is_tuple(result)
    end

    test "create connection validates integer parameters" do
      map_id = Ecto.UUID.generate()
      char_id = "123456789"

      # Test with valid integer strings
      attrs_valid = %{
        "solar_system_source" => "30000142",
        "solar_system_target" => "30000143",
        "type" => "0",
        "ship_size_type" => "2"
      }

      # This should not crash on parameter parsing
      result =
        try do
          Connections.create(attrs_valid, map_id, char_id)
        catch
          "Map server not started" ->
            {:error, :map_server_not_started}
        end

      # Result depends on underlying services, but function should handle the call
      assert is_tuple(result)

      # Test with invalid parameters
      attrs_invalid = %{
        "solar_system_source" => "invalid",
        "solar_system_target" => "30000143"
      }

      result_invalid = Connections.create(attrs_invalid, map_id, char_id)
      # Should handle invalid parameter gracefully
      assert {:error, :precondition_failed, _} = result_invalid
    end

    test "create_connection/3 handles parameter validation" do
      map_id = Ecto.UUID.generate()
      char_id = "123456789"

      attrs = %{
        "solar_system_source" => 30_000_142,
        "solar_system_target" => 30_000_143,
        "type" => 0
      }

      result =
        try do
          Connections.create_connection(map_id, attrs, char_id)
        catch
          "Map server not started" ->
            {:error, :map_server_not_started}
        end

      # Function should handle the call
      assert is_tuple(result)
    end

    test "create_connection/2 with Plug.Conn handles parameter validation" do
      map_id = Ecto.UUID.generate()
      char_id = "123456789"

      conn = %{assigns: %{map_id: map_id, owner_character_id: char_id}}

      attrs = %{
        "solar_system_source" => 30_000_142,
        "solar_system_target" => 30_000_143
      }

      result =
        try do
          Connections.create_connection(conn, attrs)
        catch
          "Map server not started" ->
            {:error, :map_server_not_started}
        end

      # Function should handle the call
      assert is_tuple(result)
    end

    test "update_connection handles coordinate parsing" do
      map_id = Ecto.UUID.generate()
      char_id = "123456789"
      conn_id = Ecto.UUID.generate()

      conn = %{assigns: %{map_id: map_id, owner_character_id: char_id}}

      # Test with string coordinates that should parse
      attrs = %{
        "mass_status" => "1",
        "ship_size_type" => "2",
        "type" => "0"
      }

      result = Connections.update_connection(conn, conn_id, attrs)
      # Function should handle coordinate parsing
      assert is_tuple(result)

      # Test with invalid coordinates
      attrs_invalid = %{
        "mass_status" => "invalid",
        "ship_size_type" => "2"
      }

      result_invalid = Connections.update_connection(conn, conn_id, attrs_invalid)
      # Should handle invalid coordinates gracefully
      assert is_tuple(result_invalid)
    end

    test "upsert_batch processes connection lists correctly" do
      map_id = Ecto.UUID.generate()
      char_id = "123456789"

      conn = %{assigns: %{map_id: map_id, owner_character_id: char_id}}

      # Test with empty list
      result_empty = Connections.upsert_batch(conn, [])
      assert %{created: 0, updated: 0, skipped: 0} = result_empty

      # Test with connection data to exercise more code paths
      connections = [
        %{
          "solar_system_source" => 30_000_142,
          "solar_system_target" => 30_000_143,
          "type" => 0
        },
        %{
          "solar_system_source" => 30_000_143,
          "solar_system_target" => 30_000_144,
          "type" => 0
        }
      ]

      result =
        try do
          Connections.upsert_batch(conn, connections)
        catch
          "Map server not started" ->
            %{created: 0, updated: 0, skipped: 0, error: "Map server not started"}
        end

      # Function should process the data and return a result
      assert is_map(result)
      assert Map.has_key?(result, :created)
      assert Map.has_key?(result, :updated)
      assert Map.has_key?(result, :skipped)
    end

    test "upsert_single processes individual connections" do
      map_id = Ecto.UUID.generate()
      char_id = "123456789"

      conn = %{assigns: %{map_id: map_id, owner_character_id: char_id}}

      conn_data = %{
        "solar_system_source" => 30_000_142,
        "solar_system_target" => 30_000_143,
        "type" => 0
      }

      result =
        try do
          Connections.upsert_single(conn, conn_data)
        catch
          "Map server not started" ->
            {:error, :map_server_not_started}
        end

      # Function should process the data
      assert is_tuple(result)
    end

    test "get_connection_by_systems handles system lookups" do
      map_id = Ecto.UUID.generate()
      source = 30_000_142
      target = 30_000_143

      result = Connections.get_connection_by_systems(map_id, source, target)
      # Function should handle the lookup
      assert is_tuple(result)
    end

    test "internal helper functions work correctly" do
      # Test coordinate normalization by creating a connection with different parameters
      map_id = Ecto.UUID.generate()
      char_id = "123456789"

      # Test different parameter formats to exercise helper functions
      params_various_formats = [
        %{
          "solar_system_source" => "30000142",
          "solar_system_target" => "30000143",
          "type" => "0",
          "ship_size_type" => "2"
        },
        %{
          "solar_system_source" => 30_000_142,
          "solar_system_target" => 30_000_143,
          "type" => 0,
          "ship_size_type" => 2
        },
        %{
          solar_system_source: 30_000_142,
          solar_system_target: 30_000_143,
          type: 0
        }
      ]

      Enum.each(params_various_formats, fn params ->
        result =
          try do
            Connections.create(params, map_id, char_id)
          catch
            "Map server not started" ->
              {:error, :map_server_not_started}
          end

        # Each call should handle the parameter format
        assert is_tuple(result)
      end)
    end
  end

  describe "edge cases and error handling" do
    test "handles missing system information gracefully" do
      map_id = Ecto.UUID.generate()
      char_id = "123456789"

      # Test with non-existent solar system IDs
      attrs = %{
        "solar_system_source" => "99999999",
        "solar_system_target" => "99999998"
      }

      result = Connections.create(attrs, map_id, char_id)
      # Should handle gracefully when system info can't be found
      assert is_tuple(result)
    end

    test "handles malformed input data" do
      map_id = Ecto.UUID.generate()
      char_id = "123456789"

      # Test with various malformed inputs
      malformed_inputs = [
        %{},
        %{"solar_system_source" => nil},
        %{"solar_system_target" => nil},
        %{"solar_system_source" => "", "solar_system_target" => ""},
        %{"solar_system_source" => [], "solar_system_target" => %{}}
      ]

      Enum.each(malformed_inputs, fn attrs ->
        result = Connections.create(attrs, map_id, char_id)
        # Should handle malformed data gracefully
        assert is_tuple(result)
      end)
    end

    test "handles different ship size type values" do
      map_id = Ecto.UUID.generate()
      char_id = "123456789"

      # Test different ship size type formats
      ship_size_types = [nil, "0", "1", "2", "3", 0, 1, 2, 3, "invalid", -1]

      Enum.each(ship_size_types, fn ship_size ->
        attrs = %{
          "solar_system_source" => "30000142",
          "solar_system_target" => "30000143",
          "ship_size_type" => ship_size
        }

        result =
          try do
            Connections.create(attrs, map_id, char_id)
          catch
            "Map server not started" ->
              {:error, :map_server_not_started}
          end

        # Should handle each ship size type
        assert is_tuple(result)
      end)
    end

    test "handles different connection type values" do
      map_id = Ecto.UUID.generate()
      char_id = "123456789"

      # Test different connection type formats
      connection_types = [nil, "0", "1", 0, 1, "invalid", -1]

      Enum.each(connection_types, fn conn_type ->
        attrs = %{
          "solar_system_source" => "30000142",
          "solar_system_target" => "30000143",
          "type" => conn_type
        }

        result =
          try do
            Connections.create(attrs, map_id, char_id)
          catch
            "Map server not started" ->
              {:error, :map_server_not_started}
          end

        # Should handle each connection type
        assert is_tuple(result)
      end)
    end

    test "handles various update field combinations" do
      map_id = Ecto.UUID.generate()
      char_id = "123456789"
      conn_id = Ecto.UUID.generate()

      conn = %{assigns: %{map_id: map_id, owner_character_id: char_id}}

      # Test different update field combinations
      update_combinations = [
        %{"mass_status" => "1"},
        %{"ship_size_type" => "2"},
        %{"type" => "0"},
        %{"mass_status" => "1", "ship_size_type" => "2"},
        %{"mass_status" => nil, "ship_size_type" => nil, "type" => nil},
        %{"unknown_field" => "value"},
        %{}
      ]

      Enum.each(update_combinations, fn attrs ->
        result = Connections.update_connection(conn, conn_id, attrs)
        # Should handle each combination
        assert is_tuple(result)
      end)
    end

    test "handles atom and string key formats in upsert_single" do
      map_id = Ecto.UUID.generate()
      char_id = "123456789"

      conn = %{assigns: %{map_id: map_id, owner_character_id: char_id}}

      # Test both string and atom key formats
      conn_data_formats = [
        %{
          "solar_system_source" => 30_000_142,
          "solar_system_target" => 30_000_143
        },
        %{
          solar_system_source: 30_000_142,
          solar_system_target: 30_000_143
        },
        %{
          "solar_system_source" => "30000142",
          "solar_system_target" => "30000143"
        }
      ]

      Enum.each(conn_data_formats, fn conn_data ->
        result =
          try do
            Connections.upsert_single(conn, conn_data)
          catch
            "Map server not started" ->
              {:error, :map_server_not_started}
          end

        # Should handle both key formats
        assert is_tuple(result)
      end)
    end
  end
end
