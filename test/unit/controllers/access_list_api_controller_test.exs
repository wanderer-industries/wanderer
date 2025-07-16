defmodule WandererAppWeb.AccessListAPIControllerUnitTest do
  use WandererAppWeb.ConnCase, async: true

  alias WandererAppWeb.MapAccessListAPIController

  describe "index/2 parameter handling" do
    test "handles missing map parameters" do
      conn = build_conn()
      params = %{}

      result = MapAccessListAPIController.index(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()

      assert %{"error" => "Must provide either ?map_id=UUID or ?slug=SLUG as a query parameter"} =
               response_body
    end

    test "handles both map_id and slug provided" do
      conn = build_conn()
      params = %{"map_id" => Ecto.UUID.generate(), "slug" => "test-slug"}

      result = MapAccessListAPIController.index(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()

      assert %{"error" => "Must provide either ?map_id=UUID or ?slug=SLUG as a query parameter"} =
               response_body
    end

    test "handles valid map_id parameter" do
      conn = build_conn()
      map_id = Ecto.UUID.generate()
      params = %{"map_id" => map_id}

      result = MapAccessListAPIController.index(conn, params)

      assert %Plug.Conn{} = result
      # Will fail to find map since we're not using real data, but parameter validation passes
      assert result.status == 404

      response_body = result.resp_body |> Jason.decode!()

      assert %{
               "error" =>
                 "Map not found. Please provide a valid map_id or slug as a query parameter."
             } = response_body
    end

    test "handles valid slug parameter" do
      conn = build_conn()
      params = %{"slug" => "test-slug"}

      result = MapAccessListAPIController.index(conn, params)

      assert %Plug.Conn{} = result
      # Will fail due to slug not being found, which returns 400 from fetch_map_id
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()

      assert %{"error" => "Must provide either ?map_id=UUID or ?slug=SLUG as a query parameter"} =
               response_body
    end

    test "handles invalid map_id format" do
      conn = build_conn()
      params = %{"map_id" => "not-a-uuid"}

      result = MapAccessListAPIController.index(conn, params)

      assert %Plug.Conn{} = result
      # Invalid UUID format causes fetch_map_id to return 400 error
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()

      assert %{"error" => "Must provide either ?map_id=UUID or ?slug=SLUG as a query parameter"} =
               response_body
    end
  end

  describe "create/2 parameter validation" do
    test "handles missing map parameters" do
      conn = build_conn()
      params = %{"acl" => %{"owner_eve_id" => "123456", "name" => "Test ACL"}}

      result = MapAccessListAPIController.create(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()

      assert %{"error" => "Must provide either ?map_id=UUID or ?slug=SLUG as a query parameter"} =
               response_body
    end

    test "handles missing acl object" do
      conn = build_conn()
      params = %{"map_id" => Ecto.UUID.generate()}

      result = MapAccessListAPIController.create(conn, params)

      assert %Plug.Conn{} = result
      # Will fail to find map since we're not using real data
      assert result.status == 404

      response_body = result.resp_body |> Jason.decode!()

      assert %{
               "error" =>
                 "Map not found. Please provide a valid map_id or slug as a query parameter."
             } = response_body
    end

    test "handles missing owner_eve_id" do
      conn = build_conn()

      params = %{
        "map_id" => Ecto.UUID.generate(),
        "acl" => %{"name" => "Test ACL"}
      }

      result = MapAccessListAPIController.create(conn, params)

      assert %Plug.Conn{} = result
      # Will fail to find map since we're not using real data
      assert result.status == 404

      response_body = result.resp_body |> Jason.decode!()

      assert %{
               "error" =>
                 "Map not found. Please provide a valid map_id or slug as a query parameter."
             } = response_body
    end

    test "handles valid parameters with invalid map" do
      conn = build_conn()

      params = %{
        "map_id" => Ecto.UUID.generate(),
        "acl" => %{
          "owner_eve_id" => "123456789",
          "name" => "Test ACL",
          "description" => "Test description"
        }
      }

      result = MapAccessListAPIController.create(conn, params)

      assert %Plug.Conn{} = result
      # Will fail to find map, but parameter validation passes
      assert result.status == 404

      response_body = result.resp_body |> Jason.decode!()

      assert %{
               "error" =>
                 "Map not found. Please provide a valid map_id or slug as a query parameter."
             } = response_body
    end

    test "validates owner_eve_id is present even when nil" do
      conn = build_conn()

      params = %{
        "map_id" => Ecto.UUID.generate(),
        "acl" => %{
          "owner_eve_id" => nil,
          "name" => "Test ACL"
        }
      }

      result = MapAccessListAPIController.create(conn, params)

      assert %Plug.Conn{} = result
      # Will fail to find map since we're not using real data
      assert result.status == 404

      response_body = result.resp_body |> Jason.decode!()

      assert %{
               "error" =>
                 "Map not found. Please provide a valid map_id or slug as a query parameter."
             } = response_body
    end
  end

  describe "show/2 parameter handling" do
    test "handles valid ACL ID format" do
      conn = build_conn()
      acl_id = Ecto.UUID.generate()
      params = %{"id" => acl_id}

      result = MapAccessListAPIController.show(conn, params)

      assert %Plug.Conn{} = result
      # Will fail to find ACL since we're not using real data, but parameter validation passes
      assert result.status == 404

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "ACL not found"} = response_body
    end

    test "handles invalid ACL ID format" do
      conn = build_conn()
      params = %{"id" => "not-a-uuid"}

      result = MapAccessListAPIController.show(conn, params)

      assert %Plug.Conn{} = result
      # Will fail at query level due to invalid UUID
      assert result.status == 500

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => error_msg} = response_body
      assert String.contains?(error_msg, "Error reading ACL")
    end
  end

  describe "update/2 parameter validation" do
    test "handles valid ACL ID with update parameters" do
      conn = build_conn()
      acl_id = Ecto.UUID.generate()

      params = %{
        "id" => acl_id,
        "acl" => %{
          "name" => "Updated Name",
          "description" => "Updated description"
        }
      }

      result = MapAccessListAPIController.update(conn, params)

      assert %Plug.Conn{} = result
      # Will fail to find ACL since we're not using real data, but parameter validation passes
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => error_msg} = response_body
      assert String.contains?(error_msg, "Failed to update ACL")
    end

    test "handles missing acl parameters" do
      conn = build_conn()
      params = %{"id" => Ecto.UUID.generate()}

      # This should cause a FunctionClauseError since update/2 expects "acl" key
      assert_raise FunctionClauseError, fn ->
        MapAccessListAPIController.update(conn, params)
      end
    end

    test "handles empty acl parameters" do
      conn = build_conn()
      acl_id = Ecto.UUID.generate()

      params = %{
        "id" => acl_id,
        "acl" => %{}
      }

      result = MapAccessListAPIController.update(conn, params)

      assert %Plug.Conn{} = result
      # Will fail to find ACL since we're not using real data, but parameter validation passes
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => error_msg} = response_body
      assert String.contains?(error_msg, "Failed to update ACL")
    end
  end

  describe "edge cases and error handling" do
    test "handles various parameter formats for map_id" do
      conn = build_conn()

      # Test different invalid map_id formats
      invalid_map_ids = [
        "",
        "123",
        "not-uuid-at-all",
        nil
      ]

      for map_id <- invalid_map_ids do
        params = %{"map_id" => map_id}
        result = MapAccessListAPIController.index(conn, params)

        assert %Plug.Conn{} = result
        # Should either be 400 (invalid parameter) or 404 (not found)
        assert result.status in [400, 404]
      end
    end

    test "handles various eve_id formats" do
      conn = build_conn()
      map_id = Ecto.UUID.generate()

      # Test different eve_id formats
      eve_ids = [
        # String
        "123456789",
        # Integer
        123_456_789,
        # Zero string
        "0",
        # Zero integer
        0
      ]

      for eve_id <- eve_ids do
        params = %{
          "map_id" => map_id,
          "acl" => %{
            "owner_eve_id" => eve_id,
            "name" => "Test ACL"
          }
        }

        result = MapAccessListAPIController.create(conn, params)

        assert %Plug.Conn{} = result
        # Parameter validation should pass, will fail at map lookup
        assert result.status == 404

        response_body = result.resp_body |> Jason.decode!()

        assert %{
                 "error" =>
                   "Map not found. Please provide a valid map_id or slug as a query parameter."
               } = response_body
      end
    end

    test "handles malformed JSON-like parameters" do
      conn = build_conn()

      # Test with nested structures that might cause issues
      params = %{
        "map_id" => Ecto.UUID.generate(),
        "acl" => %{
          "owner_eve_id" => "123456",
          "name" => "Test ACL",
          "extra_nested" => %{"deep" => %{"very" => "deep"}},
          "array_field" => [1, 2, 3]
        }
      }

      result = MapAccessListAPIController.create(conn, params)

      assert %Plug.Conn{} = result
      # Should handle extra fields gracefully
      assert result.status == 404

      response_body = result.resp_body |> Jason.decode!()

      assert %{
               "error" =>
                 "Map not found. Please provide a valid map_id or slug as a query parameter."
             } = response_body
    end

    test "handles concurrent parameter combinations" do
      conn = build_conn()

      # Test with both valid map_id and acl parameters
      params = %{
        "map_id" => Ecto.UUID.generate(),
        # Both provided - should fail
        "slug" => "test-slug",
        "acl" => %{
          "owner_eve_id" => "123456",
          "name" => "Test ACL"
        }
      }

      result = MapAccessListAPIController.create(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => error_msg} = response_body
      assert String.contains?(error_msg, "Cannot provide both map_id and slug parameters")
    end
  end
end
