defmodule WandererAppWeb.Helpers.APIUtilsTest do
  use WandererApp.DataCase, async: false

  alias WandererAppWeb.Helpers.APIUtils
  alias Phoenix.ConnTest

  describe "fetch_map_id/1" do
    test "returns {:ok, id} for valid UUID map_id" do
      valid_uuid = "550e8400-e29b-41d4-a716-446655440000"
      assert {:ok, ^valid_uuid} = APIUtils.fetch_map_id(%{"map_id" => valid_uuid})
    end

    test "returns error for invalid UUID format in map_id" do
      assert {:error, "Invalid UUID format for map_id: \"invalid-uuid\""} =
               APIUtils.fetch_map_id(%{"map_id" => "invalid-uuid"})
    end

    test "returns error for empty parameters" do
      assert {:error, "Must provide either ?map_id=UUID or ?slug=SLUG"} =
               APIUtils.fetch_map_id(%{})
    end

    test "returns error for unknown parameters" do
      assert {:error, "Must provide either ?map_id=UUID or ?slug=SLUG"} =
               APIUtils.fetch_map_id(%{"unknown" => "value"})
    end
  end

  describe "require_param/2" do
    test "returns {:ok, value} for present string parameter" do
      params = %{"name" => "test_value"}
      assert {:ok, "test_value"} = APIUtils.require_param(params, "name")
    end

    test "trims whitespace from string parameters" do
      params = %{"name" => "  test_value  "}
      assert {:ok, "test_value"} = APIUtils.require_param(params, "name")
    end

    test "returns error for empty string after trimming" do
      params = %{"name" => "   "}
      assert {:error, "Param name cannot be empty"} = APIUtils.require_param(params, "name")
    end

    test "returns error for missing parameter" do
      params = %{}
      assert {:error, "Missing required param: name"} = APIUtils.require_param(params, "name")
    end

    test "returns {:ok, value} for non-string values" do
      params = %{"count" => 42}
      assert {:ok, 42} = APIUtils.require_param(params, "count")
    end
  end

  describe "parse_int/1" do
    test "parses valid integer strings" do
      assert {:ok, 42} = APIUtils.parse_int("42")
      assert {:ok, -10} = APIUtils.parse_int("-10")
      assert {:ok, 0} = APIUtils.parse_int("0")
    end

    test "returns integer values unchanged" do
      assert {:ok, 42} = APIUtils.parse_int(42)
      assert {:ok, -10} = APIUtils.parse_int(-10)
    end

    test "returns error for invalid string formats" do
      assert {:error, "Invalid integer format: abc"} = APIUtils.parse_int("abc")
      assert {:error, "Invalid integer format: 42.5"} = APIUtils.parse_int("42.5")
      assert {:error, "Invalid integer format: 42 "} = APIUtils.parse_int("42 ")
    end

    test "returns error for unsupported types" do
      assert {:error, "Expected integer or string, got: 42.5"} = APIUtils.parse_int(42.5)
      assert {:error, "Expected integer or string, got: nil"} = APIUtils.parse_int(nil)
    end
  end

  describe "parse_int!/1" do
    test "returns integer for valid input" do
      assert 42 = APIUtils.parse_int!("42")
      assert 42 = APIUtils.parse_int!(42)
    end

    test "raises ArgumentError for invalid input" do
      assert_raise ArgumentError, "Invalid integer format: abc", fn ->
        APIUtils.parse_int!("abc")
      end
    end
  end

  describe "validate_uuid/1" do
    test "validates correct UUID format" do
      valid_uuid = "550e8400-e29b-41d4-a716-446655440000"
      assert {:ok, ^valid_uuid} = APIUtils.validate_uuid(valid_uuid)
    end

    test "returns error for invalid UUID format" do
      assert {:error, "Invalid UUID format: invalid-uuid"} =
               APIUtils.validate_uuid("invalid-uuid")
    end

    test "returns error for non-string input" do
      assert {:error, "ID must be a UUID string"} = APIUtils.validate_uuid(123)
      assert {:error, "ID must be a UUID string"} = APIUtils.validate_uuid(nil)
    end
  end

  describe "extract_upsert_params/1" do
    test "extracts valid parameters with solar_system_id" do
      params = %{
        "solar_system_id" => "30000142",
        "position_x" => 100,
        "position_y" => 200,
        "status" => 1,
        "visible" => true
      }

      assert {:ok, extracted} = APIUtils.extract_upsert_params(params)
      assert extracted["solar_system_id"] == "30000142"
      assert extracted["position_x"] == 100
      assert extracted["position_y"] == 200
      assert extracted["status"] == 1
      assert extracted["visible"] == true
    end

    test "filters out nil values" do
      params = %{
        "solar_system_id" => "30000142",
        "position_x" => 100,
        "position_y" => nil,
        "status" => nil
      }

      assert {:ok, extracted} = APIUtils.extract_upsert_params(params)
      assert extracted["solar_system_id"] == "30000142"
      assert extracted["position_x"] == 100
      refute Map.has_key?(extracted, "position_y")
      refute Map.has_key?(extracted, "status")
    end

    test "filters out unknown parameters" do
      params = %{
        "solar_system_id" => "30000142",
        "unknown_param" => "should_be_filtered",
        "position_x" => 100
      }

      assert {:ok, extracted} = APIUtils.extract_upsert_params(params)
      assert extracted["solar_system_id"] == "30000142"
      assert extracted["position_x"] == 100
      refute Map.has_key?(extracted, "unknown_param")
    end

    test "returns error when solar_system_id is missing" do
      params = %{"position_x" => 100}

      assert {:error, "Missing solar_system_id in request body"} =
               APIUtils.extract_upsert_params(params)
    end
  end

  describe "extract_update_params/1" do
    test "extracts allowed update parameters" do
      params = %{
        "position_x" => 100,
        "position_y" => 200,
        "status" => 1,
        "visible" => true,
        "description" => "Test system"
      }

      assert {:ok, extracted} = APIUtils.extract_update_params(params)
      assert extracted["position_x"] == 100
      assert extracted["position_y"] == 200
      assert extracted["status"] == 1
      assert extracted["visible"] == true
      assert extracted["description"] == "Test system"
    end

    test "filters out disallowed parameters" do
      params = %{
        # Not allowed in updates
        "solar_system_id" => "30000142",
        "position_x" => 100,
        "unknown_param" => "filtered"
      }

      assert {:ok, extracted} = APIUtils.extract_update_params(params)
      assert extracted["position_x"] == 100
      refute Map.has_key?(extracted, "solar_system_id")
      refute Map.has_key?(extracted, "unknown_param")
    end

    test "filters out nil values" do
      params = %{
        "position_x" => 100,
        "position_y" => nil,
        "status" => nil
      }

      assert {:ok, extracted} = APIUtils.extract_update_params(params)
      assert extracted["position_x"] == 100
      refute Map.has_key?(extracted, "position_y")
      refute Map.has_key?(extracted, "status")
    end
  end

  describe "normalize_connection_params/1" do
    test "normalizes connection parameters with required fields" do
      params = %{
        "solar_system_source" => "30000142",
        "solar_system_target" => "30000144"
      }

      assert {:ok, normalized} = APIUtils.normalize_connection_params(params)
      assert normalized["solar_system_source"] == 30_000_142
      assert normalized["solar_system_target"] == 30_000_144
      assert normalized["type"] == 0
      assert normalized["mass_status"] == 0
      assert normalized["time_status"] == 0
      assert normalized["ship_size_type"] == 0
    end

    test "handles parameter aliases" do
      params = %{
        "source" => "30000142",
        "target" => "30000144"
      }

      assert {:ok, normalized} = APIUtils.normalize_connection_params(params)
      assert normalized["solar_system_source"] == 30_000_142
      assert normalized["solar_system_target"] == 30_000_144
    end

    test "handles locked parameter normalization" do
      # Test boolean true values
      for locked_val <- [true, "true", 1, "1"] do
        params = %{
          "solar_system_source" => "30000142",
          "solar_system_target" => "30000144",
          "locked" => locked_val
        }

        assert {:ok, normalized} = APIUtils.normalize_connection_params(params)
        assert normalized["locked"] == true
      end

      # Test boolean false values  
      for locked_val <- [false, "false", 0, "0"] do
        params = %{
          "solar_system_source" => "30000142",
          "solar_system_target" => "30000144",
          "locked" => locked_val
        }

        assert {:ok, normalized} = APIUtils.normalize_connection_params(params)
        assert normalized["locked"] == false
      end
    end

    test "handles optional parameters" do
      params = %{
        "solar_system_source" => "30000142",
        "solar_system_target" => "30000144",
        "custom_info" => "test info",
        "wormhole_type" => "C1"
      }

      assert {:ok, normalized} = APIUtils.normalize_connection_params(params)
      assert normalized["custom_info"] == "test info"
      assert normalized["wormhole_type"] == "C1"
    end

    test "returns error for missing required fields" do
      params = %{"solar_system_source" => "30000142"}

      assert {:error, "Missing solar_system_target"} =
               APIUtils.normalize_connection_params(params)

      params = %{"solar_system_target" => "30000144"}

      assert {:error, "Missing solar_system_source"} =
               APIUtils.normalize_connection_params(params)
    end

    test "returns error for invalid integer formats" do
      params = %{
        "solar_system_source" => "invalid",
        "solar_system_target" => "30000144"
      }

      assert {:error, "Invalid solar_system_source: invalid"} =
               APIUtils.normalize_connection_params(params)
    end
  end

  describe "respond_data/3" do
    test "creates successful JSON response with data" do
      conn = ConnTest.build_conn()
      data = %{id: 1, name: "test"}

      result = APIUtils.respond_data(conn, data, :ok)

      assert result.status == 200
      response = Phoenix.ConnTest.json_response(result, 200)
      assert response == %{"data" => %{"id" => 1, "name" => "test"}}
    end

    test "creates JSON response with custom status" do
      conn = ConnTest.build_conn()
      data = %{id: 1}

      result = APIUtils.respond_data(conn, data, :created)

      assert result.status == 201
    end
  end

  describe "error_response/4" do
    test "creates error response with message only" do
      conn = ConnTest.build_conn()

      result = APIUtils.error_response(conn, :bad_request, "Invalid input")

      assert result.status == 400
      response = Phoenix.ConnTest.json_response(result, 400)
      assert response == %{"error" => "Invalid input"}
    end

    test "creates error response with details" do
      conn = ConnTest.build_conn()
      details = %{field: "name", issue: "required"}

      result = APIUtils.error_response(conn, :unprocessable_entity, "Validation failed", details)

      assert result.status == 422
      response = Phoenix.ConnTest.json_response(result, 422)

      assert response == %{
               "error" => "Validation failed",
               "details" => %{"field" => "name", "issue" => "required"}
             }
    end
  end

  describe "error_not_found/2" do
    test "creates 404 not found response" do
      conn = ConnTest.build_conn()

      result = APIUtils.error_not_found(conn, "Resource not found")

      assert result.status == 404
      response = Phoenix.ConnTest.json_response(result, 404)
      assert response == %{"error" => "Resource not found"}
    end
  end

  describe "format_error/1" do
    test "formats string errors as-is" do
      assert APIUtils.format_error("Error message") == "Error message"
    end

    test "formats atom errors as strings" do
      assert APIUtils.format_error(:not_found) == "not_found"
    end

    test "formats other errors with inspect" do
      assert APIUtils.format_error(%{error: "details"}) == "%{error: \"details\"}"
      assert APIUtils.format_error(123) == "123"
    end
  end

  describe "connection_to_json/1" do
    test "extracts relevant connection fields" do
      connection = %{
        id: "uuid",
        map_id: "map-uuid",
        solar_system_source: 30_000_142,
        solar_system_target: 30_000_144,
        mass_status: 1,
        time_status: 2,
        ship_size_type: 3,
        type: 0,
        wormhole_type: "C1",
        inserted_at: ~N[2024-01-01 12:00:00],
        updated_at: ~N[2024-01-01 12:00:00],
        # These should be filtered out
        extra_field: "ignored"
      }

      result = APIUtils.connection_to_json(connection)

      expected_fields = ~w(
        id map_id solar_system_source solar_system_target mass_status
        time_status ship_size_type type wormhole_type inserted_at updated_at
      )a

      assert Map.keys(result) |> Enum.sort() == expected_fields |> Enum.sort()
      assert result.id == "uuid"
      assert result.solar_system_source == 30_000_142
      refute Map.has_key?(result, :extra_field)
    end
  end
end
