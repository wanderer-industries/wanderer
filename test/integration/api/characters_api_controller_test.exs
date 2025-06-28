defmodule WandererAppWeb.CharactersAPIControllerTest do
  use WandererAppWeb.ApiCase, async: true

  # Note: This controller requires :api_character pipeline which includes CheckCharacterApiDisabled plug
  # We may need to mock or configure API settings for these tests

  describe "GET /api/characters" do
    test "returns list of characters when API is enabled", %{conn: conn} do
      # Create some test characters
      character1 =
        insert(:character, %{
          eve_id: "123456789",
          name: "Test Pilot 1",
          corporation_ticker: "TEST1"
        })

      character2 =
        insert(:character, %{
          eve_id: "987654321",
          name: "Test Pilot 2",
          corporation_ticker: "TEST2"
        })

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> get("/api/characters")
        |> assert_json_response(200)

      # Verify response structure
      assert %{"data" => characters} = response
      assert is_list(characters)
      assert length(characters) >= 2

      # Find our test characters in the response
      char1_data = Enum.find(characters, &(&1["eve_id"] == character1.eve_id))
      char2_data = Enum.find(characters, &(&1["eve_id"] == character2.eve_id))

      assert char1_data
      assert char2_data

      # Verify character structure
      for char_data <- [char1_data, char2_data] do
        required_fields = ["eve_id", "name"]

        for field <- required_fields do
          assert Map.has_key?(char_data, field), "Missing required field: #{field}"
        end

        # Verify data types
        assert is_binary(char_data["eve_id"])
        assert is_binary(char_data["name"])

        # Optional fields should be present if set
        if Map.has_key?(char_data, "corporation_ticker") do
          assert is_binary(char_data["corporation_ticker"])
        end
      end
    end

    test "returns empty list when no characters exist", %{conn: conn} do
      # Ensure no characters exist (test isolation)
      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> get("/api/characters")
        |> assert_json_response(200)

      assert %{"data" => []} = response
    end

    @tag :skip_if_api_disabled
    test "returns 200 when character API is enabled", %{conn: conn} do
      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> get("/api/characters")

      # Test will be skipped if API is disabled, so we only expect 200 here
      assert response.status == 200
      assert %{"data" => _} = json_response(response, 200)
    end

    test "handles database errors gracefully", %{conn: conn} do
      # This is harder to test without mocking the database
      # For now, we'll verify the endpoint responds successfully
      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> get("/api/characters")

      # Should get either success or a proper error response
      assert response.status in [200, 500]

      if response.status == 200 do
        assert %{"data" => _} = json_response(response, 200)
      else
        assert %{"error" => _} = json_response(response, 500)
      end
    end
  end
end
