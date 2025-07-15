defmodule WandererAppWeb.Plugs.CheckJsonApiAuthTest do
  use WandererAppWeb.ConnCase, async: true
  
  alias WandererAppWeb.Plugs.CheckJsonApiAuth
  import WandererAppWeb.Factory

  describe "Bearer token authentication" do
    setup do
      # Create a test user and map using factory
      user = insert(:user)
      
      # Create owner character for the map
      owner_character = insert(:character, %{
        user_id: user.id,
        eve_id: "owner_#{System.unique_integer([:positive])}"
      })
      
      # Create a test map with API key
      map = insert(:map, %{
        owner_id: owner_character.id,
        public_api_key: "test_api_key_#{System.unique_integer([:positive])}"
      })
      
      {:ok, map: map, user: user, owner_character: owner_character}
    end
    
    test "authenticates valid Bearer token", %{conn: conn, map: map} do
      conn =
        conn
        |> init_test_session(%{})
        |> put_req_header("authorization", "Bearer #{map.public_api_key}")
        |> CheckJsonApiAuth.call([])
        
      assert conn.assigns[:current_user]
      assert conn.assigns[:map]
      assert conn.assigns[:map].id == map.id
      refute conn.halted
    end
    
    test "rejects invalid Bearer token", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> put_req_header("authorization", "Bearer invalid_token")
        |> CheckJsonApiAuth.call([])
        
      assert conn.halted
      assert conn.status == 401
      assert json_response = Jason.decode!(conn.resp_body)
      assert json_response["error"] == "Invalid API key"
    end
    
    test "rejects missing authorization header", %{conn: conn} do
      conn = 
        conn
        |> init_test_session(%{})
        |> CheckJsonApiAuth.call([])
        
      assert conn.halted
      assert conn.status == 401
      assert json_response = Jason.decode!(conn.resp_body)
      assert json_response["error"] == "Missing or invalid authorization header"
    end
    
    test "rejects malformed authorization header", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> put_req_header("authorization", "Basic dGVzdDp0ZXN0")
        |> CheckJsonApiAuth.call([])
        
      assert conn.halted
      assert conn.status == 401
      assert json_response = Jason.decode!(conn.resp_body)
      assert json_response["error"] == "Missing or invalid authorization header"
    end
    
    test "accepts test tokens in test environment", %{conn: conn, map: map} do
      # Use the actual test API key from the created map
      conn =
        conn
        |> init_test_session(%{})
        |> put_req_header("authorization", "Bearer #{map.public_api_key}")
        |> CheckJsonApiAuth.call([])
        
      assert conn.assigns[:current_user]
      assert conn.assigns[:map]
      assert conn.assigns[:map].id == map.id
      refute conn.halted
    end
  end
  
  describe "session-based authentication" do
    setup do
      # Create a test user
      user = insert(:user)
      
      {:ok, user: user}
    end
    
    test "authenticates valid session", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(%{})
        |> put_session(:user_id, user.id)
        |> CheckJsonApiAuth.call([])
        
      assert conn.assigns[:current_user]
      assert conn.assigns[:current_user].id == user.id
      refute conn.halted
    end
    
    test "rejects invalid session user_id", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> put_session(:user_id, Ecto.UUID.generate())
        |> CheckJsonApiAuth.call([])
        
      assert conn.halted
      assert conn.status == 401
      assert json_response = Jason.decode!(conn.resp_body)
      assert json_response["error"] == "Invalid session"
    end
  end
  
  describe "telemetry and logging" do
    setup do
      # Return a conn with session properly configured
      conn = build_conn()
      {:ok, conn: conn}
    end
    
    test "emits telemetry events on successful auth", %{conn: conn} do
      :telemetry.attach(
        "test-auth-success",
        [:wanderer_app, :json_api, :auth],
        fn _event, measurements, metadata, _config ->
          send(self(), {:telemetry_event, measurements, metadata})
        end,
        nil
      )
      
      # Create a test map with a known API key
      user = insert(:user)
      owner_character = insert(:character, %{user_id: user.id})
      map = insert(:map, %{
        owner_id: owner_character.id,
        public_api_key: "test_api_key_for_telemetry"
      })
      
      conn
      |> init_test_session(%{})
      |> put_req_header("authorization", "Bearer #{map.public_api_key}")
      |> CheckJsonApiAuth.call([])
      
      assert_receive {:telemetry_event, %{count: 1, duration: _}, %{auth_type: "bearer_token", result: "success"}}
      
      :telemetry.detach("test-auth-success")
    end
    
    test "emits telemetry events on failed auth", %{conn: conn} do
      :telemetry.attach(
        "test-auth-failure",
        [:wanderer_app, :json_api, :auth],
        fn _event, measurements, metadata, _config ->
          send(self(), {:telemetry_event, measurements, metadata})
        end,
        nil
      )
      
      conn
      |> init_test_session(%{})
      |> put_req_header("authorization", "Bearer invalid_token")
      |> CheckJsonApiAuth.call([])
      
      assert_receive {:telemetry_event, %{count: 1, duration: _}, %{auth_type: "bearer_token", result: "failure"}}
      
      :telemetry.detach("test-auth-failure")
    end
  end
end