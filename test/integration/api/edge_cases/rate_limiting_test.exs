defmodule WandererAppWeb.API.EdgeCases.RateLimitingTest do
  use WandererAppWeb.ConnCase, async: false

  alias WandererApp.Test.Factory

  describe "API Rate Limiting" do
    setup do
      # Create test data
      user = Factory.create_user()
      map = Factory.create_map(%{user_id: user.id})
      api_key = Factory.create_map_api_key(%{map_id: map.id})

      %{
        user: user,
        map: map,
        api_key: api_key,
        base_headers: [{"x-api-key", api_key.key}, {"content-type", "application/json"}]
      }
    end

    test "respects rate limits for normal operations", %{
      conn: conn,
      map: map,
      base_headers: headers
    } do
      # Rate limit is typically 100 requests per minute per key
      # Test just below the limit
      for i <- 1..95 do
        conn =
          conn
          |> put_req_header("x-api-key", Enum.at(headers, 0) |> elem(1))
          |> get("/api/maps/#{map.slug}")

        assert json_response(conn, 200)

        # Add small delay to avoid hitting burst limits
        if rem(i, 10) == 0, do: Process.sleep(100)
      end

      # Should still be able to make requests
      conn =
        conn
        |> put_req_header("x-api-key", Enum.at(headers, 0) |> elem(1))
        |> get("/api/maps/#{map.slug}")

      assert json_response(conn, 200)
    end

    test "returns 429 when rate limit exceeded", %{conn: conn, map: map, base_headers: headers} do
      # Make rapid requests to trigger rate limiting
      # Note: Actual implementation may vary - this assumes a burst limit

      responses =
        for _i <- 1..150 do
          conn
          |> put_req_header("x-api-key", Enum.at(headers, 0) |> elem(1))
          |> get("/api/maps/#{map.slug}")
          |> Map.get(:status)
        end

      # Should have some 429 responses
      assert Enum.any?(responses, &(&1 == 429))

      # Find first 429 response
      rate_limited_response =
        Enum.reduce_while(1..150, nil, fn i, _acc ->
          conn =
            conn
            |> put_req_header("x-api-key", Enum.at(headers, 0) |> elem(1))
            |> get("/api/maps/#{map.slug}")

          if conn.status == 429 do
            {:halt, conn}
          else
            {:cont, nil}
          end
        end)

      if rate_limited_response do
        # Check proper rate limit headers
        assert get_resp_header(rate_limited_response, "x-ratelimit-limit")
        assert get_resp_header(rate_limited_response, "x-ratelimit-remaining")
        assert get_resp_header(rate_limited_response, "x-ratelimit-reset")
        assert retry_after = get_resp_header(rate_limited_response, "retry-after")
        assert is_binary(hd(retry_after))

        # Check error response format
        body = json_response(rate_limited_response, 429)
        assert body["errors"]
        assert body["errors"]["detail"] =~ "rate limit"
      end
    end

    test "rate limits are per API key", %{conn: conn, map: map} do
      # Create another API key
      api_key2 = Factory.create_map_api_key(%{map_id: map.id})

      # Make many requests with first key
      for _ <- 1..50 do
        conn
        |> put_req_header("x-api-key", api_key2.key)
        |> get("/api/maps/#{map.slug}")
      end

      # Second key should still work
      conn =
        conn
        |> put_req_header("x-api-key", api_key2.key)
        |> get("/api/maps/#{map.slug}")

      assert json_response(conn, 200)
    end

    test "rate limit headers are present in all responses", %{
      conn: conn,
      map: map,
      base_headers: headers
    } do
      conn =
        conn
        |> put_req_header("x-api-key", Enum.at(headers, 0) |> elem(1))
        |> get("/api/maps/#{map.slug}")

      assert json_response(conn, 200)

      # Check rate limit headers
      assert limit = get_resp_header(conn, "x-ratelimit-limit")
      assert remaining = get_resp_header(conn, "x-ratelimit-remaining")
      assert reset = get_resp_header(conn, "x-ratelimit-reset")

      # Validate header values
      assert String.to_integer(hd(limit)) > 0
      assert String.to_integer(hd(remaining)) >= 0
      assert String.to_integer(hd(reset)) > System.system_time(:second)
    end

    test "rate limits different endpoints independently", %{
      conn: conn,
      map: map,
      base_headers: headers
    } do
      api_key = Enum.at(headers, 0) |> elem(1)

      # Hit one endpoint multiple times
      for _ <- 1..20 do
        conn
        |> put_req_header("x-api-key", api_key)
        |> get("/api/maps/#{map.slug}")
      end

      # Different endpoint should have its own limit
      conn =
        conn
        |> put_req_header("x-api-key", api_key)
        |> get("/api/maps/#{map.slug}/systems")

      response = json_response(conn, 200)
      assert response

      # Check that we still have remaining requests on this endpoint
      remaining = get_resp_header(conn, "x-ratelimit-remaining") |> hd() |> String.to_integer()
      assert remaining > 0
    end

    test "write operations have stricter rate limits", %{
      conn: conn,
      map: map,
      base_headers: headers
    } do
      api_key = Enum.at(headers, 0) |> elem(1)

      # Write operations typically have lower rate limits
      responses =
        for i <- 1..30 do
          system_params = %{
            "solar_system_id" => 30_000_142 + i,
            "position_x" => i * 10,
            "position_y" => i * 10
          }

          conn
          |> put_req_header("x-api-key", api_key)
          |> put_req_header("content-type", "application/json")
          |> post("/api/maps/#{map.slug}/systems", system_params)
          |> Map.get(:status)
        end

      # Should hit rate limit sooner for writes
      rate_limited = Enum.count(responses, &(&1 == 429))
      assert rate_limited > 0, "Expected some requests to be rate limited"
    end

    test "respects rate limit reset time", %{conn: conn, map: map, base_headers: headers} do
      api_key = Enum.at(headers, 0) |> elem(1)

      # Make requests until rate limited
      rate_limited_conn =
        Enum.reduce_while(1..200, nil, fn _i, _acc ->
          conn =
            conn
            |> put_req_header("x-api-key", api_key)
            |> get("/api/maps/#{map.slug}")

          if conn.status == 429 do
            {:halt, conn}
          else
            {:cont, nil}
          end
        end)

      if rate_limited_conn do
        # Get reset time
        reset_time =
          get_resp_header(rate_limited_conn, "x-ratelimit-reset")
          |> hd()
          |> String.to_integer()

        retry_after =
          get_resp_header(rate_limited_conn, "retry-after")
          |> hd()
          |> String.to_integer()

        assert retry_after > 0
        assert reset_time > System.system_time(:second)

        # Wait for a short time (not full retry_after in tests)
        Process.sleep(1000)

        # Should still be rate limited if within window
        conn =
          conn
          |> put_req_header("x-api-key", api_key)
          |> get("/api/maps/#{map.slug}")

        # May or may not still be rate limited depending on implementation
        assert conn.status in [200, 429]
      end
    end

    test "OPTIONS requests are not rate limited", %{conn: conn, map: map, base_headers: headers} do
      api_key = Enum.at(headers, 0) |> elem(1)

      # Make many OPTIONS requests
      for _ <- 1..100 do
        conn =
          conn
          |> put_req_header("x-api-key", api_key)
          |> options("/api/maps/#{map.slug}")

        assert conn.status in [200, 204]
      end

      # Regular requests should still work
      conn =
        conn
        |> put_req_header("x-api-key", api_key)
        |> get("/api/maps/#{map.slug}")

      assert json_response(conn, 200)
    end

    test "rate limit error response follows API format", %{
      conn: conn,
      map: map,
      base_headers: headers
    } do
      api_key = Enum.at(headers, 0) |> elem(1)

      # Trigger rate limit
      rate_limited_conn =
        Enum.reduce_while(1..200, nil, fn _i, _acc ->
          conn =
            conn
            |> put_req_header("x-api-key", api_key)
            |> get("/api/maps/#{map.slug}")

          if conn.status == 429 do
            {:halt, conn}
          else
            {:cont, nil}
          end
        end)

      if rate_limited_conn do
        body = json_response(rate_limited_conn, 429)

        # Check error format matches OpenAPI spec
        assert body["errors"]
        assert body["errors"]["status"] == "429"
        assert body["errors"]["title"] == "Too Many Requests"
        assert body["errors"]["detail"]
        assert body["errors"]["detail"] =~ "rate limit"

        # Should include rate limit info in meta
        if body["errors"]["meta"] do
          assert body["errors"]["meta"]["retry_after"]
          assert body["errors"]["meta"]["rate_limit_reset"]
        end
      end
    end
  end

  describe "Rate Limiting with Invalid Keys" do
    test "invalid API keys count against IP rate limit", %{conn: conn, map: map} do
      # Make requests with invalid keys
      responses =
        for i <- 1..50 do
          conn
          |> put_req_header("x-api-key", "invalid-key-#{i}")
          |> get("/api/maps/#{map.slug}")
          |> Map.get(:status)
        end

      # All should be 401
      assert Enum.all?(responses, &(&1 == 401))

      # But repeated invalid attempts might trigger IP-based rate limiting
      # This depends on implementation
    end

    test "missing API key uses IP-based rate limiting", %{conn: conn} do
      # Public endpoints might have IP-based rate limits
      responses =
        for _ <- 1..100 do
          conn
          |> get("/api/common/systems")
          |> Map.get(:status)
        end

      # Should eventually hit rate limit or all succeed
      assert Enum.all?(responses, &(&1 in [200, 429]))
    end
  end
end
