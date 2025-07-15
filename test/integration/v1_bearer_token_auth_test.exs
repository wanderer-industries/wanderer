defmodule WandererAppWeb.V1BearerTokenAuthTest do
  use WandererAppWeb.ConnCase
  
  import WandererAppWeb.Factory
  
  describe "v1 API Bearer token authentication" do
    setup do
      # Create test data
      user = insert(:user)
      
      # First create an owner character
      owner_character = insert(:character, %{
        user_id: user.id,
        eve_id: "owner_#{System.unique_integer([:positive])}"
      })
      
      # Create map with the owner character
      map = insert(:map, %{
        owner_id: owner_character.id,
        public_api_key: "test_bearer_token_#{System.unique_integer([:positive])}"
      })
      
      # Create another character for testing
      character = insert(:character, %{
        user_id: user.id,
        eve_id: "123456789"
      })
      
      # Add character to map
      insert(:map_character_settings, %{
        map_id: map.id,
        character_id: character.id
      })
      
      {:ok, map: map, user: user, character: character, owner_character: owner_character}
    end
    
    test "can access v1 character endpoint with valid Bearer token", %{conn: conn, map: map, character: character} do
      conn = 
        conn
        |> put_req_header("authorization", "Bearer #{map.public_api_key}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/v1/characters/#{character.id}")
        
      assert json_response = json_response(conn, 200)
      assert json_response["data"]["type"] == "characters"
      assert json_response["data"]["id"] == character.id
    end
    
    test "rejects v1 request with invalid Bearer token", %{conn: conn, character: character} do
      conn = 
        conn
        |> put_req_header("authorization", "Bearer invalid_token")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/v1/characters/#{character.id}")
        
      assert conn.status == 401
      assert json_response = Jason.decode!(conn.resp_body)
      assert json_response["error"] == "Invalid API key"
    end
    
    test "rejects v1 request without Bearer token", %{conn: conn, character: character} do
      conn = 
        conn
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/v1/characters/#{character.id}")
        
      assert conn.status == 401
      assert json_response = Jason.decode!(conn.resp_body)
      assert json_response["error"] == "Missing or invalid authorization header"
    end
    
    test "can access v1 maps endpoint with valid Bearer token", %{conn: conn, map: map} do
      conn = 
        conn
        |> put_req_header("authorization", "Bearer #{map.public_api_key}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/v1/maps")
        
      assert json_response = json_response(conn, 200)
      assert json_response["data"]
      # Should at least see the map associated with the API key
      assert Enum.any?(json_response["data"], fn m -> 
        m["id"] == map.id 
      end)
    end
    
    test "Bearer token provides map context in conn assigns", %{conn: conn, map: map} do
      # This test demonstrates that the map context is available
      # We'll use a v1 endpoint to check if assigns are properly set
      conn = 
        conn
        |> put_req_header("authorization", "Bearer #{map.public_api_key}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/v1/maps/#{map.id}")
        
      # The response should be successful, indicating auth worked
      assert json_response(conn, 200)
      
      # The Bearer token auth should have set the map and user in assigns
      # These would be available to the controller handling the request
      assert conn.assigns[:map]
      assert conn.assigns[:map].id == map.id
      assert conn.assigns[:current_user]
    end
  end
end