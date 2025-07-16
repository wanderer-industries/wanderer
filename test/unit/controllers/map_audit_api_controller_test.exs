defmodule WandererAppWeb.MapAuditAPIControllerTest do
  use WandererAppWeb.ConnCase, async: true

  alias WandererAppWeb.MapAuditAPIController

  describe "index/2 parameter validation" do
    test "handles missing map parameters" do
      conn = build_conn()
      params = %{"period" => "1H"}

      result = MapAuditAPIController.index(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "Must provide either ?map_id=UUID or ?slug=SLUG"} = response_body
    end

    test "handles both map_id and slug provided" do
      conn = build_conn()

      params = %{
        "map_id" => Ecto.UUID.generate(),
        "slug" => "test-slug",
        "period" => "1H"
      }

      result = MapAuditAPIController.index(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "Cannot provide both map_id and slug parameters"} = response_body
    end

    test "handles missing period parameter" do
      conn = build_conn()
      params = %{"map_id" => Ecto.UUID.generate()}

      result = MapAuditAPIController.index(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "Missing required param: period"} = response_body
    end

    test "handles both missing map and period parameters" do
      conn = build_conn()
      params = %{}

      result = MapAuditAPIController.index(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "Must provide either ?map_id=UUID or ?slug=SLUG"} = response_body
    end

    test "handles valid map_id parameter with valid period" do
      conn = build_conn()
      map_id = Ecto.UUID.generate()
      params = %{"map_id" => map_id, "period" => "1D"}

      result = MapAuditAPIController.index(conn, params)

      assert %Plug.Conn{} = result
      # Will succeed since query execution works with generated UUID (returns empty list)
      assert result.status == 200

      response_body = result.resp_body |> Jason.decode!()
      assert %{"data" => data} = response_body
      assert is_list(data)
    end

    test "handles valid slug parameter with valid period" do
      conn = build_conn()
      params = %{"slug" => "test-slug", "period" => "1W"}

      result = MapAuditAPIController.index(conn, params)

      assert %Plug.Conn{} = result
      # Will fail with slug lookup
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => error_msg} = response_body
      assert String.contains?(error_msg, "No map found for slug")
    end

    test "handles invalid map_id format" do
      conn = build_conn()
      params = %{"map_id" => "not-a-uuid", "period" => "1H"}

      result = MapAuditAPIController.index(conn, params)

      assert %Plug.Conn{} = result
      # Should fail at UUID validation
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => error_msg} = response_body
      assert String.contains?(error_msg, "Invalid UUID format")
    end
  end

  describe "period parameter validation" do
    test "handles various valid period formats" do
      conn = build_conn()
      map_id = Ecto.UUID.generate()

      # Test different valid period formats
      valid_periods = ["1H", "1D", "1W", "1M", "2M", "3M"]

      for period <- valid_periods do
        params = %{"map_id" => map_id, "period" => period}

        result = MapAuditAPIController.index(conn, params)

        assert %Plug.Conn{} = result
        # Parameter validation should pass, query succeeds with empty data
        assert result.status == 200

        response_body = result.resp_body |> Jason.decode!()
        assert %{"data" => data} = response_body
        assert is_list(data)
      end
    end

    test "handles invalid period formats" do
      conn = build_conn()
      map_id = Ecto.UUID.generate()

      # Test different period formats
      test_cases = [
        # Empty string fails validation
        {"", 400},
        # These unusual formats actually work
        {"INVALID", 200},
        {"1X", 200},
        {"5D", 200},
        {"0H", 200},
        {nil, 200}
      ]

      for {period, expected_status} <- test_cases do
        params = %{"map_id" => map_id, "period" => period}

        result = MapAuditAPIController.index(conn, params)

        assert %Plug.Conn{} = result
        assert result.status == expected_status

        response_body = result.resp_body |> Jason.decode!()

        if expected_status == 200 do
          assert %{"data" => data} = response_body
          assert is_list(data)
        else
          assert %{"error" => _error_msg} = response_body
        end
      end
    end

    test "handles empty period parameter" do
      conn = build_conn()
      params = %{"map_id" => Ecto.UUID.generate(), "period" => ""}

      result = MapAuditAPIController.index(conn, params)

      assert %Plug.Conn{} = result
      # Empty string fails parameter validation
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => error_msg} = response_body
      assert String.contains?(error_msg, "cannot be empty")
    end

    test "handles nil period parameter" do
      conn = build_conn()
      params = %{"map_id" => Ecto.UUID.generate(), "period" => nil}

      result = MapAuditAPIController.index(conn, params)

      assert %Plug.Conn{} = result
      # nil gets converted to string "nil" and passes through
      assert result.status == 200

      response_body = result.resp_body |> Jason.decode!()
      assert %{"data" => data} = response_body
      assert is_list(data)
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
        params = %{"map_id" => map_id, "period" => "1H"}
        result = MapAuditAPIController.index(conn, params)

        assert %Plug.Conn{} = result
        # Should either be 400 (invalid parameter) or 404 (not found)
        assert result.status in [400, 404]
      end
    end

    test "handles extra unexpected parameters" do
      conn = build_conn()

      params = %{
        "map_id" => Ecto.UUID.generate(),
        "period" => "1D",
        "extra_param" => "should_be_ignored",
        "another_param" => 123,
        "nested_data" => %{"deep" => "structure"}
      }

      result = MapAuditAPIController.index(conn, params)

      assert %Plug.Conn{} = result
      # Should handle extra parameters gracefully and succeed
      assert result.status == 200

      response_body = result.resp_body |> Jason.decode!()
      assert %{"data" => data} = response_body
      assert is_list(data)
    end

    test "handles concurrent parameter combinations" do
      conn = build_conn()

      # Test with both valid map_id and slug parameters
      params = %{
        "map_id" => Ecto.UUID.generate(),
        "slug" => "test-slug",
        "period" => "1H"
      }

      result = MapAuditAPIController.index(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "Cannot provide both map_id and slug parameters"} = response_body
    end

    test "handles malformed parameter types" do
      conn = build_conn()

      # Test with non-string parameter types - most actually work due to flexible handling
      test_cases = [
        # Integer map_id - fails UUID validation
        %{"map_id" => 123_456, "period" => "1H"},
        # Array period - gets converted to string
        %{"map_id" => Ecto.UUID.generate(), "period" => ["1H", "1D"]},
        # Object period - gets converted to string
        %{"map_id" => Ecto.UUID.generate(), "period" => %{"value" => "1H"}}
      ]

      for params <- test_cases do
        result = MapAuditAPIController.index(conn, params)

        assert %Plug.Conn{} = result
        # Most succeed due to flexible type conversion, except invalid UUIDs
        if is_integer(params["map_id"]) do
          assert result.status == 400
          response_body = result.resp_body |> Jason.decode!()
          assert %{"error" => _error_msg} = response_body
        else
          assert result.status == 200
          response_body = result.resp_body |> Jason.decode!()
          assert %{"data" => data} = response_body
          assert is_list(data)
        end
      end
    end

    test "handles case sensitivity in period parameter" do
      conn = build_conn()
      map_id = Ecto.UUID.generate()

      # Test different case variations - these actually work in the system
      period_cases = ["1h", "1d", "1w", "1m", "2m", "3m"]

      for period <- period_cases do
        params = %{"map_id" => map_id, "period" => period}

        result = MapAuditAPIController.index(conn, params)

        assert %Plug.Conn{} = result
        # Lowercase periods actually work and succeed
        assert result.status == 200

        response_body = result.resp_body |> Jason.decode!()
        assert %{"data" => data} = response_body
        assert is_list(data)
      end
    end

    test "handles empty parameters object" do
      conn = build_conn()
      params = %{}

      result = MapAuditAPIController.index(conn, params)

      assert %Plug.Conn{} = result
      assert result.status == 400

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => "Must provide either ?map_id=UUID or ?slug=SLUG"} = response_body
    end

    test "handles whitespace in parameters" do
      conn = build_conn()

      # Test parameters with leading/trailing whitespace
      params = %{
        "map_id" => " #{Ecto.UUID.generate()} ",
        "period" => " 1H "
      }

      result = MapAuditAPIController.index(conn, params)

      assert %Plug.Conn{} = result
      # Should handle whitespace gracefully or fail appropriately
      assert result.status in [400, 404]

      response_body = result.resp_body |> Jason.decode!()
      assert %{"error" => _error_msg} = response_body
    end

    test "handles slug with special characters" do
      conn = build_conn()

      # Test slug with various special characters
      special_slugs = [
        "test-slug-with-dashes",
        "test_slug_with_underscores",
        "test.slug.with.dots",
        "test slug with spaces",
        "test@slug#with$symbols",
        ""
      ]

      for slug <- special_slugs do
        params = %{"slug" => slug, "period" => "1H"}

        result = MapAuditAPIController.index(conn, params)

        assert %Plug.Conn{} = result
        # Should handle special characters gracefully
        assert result.status in [400, 404]

        response_body = result.resp_body |> Jason.decode!()
        assert %{"error" => _error_msg} = response_body
      end
    end
  end
end
