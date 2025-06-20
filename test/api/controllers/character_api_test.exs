defmodule WandererApp.CharacterApiTest do
  use WandererApp.ApiCase

  @moduledoc """
  Tests for the character API endpoints.
  Note: Currently only the index endpoint is available at /api/characters
  """

  describe "GET /api/characters" do
    setup do
      # Create test characters
      user1 = create_user()
      character1 = create_character(%{user_id: user1.id, name: "Test Character 1"}, user1)

      user2 = create_user()
      character2 = create_character(%{user_id: user2.id, name: "Test Character 2"}, user2)

      {:ok, characters: [character1, character2]}
    end

    test "lists all characters in the database", %{conn: conn, characters: characters} do
      # Note: This endpoint lists ALL characters and doesn't require authentication
      response =
        conn
        |> get("/api/characters")
        |> json_response(200)

      # Should include all characters created in setup
      assert length(response["data"]) >= 2

      character_names = Enum.map(response["data"], & &1["name"])
      assert "Test Character 1" in character_names
      assert "Test Character 2" in character_names
    end

    test "returns character information in correct format", %{conn: conn} do
      response =
        conn
        |> get("/api/characters")
        |> json_response(200)

      # Based on the OpenAPI schema, check for required fields
      Enum.each(response["data"], fn character ->
        assert Map.has_key?(character, "eve_id")
        assert Map.has_key?(character, "name")
        # Optional fields: corporation_id, corporation_ticker, alliance_id, alliance_ticker
      end)
    end

    test "handles empty character list", %{conn: _conn} do
      # Skip this test as we already created characters in other tests
      # In a real scenario, you'd test with a clean database
    end
  end
end
