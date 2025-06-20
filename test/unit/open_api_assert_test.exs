defmodule WandererApp.OpenApiAssertTest do
  use WandererApp.DataCase

  @moduletag :unit

  alias WandererApp.Test.OpenApiAssert

  describe "OpenAPI validation helpers" do
    test "assert_request_valid! succeeds with valid parameters" do
      # Mock operation with proper OpenApiSpex parameter structure
      operation = %{
        parameters: [
          %OpenApiSpex.Parameter{
            name: "id",
            in: :path,
            required: true,
            schema: %OpenApiSpex.Schema{type: :string}
          }
        ]
      }

      params = %{
        path: %{"id" => "123"},
        query: %{},
        body: nil
      }

      # Should not raise an error
      assert :ok = OpenApiAssert.assert_request_valid!(operation, params)
    end

    test "assert_request_valid! fails with missing required parameter" do
      # Mock operation with required parameter
      operation = %{
        parameters: [
          %OpenApiSpex.Parameter{
            name: "id",
            in: :path,
            required: true,
            schema: %OpenApiSpex.Schema{type: :string}
          }
        ]
      }

      params = %{
        # Missing required "id" parameter
        path: %{},
        query: %{},
        body: nil
      }

      # Should raise an assertion error
      assert_raise ExUnit.AssertionError, ~r/Request validation failed/, fn ->
        OpenApiAssert.assert_request_valid!(operation, params)
      end
    end

    test "get_operation_from_conn returns nil for unknown paths" do
      # Mock a simple conn
      conn = %Plug.Conn{
        method: "GET",
        request_path: "/unknown/path",
        private: %{}
      }

      # Should handle unknown paths gracefully
      assert is_nil(OpenApiAssert.get_operation_from_conn(conn))
    end
  end
end
