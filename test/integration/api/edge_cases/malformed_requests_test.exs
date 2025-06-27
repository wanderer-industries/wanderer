defmodule WandererAppWeb.API.EdgeCases.MalformedRequestsTest do
  use WandererAppWeb.ConnCase, async: false

  alias WandererApp.Test.Factory

  describe "Malformed JSON Requests" do
    setup do
      user = Factory.create_user()
      map = Factory.create_map(%{user_id: user.id})
      api_key = Factory.create_map_api_key(%{map_id: map.id})

      %{
        user: user,
        map: map,
        api_key: api_key,
        base_conn: put_req_header(conn, "x-api-key", api_key.key)
      }
    end

    test "handles invalid JSON syntax", %{base_conn: conn, map: map} do
      # Various forms of invalid JSON
      invalid_jsons = [
        "{invalid json}",
        "{'single': 'quotes'}",
        "{\"unclosed\": \"string}",
        "{\"trailing\": \"comma\",}",
        "undefined",
        "{\"key\" \"missing colon\" \"value\"}",
        "[1, 2, 3,]",
        "{'nested': {'broken': }}",
        "null undefined true"
      ]

      for invalid_json <- invalid_jsons do
        conn =
          conn
          |> put_req_header("content-type", "application/json")
          |> put_req_header("content-length", "#{byte_size(invalid_json)}")
          |> Map.put(:body_params, %{})
          |> Map.put(:params, %{})
          |> Plug.Conn.put_private(:plug_skip_body_read, true)

        # Manually set request body
        {:ok, body, conn} = Plug.Conn.read_body(conn, length: 1_000_000)
        conn = Map.put(conn, :body_params, body)

        conn = post(conn, "/api/maps/#{map.slug}/systems", invalid_json)

        assert conn.status == 400
        error_response = json_response(conn, 400)
        assert error_response["errors"]["status"] == "400"
        assert error_response["errors"]["title"] == "Bad Request"

        assert error_response["errors"]["detail"] =~ "JSON" or
                 error_response["errors"]["detail"] =~ "parse" or
                 error_response["errors"]["detail"] =~ "invalid"
      end
    end

    test "handles deeply nested JSON", %{base_conn: conn, map: map} do
      # Create deeply nested structure
      deep_json =
        Enum.reduce(1..100, "\"value\"", fn _, acc ->
          "{\"nested\": #{acc}}"
        end)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/maps/#{map.slug}/systems", deep_json)

      # Should either accept or reject with appropriate error
      if conn.status == 400 do
        error_response = json_response(conn, 400)

        assert error_response["errors"]["detail"] =~ "too deep" or
                 error_response["errors"]["detail"] =~ "nested" or
                 error_response["errors"]["detail"] =~ "complexity"
      end
    end

    test "handles extremely large JSON payloads", %{base_conn: conn, map: map} do
      # Create a very large payload
      large_array =
        for i <- 1..10000,
            do: %{
              "solar_system_id" => 30_000_142 + i,
              "position_x" => i * 10,
              "position_y" => i * 20,
              "description" => String.duplicate("a", 1000)
            }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/maps/#{map.slug}/systems/bulk", %{"systems" => large_array})

      # Should reject if too large
      assert conn.status in [400, 413, 422]

      if conn.status == 413 do
        error_response = json_response(conn, 413)
        assert error_response["errors"]["status"] == "413"
        assert error_response["errors"]["title"] == "Payload Too Large"

        assert error_response["errors"]["detail"] =~ "too large" or
                 error_response["errors"]["detail"] =~ "size limit" or
                 error_response["errors"]["detail"] =~ "exceeded"
      end
    end

    test "handles missing required fields", %{base_conn: conn, map: map} do
      # Various incomplete payloads
      incomplete_payloads = [
        # Empty object
        %{},
        # Missing solar_system_id and position_y
        %{"position_x" => 100},
        # Missing positions
        %{"solar_system_id" => 30_000_142},
        # Missing solar_system_id and position_x
        %{"position_y" => 200},
        # Null required field
        %{"solar_system_id" => nil, "position_x" => 100, "position_y" => 200}
      ]

      for payload <- incomplete_payloads do
        conn =
          conn
          |> put_req_header("content-type", "application/json")
          |> post("/api/maps/#{map.slug}/systems", payload)

        assert conn.status in [400, 422]
        error_response = json_response(conn, conn.status)

        assert error_response["errors"]["detail"] =~ "required" or
                 error_response["errors"]["detail"] =~ "missing" or
                 error_response["errors"]["detail"] =~ "must be present"
      end
    end

    test "handles wrong data types", %{base_conn: conn, map: map} do
      # Test various wrong type scenarios
      wrong_type_payloads = [
        %{"solar_system_id" => "not-a-number", "position_x" => 100, "position_y" => 200},
        %{"solar_system_id" => 30_000_142, "position_x" => "100", "position_y" => "200"},
        %{"solar_system_id" => [30_000_142], "position_x" => 100, "position_y" => 200},
        %{"solar_system_id" => %{"id" => 30_000_142}, "position_x" => 100, "position_y" => 200},
        %{"solar_system_id" => true, "position_x" => false, "position_y" => nil}
      ]

      for payload <- wrong_type_payloads do
        conn =
          conn
          |> put_req_header("content-type", "application/json")
          |> post("/api/maps/#{map.slug}/systems", payload)

        assert conn.status in [400, 422]
        error_response = json_response(conn, conn.status)

        assert error_response["errors"]["detail"] =~ "type" or
                 error_response["errors"]["detail"] =~ "must be" or
                 error_response["errors"]["detail"] =~ "invalid"
      end
    end
  end

  describe "Malformed Headers" do
    setup do
      user = Factory.create_user()
      map = Factory.create_map(%{user_id: user.id})
      api_key = Factory.create_map_api_key(%{map_id: map.id})

      %{user: user, map: map, api_key: api_key}
    end

    test "handles invalid content-type header", %{conn: conn, map: map, api_key: api_key} do
      invalid_content_types = [
        "text/plain",
        "application/xml",
        "application/json; charset=invalid",
        "application/json/extra",
        "invalid/type",
        "",
        "null"
      ]

      for content_type <- invalid_content_types do
        conn =
          conn
          |> put_req_header("x-api-key", api_key.key)
          |> put_req_header("content-type", content_type)
          |> post("/api/maps/#{map.slug}/systems", "{\"solar_system_id\": 30000142}")

        assert conn.status in [400, 415]

        if conn.status == 415 do
          error_response = json_response(conn, 415)
          assert error_response["errors"]["status"] == "415"
          assert error_response["errors"]["title"] == "Unsupported Media Type"

          assert error_response["errors"]["detail"] =~ "content-type" or
                   error_response["errors"]["detail"] =~ "media type" or
                   error_response["errors"]["detail"] =~ "must be application/json"
        end
      end
    end

    test "handles malformed API key headers", %{conn: conn, map: map} do
      malformed_keys = [
        "",
        "   ",
        "key with spaces",
        "key\nwith\nnewlines",
        "key\twith\ttabs",
        # Very long key
        String.duplicate("a", 1000),
        "key/with/slashes",
        "key?with=query",
        "key#with#hash",
        # Binary data
        <<0, 1, 2, 3, 4, 5>>
      ]

      for bad_key <- malformed_keys do
        conn =
          conn
          |> put_req_header("x-api-key", bad_key)
          |> get("/api/maps/#{map.slug}")

        assert conn.status == 401
        error_response = json_response(conn, 401)

        assert error_response["errors"]["detail"] =~ "invalid" or
                 error_response["errors"]["detail"] =~ "malformed" or
                 error_response["errors"]["detail"] =~ "API key"
      end
    end

    test "handles duplicate headers", %{conn: conn, map: map, api_key: api_key} do
      conn =
        conn
        |> put_req_header("x-api-key", api_key.key)
        |> put_req_header("x-api-key", "different-key")
        |> get("/api/maps/#{map.slug}")

      # Should either use first, last, or reject
      assert conn.status in [200, 400, 401]
    end

    test "handles headers with invalid encoding", %{conn: conn, map: map, api_key: api_key} do
      # Headers with non-ASCII characters
      conn =
        conn
        |> put_req_header("x-api-key", api_key.key)
        |> put_req_header("x-custom-header", "value-with-émojis-🚀")
        |> get("/api/maps/#{map.slug}")

      # Should handle gracefully
      assert conn.status in [200, 400]
    end
  end

  describe "Malformed URL Parameters" do
    setup do
      user = Factory.create_user()
      map = Factory.create_map(%{user_id: user.id})
      api_key = Factory.create_map_api_key(%{map_id: map.id})

      %{
        user: user,
        map: map,
        api_key: api_key,
        conn: put_req_header(conn, "x-api-key", api_key.key)
      }
    end

    test "handles invalid path parameters", %{conn: conn} do
      invalid_paths = [
        "/api/maps/../../etc/passwd",
        "/api/maps/map%00null",
        "/api/maps/map\nwith\nnewline",
        "/api/maps/" <> String.duplicate("a", 1000),
        "/api/maps/map<script>alert('xss')</script>",
        "/api/maps/map';DROP TABLE maps;--",
        "/api/maps/map%20with%20spaces",
        "/api/maps/",
        "/api/maps//systems"
      ]

      for path <- invalid_paths do
        conn = get(conn, path)
        assert conn.status in [400, 404]
      end
    end

    test "handles invalid query parameters", %{conn: conn, map: map} do
      invalid_queries = [
        "?limit=not-a-number",
        "?limit=-1",
        "?limit=999999999",
        "?offset=abc",
        "?offset=-100",
        "?sort=';DROP TABLE;",
        "?filter[name]=<script>",
        "?include=../../../etc/passwd",
        "?fields=*",
        "?page[size]=huge"
      ]

      for query <- invalid_queries do
        conn = get(conn, "/api/maps/#{map.slug}/systems#{query}")
        assert conn.status in [400, 422]

        error_response = json_response(conn, conn.status)

        assert error_response["errors"]["detail"] =~ "invalid" or
                 error_response["errors"]["detail"] =~ "parameter" or
                 error_response["errors"]["detail"] =~ "query"
      end
    end

    test "handles extremely long query strings", %{conn: conn, map: map} do
      # Create very long query string
      long_param = String.duplicate("a", 10000)
      conn = get(conn, "/api/maps/#{map.slug}/systems?filter=#{long_param}")

      assert conn.status in [400, 414]

      if conn.status == 414 do
        error_response = json_response(conn, 414)
        assert error_response["errors"]["title"] == "URI Too Long"
      end
    end

    test "handles special characters in parameters", %{conn: conn, map: map} do
      special_chars = [
        # Null byte
        "%00",
        # Newline
        "%0A",
        # Carriage return
        "%0D",
        # Space
        "%20",
        # <
        "%3C",
        # >
        "%3E",
        # "
        "%22",
        # '
        "%27",
        # {
        "%7B",
        # }
        "%7D"
      ]

      for char <- special_chars do
        conn = get(conn, "/api/maps/#{map.slug}/systems?name=test#{char}test")
        # Should handle safely
        assert conn.status in [200, 400]
      end
    end
  end

  describe "Invalid HTTP Methods" do
    setup do
      user = Factory.create_user()
      map = Factory.create_map(%{user_id: user.id})
      api_key = Factory.create_map_api_key(%{map_id: map.id})

      %{
        user: user,
        map: map,
        api_key: api_key,
        conn: put_req_header(conn, "x-api-key", api_key.key)
      }
    end

    test "handles unsupported HTTP methods", %{conn: conn, map: map} do
      # Try various invalid methods
      unsupported_methods = ["TRACE", "CONNECT", "CUSTOM", "INVALID"]

      for method <- unsupported_methods do
        conn =
          conn
          |> Map.put(:method, method)
          |> dispatch("/api/maps/#{map.slug}")

        assert conn.status == 405
        error_response = json_response(conn, 405)
        assert error_response["errors"]["status"] == "405"
        assert error_response["errors"]["title"] == "Method Not Allowed"
        assert get_resp_header(conn, "allow") != []
      end
    end

    test "handles method mismatch for endpoints", %{conn: conn, map: map} do
      # Try wrong methods for specific endpoints
      wrong_methods = [
        # Should be GET
        {:post, "/api/maps/#{map.slug}"},
        # Should be POST
        {:put, "/api/maps/#{map.slug}/systems"},
        # Should be GET
        {:delete, "/api/maps"},
        # Might be DELETE
        {:get, "/api/maps/#{map.slug}/systems/30000142"}
      ]

      for {method, path} <- wrong_methods do
        conn =
          case method do
            :get -> get(conn, path)
            :post -> post(conn, path, %{})
            :put -> put(conn, path, %{})
            :delete -> delete(conn, path)
          end

        # Should return 404 or 405
        assert conn.status in [404, 405]
      end
    end
  end

  describe "Request Body Edge Cases" do
    setup do
      user = Factory.create_user()
      map = Factory.create_map(%{user_id: user.id})
      api_key = Factory.create_map_api_key(%{map_id: map.id})

      %{
        user: user,
        map: map,
        api_key: api_key,
        conn: put_req_header(conn, "x-api-key", api_key.key)
      }
    end

    test "handles empty request body when body is required", %{conn: conn, map: map} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/maps/#{map.slug}/systems", "")

      assert conn.status in [400, 422]
      error_response = json_response(conn, conn.status)

      assert error_response["errors"]["detail"] =~ "body" or
               error_response["errors"]["detail"] =~ "empty" or
               error_response["errors"]["detail"] =~ "required"
    end

    test "handles array when object expected", %{conn: conn, map: map} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/maps/#{map.slug}/systems", [1, 2, 3])

      assert conn.status in [400, 422]
      error_response = json_response(conn, conn.status)

      assert error_response["errors"]["detail"] =~ "object" or
               error_response["errors"]["detail"] =~ "array" or
               error_response["errors"]["detail"] =~ "type"
    end

    test "handles circular references in JSON", %{conn: conn, map: map} do
      # Can't create true circular reference in JSON, but can create very deep nesting
      # that might cause stack overflow in naive parsers
      deep_obj = %{"a" => %{"b" => %{"c" => %{"d" => %{"e" => %{"f" => "value"}}}}}}

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/maps/#{map.slug}/systems", deep_obj)

      # Should handle without crashing
      assert conn.status in [400, 422]
    end

    test "handles Unicode edge cases", %{conn: conn, map: map} do
      unicode_payloads = [
        # Null character
        %{"name" => "test\u0000null"},
        # Zero-width space
        %{"name" => "test\u200Binvisible"},
        # Byte order mark
        %{"name" => "test\uFEFFbom"},
        # Mathematical alphanumeric symbols
        %{"name" => "𝕿𝖊𝖘𝖙"},
        # Emojis
        %{"name" => "🚀🚀🚀🚀🚀"},
        # Long unicode string
        %{"name" => String.duplicate("𝕳", 100)}
      ]

      for payload <- unicode_payloads do
        full_payload =
          Map.merge(
            %{
              "solar_system_id" => 30_000_142,
              "position_x" => 100,
              "position_y" => 200
            },
            payload
          )

        conn =
          conn
          |> put_req_header("content-type", "application/json")
          |> post("/api/maps/#{map.slug}/systems", full_payload)

        # Should either accept or reject gracefully
        assert conn.status in [201, 400, 422]
      end
    end
  end
end
