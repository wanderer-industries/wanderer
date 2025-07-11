# Standalone test for the UtilAPIController
#
# This file can be run directly with:
#   elixir test/standalone/util_api_controller_test.exs
#
# It doesn't require any database connections or external dependencies.

# Start ExUnit
ExUnit.start()

defmodule UtilAPIControllerTest do
  use ExUnit.Case

  # Mock controller that implements the functions we want to test
  defmodule MockUtilAPIController do
    # Simplified version of fetch_map_id from UtilAPIController
    def fetch_map_id(params) do
      cond do
        params["map_id"] ->
          case Integer.parse(params["map_id"]) do
            {map_id, ""} -> {:ok, map_id}
            _ -> {:error, "Invalid map_id format"}
          end

        params["slug"] ->
          # In a real app, this would look up the map by slug
          # For testing, we'll just use a simple mapping
          case params["slug"] do
            "test-map" -> {:ok, 1}
            "another-map" -> {:ok, 2}
            _ -> {:error, "Map not found"}
          end

        true ->
          {:error, "Missing required param: map_id or slug"}
      end
    end

    # Simplified version of require_param from UtilAPIController
    def require_param(params, key) do
      case params[key] do
        nil -> {:error, "Missing required param: #{key}"}
        "" -> {:error, "Param #{key} cannot be empty"}
        val -> {:ok, val}
      end
    end

    # Simplified version of parse_int from UtilAPIController
    def parse_int(str) do
      case Integer.parse(str) do
        {num, ""} -> {:ok, num}
        _ -> {:error, "Invalid integer for param id=#{str}"}
      end
    end
  end

  describe "fetch_map_id/1" do
    test "returns map_id when valid map_id is provided" do
      params = %{"map_id" => "123"}
      result = MockUtilAPIController.fetch_map_id(params)

      assert {:ok, 123} = result
    end

    test "returns map_id when valid slug is provided" do
      params = %{"slug" => "test-map"}
      result = MockUtilAPIController.fetch_map_id(params)

      assert {:ok, 1} = result
    end

    test "returns error when map_id is invalid format" do
      params = %{"map_id" => "not-a-number"}
      result = MockUtilAPIController.fetch_map_id(params)

      assert {:error, "Invalid map_id format"} = result
    end

    test "returns error when slug is not found" do
      params = %{"slug" => "non-existent-map"}
      result = MockUtilAPIController.fetch_map_id(params)

      assert {:error, "Map not found"} = result
    end

    test "returns error when neither map_id nor slug is provided" do
      params = %{}
      result = MockUtilAPIController.fetch_map_id(params)

      assert {:error, "Missing required param: map_id or slug"} = result
    end

    test "prioritizes map_id over slug when both are provided" do
      params = %{"map_id" => "123", "slug" => "test-map"}
      result = MockUtilAPIController.fetch_map_id(params)

      assert {:ok, 123} = result
    end
  end

  describe "require_param/2" do
    test "returns value when param exists" do
      params = %{"key" => "value"}
      result = MockUtilAPIController.require_param(params, "key")

      assert {:ok, "value"} = result
    end

    test "returns error when param is missing" do
      params = %{}
      result = MockUtilAPIController.require_param(params, "key")

      assert {:error, "Missing required param: key"} = result
    end

    test "returns error when param is empty string" do
      params = %{"key" => ""}
      result = MockUtilAPIController.require_param(params, "key")

      assert {:error, "Param key cannot be empty"} = result
    end
  end

  describe "parse_int/1" do
    test "returns integer when string is valid integer" do
      result = MockUtilAPIController.parse_int("123")

      assert {:ok, 123} = result
    end

    test "returns error when string is not a valid integer" do
      result = MockUtilAPIController.parse_int("not-an-integer")

      assert {:error, message} = result
      assert message =~ "Invalid integer for param id"
    end

    test "returns error when string contains integer with extra characters" do
      result = MockUtilAPIController.parse_int("123abc")

      assert {:error, message} = result
      assert message =~ "Invalid integer for param id"
    end
  end
end
