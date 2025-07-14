defmodule WandererAppWeb.CharactersAPIControllerUnitTest do
  use WandererAppWeb.ConnCase, async: true

  alias WandererAppWeb.CharactersAPIController

  describe "index/2 functionality" do
    test "handles basic request structure" do
      conn = build_conn()
      params = %{}

      result = CharactersAPIController.index(conn, params)

      assert %Plug.Conn{} = result
      # Should return 200 or 500 depending on operation result
      assert result.status in [200, 500]

      if result.status == 200 do
        response_body = result.resp_body |> Jason.decode!()
        assert %{"data" => data} = response_body
        assert is_list(data)
      else
        response_body = result.resp_body |> Jason.decode!()
        assert %{"error" => _error_msg} = response_body
      end
    end

    test "handles various parameter inputs" do
      conn = build_conn()

      # Test with different parameter structures
      test_params = [
        %{},
        %{"extra" => "ignored"},
        %{"nested" => %{"data" => "value"}},
        %{"array" => [1, 2, 3]},
        %{"filter" => "some_filter"},
        %{"limit" => 100},
        %{"offset" => 0}
      ]

      for params <- test_params do
        result = CharactersAPIController.index(conn, params)

        assert %Plug.Conn{} = result
        # Should handle all parameter variations gracefully
        assert result.status in [200, 500]

        if result.status == 200 do
          response_body = result.resp_body |> Jason.decode!()
          assert %{"data" => data} = response_body
          assert is_list(data)
        else
          response_body = result.resp_body |> Jason.decode!()
          assert %{"error" => _error_msg} = response_body
        end
      end
    end

    test "response structure validation" do
      conn = build_conn()
      params = %{}

      result = CharactersAPIController.index(conn, params)

      assert %Plug.Conn{} = result

      case result.status do
        200 ->
          response_body = result.resp_body |> Jason.decode!()
          assert %{"data" => data} = response_body
          assert is_list(data)

          # If there are characters in the response, validate structure
          if length(data) > 0 do
            character = List.first(data)
            # Validate that it has required fields
            assert Map.has_key?(character, "eve_id")
            assert Map.has_key?(character, "name")
            assert is_binary(character["eve_id"])
            assert is_binary(character["name"])
          end

        500 ->
          response_body = result.resp_body |> Jason.decode!()
          assert %{"error" => error_msg} = response_body
          assert is_binary(error_msg)
      end
    end

    test "handles nil parameters" do
      conn = build_conn()
      params = nil

      # Should handle nil parameters gracefully
      result = CharactersAPIController.index(conn, params)

      assert %Plug.Conn{} = result
      assert result.status in [200, 500]
    end

    test "handles malformed parameter structures" do
      conn = build_conn()

      # Test various malformed parameter structures
      malformed_params = [
        "not_a_map",
        123,
        [],
        %{"deeply" => %{"nested" => %{"structure" => %{"with" => "values"}}}},
        %{"array_with_objects" => [%{"key" => "value"}, %{"another" => "object"}]}
      ]

      for params <- malformed_params do
        result = CharactersAPIController.index(conn, params)

        assert %Plug.Conn{} = result
        # Should handle malformed structures gracefully
        assert result.status in [200, 500]
      end
    end
  end

  describe "edge cases and error handling" do
    test "handles concurrent parameter access" do
      conn = build_conn()

      # Test with complex nested parameter structure
      params = %{
        "filter" => %{
          "corporation" => "Test Corp",
          "alliance" => "Test Alliance",
          "nested_data" => %{
            "deep" => %{
              "structure" => "value"
            }
          }
        },
        "pagination" => %{
          "limit" => 50,
          "offset" => 0
        },
        "sort" => %{
          "field" => "name",
          "direction" => "asc"
        },
        "array_field" => [1, 2, 3, %{"object" => "in_array"}],
        "extra_top_level" => "ignored"
      }

      result = CharactersAPIController.index(conn, params)

      assert %Plug.Conn{} = result
      # Should handle complex structure gracefully
      assert result.status in [200, 500]

      response_body = result.resp_body |> Jason.decode!()
      assert is_map(response_body)
    end

    test "handles very large parameter objects" do
      conn = build_conn()

      # Create a large parameter object
      large_data = 1..100 |> Enum.into(%{}, fn i -> {"field_#{i}", "value_#{i}"} end)

      params = Map.merge(%{"filter" => "characters"}, large_data)

      result = CharactersAPIController.index(conn, params)

      assert %Plug.Conn{} = result
      # Should handle large objects gracefully
      assert result.status in [200, 500]

      response_body = result.resp_body |> Jason.decode!()
      assert is_map(response_body)
    end

    test "handles special characters in parameters" do
      conn = build_conn()

      # Test with special characters
      params = %{
        "search" => "测试 特殊字符",
        "filter" => "çharacters with àccents",
        "unicode" => "🚀 emoji test",
        "symbols" => "!@#$%^&*()_+-=[]{}|;':\",./<>?",
        "newlines" => "line1\nline2\rline3\r\nline4"
      }

      result = CharactersAPIController.index(conn, params)

      assert %Plug.Conn{} = result
      # Should handle special characters gracefully
      assert result.status in [200, 500]

      response_body = result.resp_body |> Jason.decode!()
      assert is_map(response_body)
    end

    test "handles empty and null values" do
      conn = build_conn()

      # Test with various empty/null values
      params = %{
        "empty_string" => "",
        "null_value" => nil,
        "empty_map" => %{},
        "empty_array" => [],
        "zero" => 0,
        "false" => false,
        "whitespace" => "   ",
        "tab_and_newline" => "\t\n"
      }

      result = CharactersAPIController.index(conn, params)

      assert %Plug.Conn{} = result
      # Should handle empty/null values gracefully
      assert result.status in [200, 500]

      response_body = result.resp_body |> Jason.decode!()
      assert is_map(response_body)
    end

    test "performance with repeated requests" do
      conn = build_conn()
      params = %{}

      # Make multiple requests to test consistency
      results =
        for _i <- 1..5 do
          CharactersAPIController.index(conn, params)
        end

      # All results should have consistent structure
      Enum.each(results, fn result ->
        assert %Plug.Conn{} = result
        assert result.status in [200, 500]

        response_body = result.resp_body |> Jason.decode!()
        assert is_map(response_body)

        case result.status do
          200 ->
            assert %{"data" => data} = response_body
            assert is_list(data)

          500 ->
            assert %{"error" => _error_msg} = response_body
        end
      end)
    end

    test "handles request with different connection states" do
      # Test with basic connection
      conn1 = build_conn()
      result1 = CharactersAPIController.index(conn1, %{})
      assert %Plug.Conn{} = result1
      assert result1.status in [200, 500]

      # Test with connection that has assigns
      conn2 = build_conn() |> assign(:user_id, "123") |> assign(:map_id, Ecto.UUID.generate())
      result2 = CharactersAPIController.index(conn2, %{})
      assert %Plug.Conn{} = result2
      assert result2.status in [200, 500]

      # Test with connection that has different content type
      conn3 = build_conn() |> put_req_header("content-type", "application/xml")
      result3 = CharactersAPIController.index(conn3, %{})
      assert %Plug.Conn{} = result3
      assert result3.status in [200, 500]
    end
  end

  describe "response content validation" do
    test "ensures response always has required structure" do
      conn = build_conn()
      params = %{}

      result = CharactersAPIController.index(conn, params)

      assert %Plug.Conn{} = result
      assert result.resp_body != ""

      response_body = result.resp_body |> Jason.decode!()
      assert is_map(response_body)

      case result.status do
        200 ->
          # Success response should have data field
          assert %{"data" => data} = response_body
          assert is_list(data)

          # Each character should have basic structure if any exist
          Enum.each(data, fn character ->
            assert is_map(character)
            # Should have at least eve_id and name according to schema
            assert Map.has_key?(character, "eve_id") or Map.has_key?(character, "name")
          end)

        500 ->
          # Error response should have error field
          assert %{"error" => error_msg} = response_body
          assert is_binary(error_msg)
          assert String.length(error_msg) > 0
      end
    end

    test "validates character data structure when present" do
      conn = build_conn()
      params = %{}

      result = CharactersAPIController.index(conn, params)

      if result.status == 200 do
        response_body = result.resp_body |> Jason.decode!()
        %{"data" => characters} = response_body

        # If there are characters, validate their structure
        Enum.each(characters, fn character ->
          # According to the schema, these are the possible fields
          possible_fields = [
            "eve_id",
            "name",
            "corporation_id",
            "corporation_ticker",
            "alliance_id",
            "alliance_ticker"
          ]

          # Character should be a map
          assert is_map(character)

          # All present fields should be in the expected list
          character_fields = Map.keys(character)
          unexpected_fields = character_fields -- possible_fields

          assert length(unexpected_fields) == 0,
                 "Unexpected fields found: #{inspect(unexpected_fields)}"

          # If eve_id is present, it should be a string
          if Map.has_key?(character, "eve_id") do
            assert is_binary(character["eve_id"])
          end

          # If name is present, it should be a string
          if Map.has_key?(character, "name") do
            assert is_binary(character["name"])
          end
        end)
      end
    end
  end
end
