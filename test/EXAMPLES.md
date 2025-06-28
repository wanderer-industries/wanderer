# WandererApp Test Examples

This document provides practical examples of common test scenarios in the WandererApp project. Use these as templates when writing new tests.

## Table of Contents

1. [API Endpoint Tests](#api-endpoint-tests)
2. [Authentication Tests](#authentication-tests)
3. [Error Handling Tests](#error-handling-tests)
4. [Mock Usage Examples](#mock-usage-examples)
5. [Contract Test Examples](#contract-test-examples)
6. [Performance Test Examples](#performance-test-examples)
7. [WebSocket Test Examples](#websocket-test-examples)

## API Endpoint Tests

### Basic CRUD Operations

```elixir
defmodule WandererAppWeb.MapSystemsAPITest do
  use WandererAppWeb.ConnCase, async: true
  
  alias WandererApp.Test.Factory
  
  describe "systems CRUD operations" do
    setup do
      user = Factory.create_user()
      map = Factory.create_map(%{user_id: user.id})
      api_key = Factory.create_map_api_key(%{map_id: map.id})
      
      %{
        map: map,
        conn: build_conn() |> put_req_header("x-api-key", api_key.key)
      }
    end
    
    test "lists all systems in a map", %{conn: conn, map: map} do
      # Create test data
      systems = for i <- 1..3 do
        Factory.create_map_system(%{
          map_id: map.id,
          solar_system_id: 30000142 + i,
          position_x: i * 100,
          position_y: i * 100
        })
      end
      
      # Make request
      conn = get(conn, "/api/maps/#{map.slug}/systems")
      
      # Assert response
      assert response = json_response(conn, 200)
      assert length(response["data"]) == 3
      
      # Verify each system
      response_ids = Enum.map(response["data"], & &1["solar_system_id"])
      expected_ids = Enum.map(systems, & &1.solar_system_id)
      assert Enum.sort(response_ids) == Enum.sort(expected_ids)
      
      # Check response structure
      first_system = hd(response["data"])
      assert first_system["type"] == "system"
      assert first_system["position_x"]
      assert first_system["position_y"]
    end
    
    test "creates a new system", %{conn: conn, map: map} do
      system_params = %{
        "solar_system_id" => 30000142,
        "position_x" => 100,
        "position_y" => 200,
        "name" => "Jita",
        "description" => "Trade hub"
      }
      
      conn = post(conn, "/api/maps/#{map.slug}/systems", system_params)
      
      assert response = json_response(conn, 201)
      assert response["data"]["solar_system_id"] == 30000142
      assert response["data"]["name"] == "Jita"
      
      # Verify location header
      assert [location] = get_resp_header(conn, "location")
      assert location =~ "/api/maps/#{map.slug}/systems/30000142"
      
      # Verify system was actually created
      conn = get(conn, "/api/maps/#{map.slug}/systems/30000142")
      assert json_response(conn, 200)
    end
    
    test "updates an existing system", %{conn: conn, map: map} do
      system = Factory.create_map_system(map.id, %{
        solar_system_id: 30000142,
        position_x: 100,
        position_y: 100
      })
      
      update_params = %{
        "position_x" => 200,
        "position_y" => 300,
        "description" => "Updated position"
      }
      
      conn = put(conn, "/api/maps/#{map.slug}/systems/#{system.solar_system_id}", update_params)
      
      assert response = json_response(conn, 200)
      assert response["data"]["position_x"] == 200
      assert response["data"]["position_y"] == 300
      assert response["data"]["description"] == "Updated position"
    end
    
    test "deletes a system", %{conn: conn, map: map} do
      system = Factory.create_map_system(map.id)
      
      conn = delete(conn, "/api/maps/#{map.slug}/systems/#{system.solar_system_id}")
      
      assert conn.status == 204
      assert get_resp_header(conn, "content-length") == ["0"]
      
      # Verify deletion
      conn = get(conn, "/api/maps/#{map.slug}/systems/#{system.solar_system_id}")
      assert json_response(conn, 404)
    end
  end
end
```

### Pagination and Filtering

```elixir
defmodule WandererAppWeb.PaginationTest do
  use WandererAppWeb.ConnCase
  
  describe "pagination" do
    setup do
      map = Factory.create_map()
      
      # Create 25 systems
      for i <- 1..25 do
        Factory.create_map_system(map.id, %{
          solar_system_id: 30000100 + i,
          name: "System #{i}"
        })
      end
      
      api_key = Factory.create_map_api_key(%{map_id: map.id})
      
      %{
        map: map,
        conn: build_conn() |> put_req_header("x-api-key", api_key.key)
      }
    end
    
    test "paginates results with limit and offset", %{conn: conn, map: map} do
      # First page
      conn = get(conn, "/api/maps/#{map.slug}/systems?limit=10&offset=0")
      page1 = json_response(conn, 200)
      
      assert length(page1["data"]) == 10
      assert page1["meta"]["total"] == 25
      assert page1["meta"]["limit"] == 10
      assert page1["meta"]["offset"] == 0
      
      # Second page
      conn = get(conn, "/api/maps/#{map.slug}/systems?limit=10&offset=10")
      page2 = json_response(conn, 200)
      
      assert length(page2["data"]) == 10
      assert page2["meta"]["offset"] == 10
      
      # Ensure no overlap
      page1_ids = Enum.map(page1["data"], & &1["solar_system_id"])
      page2_ids = Enum.map(page2["data"], & &1["solar_system_id"])
      assert Enum.empty?(page1_ids -- (page1_ids -- page2_ids))
      
      # Last page
      conn = get(conn, "/api/maps/#{map.slug}/systems?limit=10&offset=20")
      page3 = json_response(conn, 200)
      
      assert length(page3["data"]) == 5
    end
    
    test "filters results by name", %{conn: conn, map: map} do
      conn = get(conn, "/api/maps/#{map.slug}/systems?filter[name]=System 1")
      response = json_response(conn, 200)
      
      # Should match "System 1", "System 10-19"
      assert length(response["data"]) == 11
      assert Enum.all?(response["data"], &String.contains?(&1["name"], "System 1"))
    end
    
    test "sorts results", %{conn: conn, map: map} do
      # Sort by name ascending
      conn = get(conn, "/api/maps/#{map.slug}/systems?sort=name&limit=5")
      response = json_response(conn, 200)
      
      names = Enum.map(response["data"], & &1["name"])
      assert names == Enum.sort(names)
      
      # Sort by name descending
      conn = get(conn, "/api/maps/#{map.slug}/systems?sort=-name&limit=5")
      response = json_response(conn, 200)
      
      names = Enum.map(response["data"], & &1["name"])
      assert names == Enum.sort(names, :desc)
    end
  end
end
```

## Authentication Tests

### API Key Authentication

```elixir
defmodule WandererAppWeb.APIKeyAuthTest do
  use WandererAppWeb.ConnCase
  
  describe "API key authentication" do
    setup do
      user = Factory.create_user()
      map = Factory.create_map(%{user_id: user.id})
      %{map: map, user: user}
    end
    
    test "accepts valid API key in header", %{map: map} do
      api_key = Factory.create_map_api_key(%{map_id: map.id})
      
      conn = 
        build_conn()
        |> put_req_header("x-api-key", api_key.key)
        |> get("/api/maps/#{map.slug}")
      
      assert json_response(conn, 200)
    end
    
    test "accepts valid API key in query params", %{map: map} do
      api_key = Factory.create_map_api_key(%{map_id: map.id})
      
      conn = get(build_conn(), "/api/maps/#{map.slug}?api_key=#{api_key.key}")
      
      assert json_response(conn, 200)
    end
    
    test "rejects invalid API key", %{map: map} do
      conn = 
        build_conn()
        |> put_req_header("x-api-key", "invalid-key-12345")
        |> get("/api/maps/#{map.slug}")
      
      assert response = json_response(conn, 401)
      assert response["errors"]["status"] == "401"
      assert response["errors"]["title"] == "Unauthorized"
      assert response["errors"]["detail"] =~ "Invalid API key"
    end
    
    test "rejects missing API key", %{map: map} do
      conn = get(build_conn(), "/api/maps/#{map.slug}")
      
      assert response = json_response(conn, 401)
      assert response["errors"]["detail"] =~ "API key required"
    end
    
    test "rejects expired API key", %{map: map} do
      # Create expired key
      expired_key = Factory.create_map_api_key(%{
        map_id: map.id,
        expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
      })
      
      conn = 
        build_conn()
        |> put_req_header("x-api-key", expired_key.key)
        |> get("/api/maps/#{map.slug}")
      
      assert response = json_response(conn, 401)
      assert response["errors"]["detail"] =~ "API key expired"
    end
    
    test "rejects revoked API key", %{map: map} do
      revoked_key = Factory.create_map_api_key(%{
        map_id: map.id,
        revoked: true
      })
      
      conn = 
        build_conn()
        |> put_req_header("x-api-key", revoked_key.key)
        |> get("/api/maps/#{map.slug}")
      
      assert response = json_response(conn, 401)
      assert response["errors"]["detail"] =~ "API key revoked"
    end
  end
end
```

### Permission Tests

```elixir
defmodule WandererAppWeb.PermissionTest do
  use WandererAppWeb.ConnCase
  
  describe "ACL permissions" do
    setup do
      owner = Factory.create_user()
      member = Factory.create_user()
      map = Factory.create_map(%{user_id: owner.id})
      
      # Create ACL with member
      acl = Factory.create_access_list(%{map_id: map.id})
      Factory.create_access_list_member(%{
        access_list_id: acl.id,
        character_id: member.character_id,
        role: "viewer"
      })
      
      # Create API keys
      owner_key = Factory.create_map_api_key(%{map_id: map.id, user_id: owner.id})
      acl_key = Factory.create_acl_api_key(%{access_list_id: acl.id})
      
      %{
        map: map,
        owner: owner,
        member: member,
        owner_key: owner_key,
        acl_key: acl_key
      }
    end
    
    test "owner can perform all operations", %{map: map, owner_key: owner_key} do
      conn = build_conn() |> put_req_header("x-api-key", owner_key.key)
      
      # Can read
      conn = get(conn, "/api/maps/#{map.slug}")
      assert json_response(conn, 200)
      
      # Can create
      conn = post(conn, "/api/maps/#{map.slug}/systems", %{
        "solar_system_id" => 30000142,
        "position_x" => 100,
        "position_y" => 200
      })
      assert json_response(conn, 201)
      
      # Can update
      conn = put(conn, "/api/maps/#{map.slug}", %{"name" => "Updated Name"})
      assert json_response(conn, 200)
      
      # Can delete
      conn = delete(conn, "/api/maps/#{map.slug}/systems/30000142")
      assert conn.status == 204
    end
    
    test "viewer can only read", %{map: map, acl_key: acl_key} do
      conn = build_conn() |> put_req_header("x-api-key", acl_key.key)
      
      # Can read
      conn = get(conn, "/api/maps/#{map.slug}")
      assert json_response(conn, 200)
      
      # Cannot create
      conn = post(conn, "/api/maps/#{map.slug}/systems", %{
        "solar_system_id" => 30000142,
        "position_x" => 100,
        "position_y" => 200
      })
      assert response = json_response(conn, 403)
      assert response["errors"]["detail"] =~ "permission" or 
             response["errors"]["detail"] =~ "forbidden"
      
      # Cannot update
      conn = put(conn, "/api/maps/#{map.slug}", %{"name" => "Updated Name"})
      assert json_response(conn, 403)
      
      # Cannot delete
      conn = delete(conn, "/api/maps/#{map.slug}")
      assert json_response(conn, 403)
    end
  end
end
```

## Error Handling Tests

### Validation Errors

```elixir
defmodule WandererAppWeb.ValidationErrorTest do
  use WandererAppWeb.ConnCase
  
  describe "input validation" do
    setup [:create_authenticated_conn]
    
    test "validates required fields", %{conn: conn, map: map} do
      # Missing required fields
      conn = post(conn, "/api/maps/#{map.slug}/systems", %{})
      
      assert response = json_response(conn, 422)
      assert response["errors"]["status"] == "422"
      assert response["errors"]["title"] == "Unprocessable Entity"
      assert response["errors"]["detail"] =~ "required"
      
      # Check for field-specific errors
      assert response["errors"]["fields"]["solar_system_id"] =~ "required"
      assert response["errors"]["fields"]["position_x"] =~ "required"
      assert response["errors"]["fields"]["position_y"] =~ "required"
    end
    
    test "validates field types", %{conn: conn, map: map} do
      invalid_params = %{
        "solar_system_id" => "not-a-number",
        "position_x" => "invalid",
        "position_y" => [1, 2, 3]
      }
      
      conn = post(conn, "/api/maps/#{map.slug}/systems", invalid_params)
      
      assert response = json_response(conn, 422)
      assert response["errors"]["fields"]["solar_system_id"] =~ "must be an integer"
      assert response["errors"]["fields"]["position_x"] =~ "must be a number"
      assert response["errors"]["fields"]["position_y"] =~ "must be a number"
    end
    
    test "validates field constraints", %{conn: conn, map: map} do
      params = %{
        "solar_system_id" => -1, # Invalid EVE system ID
        "position_x" => 99999999, # Too large
        "position_y" => -99999999, # Too small
        "name" => String.duplicate("a", 500) # Too long
      }
      
      conn = post(conn, "/api/maps/#{map.slug}/systems", params)
      
      assert response = json_response(conn, 422)
      assert response["errors"]["fields"]["solar_system_id"] =~ "must be positive"
      assert response["errors"]["fields"]["name"] =~ "too long"
    end
    
    test "validates business rules", %{conn: conn, map: map} do
      # Create a system
      Factory.create_map_system(map.id, %{solar_system_id: 30000142})
      
      # Try to create duplicate
      conn = post(conn, "/api/maps/#{map.slug}/systems", %{
        "solar_system_id" => 30000142,
        "position_x" => 100,
        "position_y" => 200
      })
      
      assert response = json_response(conn, 422)
      assert response["errors"]["detail"] =~ "already exists" or
             response["errors"]["detail"] =~ "duplicate"
    end
  end
  
  defp create_authenticated_conn(_) do
    map = Factory.create_map()
    api_key = Factory.create_map_api_key(%{map_id: map.id})
    
    %{
      map: map,
      conn: build_conn() |> put_req_header("x-api-key", api_key.key)
    }
  end
end
```

### Service Error Handling

```elixir
defmodule WandererAppWeb.ServiceErrorTest do
  use WandererAppWeb.ConnCase
  import Mox
  
  setup :verify_on_exit!
  
  describe "external service errors" do
    setup [:create_authenticated_conn]
    
    test "handles EVE API timeout", %{conn: conn} do
      Test.EVEAPIClientMock
      |> expect(:get_system_info, fn _system_id ->
        {:error, :timeout}
      end)
      
      conn = get(conn, "/api/common/systems/30000142")
      
      assert response = json_response(conn, 503)
      assert response["errors"]["status"] == "503"
      assert response["errors"]["title"] == "Service Unavailable"
      assert response["errors"]["detail"] =~ "temporarily unavailable"
      
      # Should include retry information
      assert response["errors"]["meta"]["retry_after"]
    end
    
    test "handles database connection errors", %{conn: conn, map: map} do
      # This is harder to test without actually breaking the DB
      # In practice, you might use a custom Repo wrapper for testing
      
      # Simulate by mocking Ecto.Adapters.SQL
      Test.RepoMock
      |> expect(:all, fn _query ->
        {:error, %DBConnection.ConnectionError{message: "connection timeout"}}
      end)
      
      conn = get(conn, "/api/maps/#{map.slug}/systems")
      
      assert response = json_response(conn, 503)
      assert response["errors"]["detail"] =~ "database" or
             response["errors"]["detail"] =~ "connection"
    end
    
    test "handles cache failures gracefully", %{conn: conn, map: map} do
      Test.CacheMock
      |> expect(:get, fn _key ->
        {:error, :connection_refused}
      end)
      |> stub(:put, fn _key, _value, _opts ->
        {:error, :connection_refused}
      end)
      
      # Should still work without cache
      conn = get(conn, "/api/maps/#{map.slug}")
      assert json_response(conn, 200)
    end
  end
end
```

## Mock Usage Examples

### Complex Mock Scenarios

```elixir
defmodule WandererApp.ComplexMockTest do
  use WandererApp.DataCase
  import Mox
  
  setup :verify_on_exit!
  
  describe "complex service interactions" do
    test "fetches and caches character with corporation info" do
      character_id = 123456789
      corporation_id = 987654321
      
      # Mock EVE API calls in sequence
      Test.EVEAPIClientMock
      |> expect(:get_character_info, fn ^character_id ->
        {:ok, %{
          "name" => "Test Character",
          "corporation_id" => corporation_id,
          "birthday" => "2020-01-01T00:00:00Z"
        }}
      end)
      |> expect(:get_corporation_info, fn ^corporation_id ->
        {:ok, %{
          "name" => "Test Corporation",
          "ticker" => "TEST",
          "member_count" => 100
        }}
      end)
      
      # Mock cache interactions
      Test.CacheMock
      |> expect(:get, fn key ->
        assert key in ["character:#{character_id}", "corporation:#{corporation_id}"]
        {:error, :not_found}
      end)
      |> expect(:put, 2, fn key, value, opts ->
        assert key in ["character:#{character_id}", "corporation:#{corporation_id}"]
        assert opts[:ttl] in [3600, 7200]
        assert is_map(value)
        :ok
      end)
      
      # Mock PubSub notification
      Test.PubSubMock
      |> expect(:publish, fn topic, message ->
        assert topic == "character:updates"
        assert message.character_id == character_id
        :ok
      end)
      
      # Execute the function
      {:ok, character} = WandererApp.Characters.fetch_character_with_corp(character_id)
      
      # Verify the result
      assert character.name == "Test Character"
      assert character.corporation.name == "Test Corporation"
      assert character.corporation.ticker == "TEST"
    end
    
    test "handles partial failures with fallbacks" do
      Test.EVEAPIClientMock
      |> expect(:get_character_info, fn _id ->
        {:ok, %{"name" => "Test Character"}}
      end)
      |> expect(:get_character_location, fn _id ->
        {:error, :rate_limited}
      end)
      
      Test.CacheMock
      |> expect(:get, fn "character:location:123" ->
        # Return cached location
        {:ok, %{solar_system_id: 30000142, last_updated: DateTime.utc_now()}}
      end)
      
      {:ok, character} = WandererApp.Characters.fetch_character_full(123)
      
      assert character.name == "Test Character"
      assert character.location.solar_system_id == 30000142
      assert character.location.source == :cache
    end
  end
end
```

### Stub vs Expect

```elixir
defmodule WandererApp.StubVsExpectTest do
  use WandererApp.DataCase
  import Mox
  
  describe "when to use stub vs expect" do
    test "use stub for optional background operations" do
      # Logger calls are optional - use stub
      Test.LoggerMock
      |> stub(:info, fn _msg -> :ok end)
      |> stub(:debug, fn _msg -> :ok end)
      
      # Cache writes are optional - use stub
      Test.CacheMock
      |> stub(:put, fn _key, _value, _opts -> :ok end)
      
      # Business logic doesn't fail if these don't happen
      assert {:ok, _result} = WandererApp.SomeModule.do_work()
    end
    
    test "use expect for critical operations" do
      # This MUST be called exactly once
      Test.EVEAPIClientMock
      |> expect(:verify_token, 1, fn token ->
        assert token == "test-token"
        {:ok, %{character_id: 123}}
      end)
      
      # This MUST be called with specific params
      Test.DatabaseMock
      |> expect(:insert_character, fn character ->
        assert character.id == 123
        {:ok, character}
      end)
      
      # Test will fail if expectations aren't met
      assert {:ok, _} = WandererApp.Auth.verify_and_create("test-token")
    end
    
    test "combine stub and expect" do
      # Required call
      Test.EVEAPIClientMock
      |> expect(:get_character_info, fn _id ->
        {:ok, %{name: "Test"}}
      end)
      
      # Optional calls that might happen 0+ times
      Test.CacheMock
      |> stub(:get, fn _key -> {:error, :not_found} end)
      |> stub(:put, fn _key, _value, _opts -> :ok end)
      
      Test.LoggerMock
      |> stub(:info, fn _msg -> :ok end)
      
      assert {:ok, _} = WandererApp.Characters.fetch_character(123)
    end
  end
end
```

## Contract Test Examples

### OpenAPI Validation

```elixir
defmodule WandererAppWeb.OpenAPIContractTest do
  use WandererAppWeb.ConnCase
  use WandererAppWeb.OpenAPICase
  
  describe "API contract validation" do
    setup [:create_test_data]
    
    test "validates all endpoints against OpenAPI spec", %{conn: conn, map: map} do
      # Test each endpoint defined in OpenAPI spec
      for operation <- get_all_operations() do
        test_operation_contract(conn, operation, %{
          map_slug: map.slug,
          system_id: "30000142"
        })
      end
    end
    
    test "POST /api/maps/:slug/systems matches schema", %{conn: conn, map: map} do
      request_body = %{
        "solar_system_id" => 30000142,
        "position_x" => 100.5,
        "position_y" => 200.5,
        "name" => "Jita",
        "description" => "Major trade hub",
        "locked" => false,
        "rally_point" => true
      }
      
      # Validate request matches schema
      assert_valid_request_body(request_body, "CreateSystemRequest")
      
      # Make request
      conn = 
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/maps/#{map.slug}/systems", request_body)
      
      # Validate response
      assert response = json_response(conn, 201)
      assert_valid_response(response, 201, "CreateSystemResponse")
      
      # Validate response headers
      assert_required_headers(conn, ["content-type", "location"])
      assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
      
      # Validate response data types
      assert is_integer(response["data"]["solar_system_id"])
      assert is_float(response["data"]["position_x"])
      assert is_boolean(response["data"]["locked"])
      assert is_binary(response["data"]["created_at"])
      assert DateTime.from_iso8601(response["data"]["created_at"])
    end
    
    test "error responses match error schema", %{conn: conn} do
      # Test various error scenarios
      error_cases = [
        {"/api/maps/nonexistent", 404, "Not Found"},
        {"/api/maps/test", 401, "Unauthorized"}, # No API key
      ]
      
      for {path, status, title} <- error_cases do
        conn = get(build_conn(), path)
        
        assert response = json_response(conn, status)
        assert_valid_response(response, status, "ErrorResponse")
        
        assert response["errors"]["status"] == to_string(status)
        assert response["errors"]["title"] == title
        assert is_binary(response["errors"]["detail"])
        assert is_binary(response["errors"]["id"])
      end
    end
  end
  
  defp test_operation_contract(conn, operation, params) do
    path = build_path(operation.path, params)
    
    case operation.method do
      :get ->
        conn = get(conn, path)
        assert conn.status in operation.expected_statuses
        
      :post ->
        body = build_request_body(operation.request_schema)
        conn = post(conn, path, body)
        assert conn.status in operation.expected_statuses
        
      _ ->
        # Handle other methods
    end
    
    if conn.status < 400 do
      response = json_response(conn, conn.status)
      assert_valid_response(response, conn.status, operation.response_schema)
    end
  end
end
```

## Performance Test Examples

### Load Testing

```elixir
defmodule WandererAppWeb.PerformanceTest do
  use WandererAppWeb.ConnCase
  
  @tag :performance
  @tag timeout: :infinity
  describe "API performance under load" do
    setup do
      # Create test data
      map = Factory.create_map()
      
      # Create many systems
      systems = for i <- 1..1000 do
        Factory.create_map_system(map.id, %{
          solar_system_id: 30000000 + i
        })
      end
      
      api_key = Factory.create_map_api_key(%{map_id: map.id})
      
      %{
        map: map,
        systems: systems,
        api_key: api_key
      }
    end
    
    test "handles concurrent read requests", %{map: map, api_key: api_key} do
      # Warm up
      conn = 
        build_conn()
        |> put_req_header("x-api-key", api_key.key)
        |> get("/api/maps/#{map.slug}/systems")
      assert json_response(conn, 200)
      
      # Measure concurrent performance
      concurrency_levels = [10, 50, 100]
      
      for concurrency <- concurrency_levels do
        {time, results} = :timer.tc(fn ->
          tasks = for _ <- 1..concurrency do
            Task.async(fn ->
              conn = 
                build_conn()
                |> put_req_header("x-api-key", api_key.key)
                |> get("/api/maps/#{map.slug}/systems")
              
              {conn.status, byte_size(conn.resp_body)}
            end)
          end
          
          Task.await_many(tasks, 30_000)
        end)
        
        # All should succeed
        assert Enum.all?(results, fn {status, _size} -> status == 200 end)
        
        # Calculate metrics
        avg_time = time / concurrency / 1000 # ms
        requests_per_sec = concurrency * 1_000_000 / time
        
        IO.puts("Concurrency: #{concurrency}")
        IO.puts("  Total time: #{time / 1_000}ms")
        IO.puts("  Avg time per request: #{Float.round(avg_time, 2)}ms")
        IO.puts("  Requests/sec: #{Float.round(requests_per_sec, 2)}")
        
        # Performance assertions
        assert avg_time < 100, "Average response time should be under 100ms"
        assert requests_per_sec > 10, "Should handle at least 10 requests/sec"
      end
    end
    
    test "handles large response payloads efficiently", %{map: map, api_key: api_key} do
      # Request all systems (1000 items)
      {time, conn} = :timer.tc(fn ->
        build_conn()
        |> put_req_header("x-api-key", api_key.key)
        |> get("/api/maps/#{map.slug}/systems?limit=1000")
      end)
      
      assert response = json_response(conn, 200)
      assert length(response["data"]) == 1000
      
      # Check performance
      response_size = byte_size(conn.resp_body)
      time_ms = time / 1000
      
      IO.puts("Large payload performance:")
      IO.puts("  Response size: #{response_size / 1024}KB")
      IO.puts("  Response time: #{time_ms}ms")
      IO.puts("  Throughput: #{Float.round(response_size / time * 1000, 2)}KB/s")
      
      # Should complete in reasonable time
      assert time_ms < 1000, "Large payload should return in under 1 second"
    end
    
    test "write operations maintain performance", %{map: map, api_key: api_key} do
      write_times = for i <- 1..10 do
        system_params = %{
          "solar_system_id" => 31000000 + i,
          "position_x" => i * 10,
          "position_y" => i * 10
        }
        
        {time, conn} = :timer.tc(fn ->
          build_conn()
          |> put_req_header("x-api-key", api_key.key)
          |> put_req_header("content-type", "application/json")
          |> post("/api/maps/#{map.slug}/systems", system_params)
        end)
        
        assert json_response(conn, 201)
        time / 1000 # Convert to ms
      end
      
      avg_write_time = Enum.sum(write_times) / length(write_times)
      max_write_time = Enum.max(write_times)
      
      IO.puts("Write operation performance:")
      IO.puts("  Average time: #{Float.round(avg_write_time, 2)}ms")
      IO.puts("  Max time: #{Float.round(max_write_time, 2)}ms")
      
      assert avg_write_time < 200, "Writes should average under 200ms"
      assert max_write_time < 500, "No write should take over 500ms"
    end
  end
end
```

## WebSocket Test Examples

### Real-time Updates

```elixir
defmodule WandererAppWeb.WebSocketTest do
  use WandererAppWeb.ChannelCase
  
  alias WandererAppWeb.MapChannel
  
  describe "map real-time updates" do
    setup do
      user = Factory.create_user()
      map = Factory.create_map(%{user_id: user.id})
      
      # Connect to channel
      {:ok, socket} = connect(WandererAppWeb.UserSocket, %{
        "token" => generate_user_token(user)
      })
      
      {:ok, _reply, socket} = subscribe_and_join(
        socket,
        MapChannel,
        "map:#{map.slug}",
        %{}
      )
      
      %{socket: socket, map: map, user: user}
    end
    
    test "broadcasts system creation", %{socket: socket, map: map} do
      # Create system via API (would trigger broadcast)
      system_data = %{
        solar_system_id: 30000142,
        position_x: 100,
        position_y: 200,
        name: "Jita"
      }
      
      # Simulate the broadcast that would happen
      broadcast_from!(socket, "system:created", %{
        "system" => system_data
      })
      
      # Client should receive the event
      assert_push "system:created", %{system: pushed_system}
      assert pushed_system.solar_system_id == 30000142
      assert pushed_system.name == "Jita"
    end
    
    test "broadcasts system updates to all connected clients", %{map: map} do
      # Connect multiple clients
      clients = for i <- 1..3 do
        user = Factory.create_user()
        {:ok, socket} = connect(WandererAppWeb.UserSocket, %{
          "token" => generate_user_token(user)
        })
        
        {:ok, _reply, socket} = subscribe_and_join(
          socket,
          MapChannel,
          "map:#{map.slug}",
          %{}
        )
        
        {user, socket}
      end
      
      # Broadcast update from first client
      {_user1, socket1} = hd(clients)
      
      broadcast_from!(socket1, "system:updated", %{
        "system_id" => 30000142,
        "changes" => %{"position_x" => 150}
      })
      
      # All other clients should receive it
      for {_user, socket} <- tl(clients) do
        assert_push "system:updated", payload, 1000
        assert payload.system_id == 30000142
        assert payload.changes.position_x == 150
      end
    end
    
    test "handles presence tracking", %{socket: socket, map: map} do
      # Track user presence
      {:ok, _} = WandererAppWeb.Presence.track(
        socket,
        socket.assigns.user_id,
        %{
          character_name: "Test Character",
          online_at: System.system_time(:second)
        }
      )
      
      # Should receive presence state
      assert_push "presence_state", state
      assert map_size(state) == 1
      
      # Another user joins
      user2 = Factory.create_user()
      {:ok, socket2} = connect(WandererAppWeb.UserSocket, %{
        "token" => generate_user_token(user2)
      })
      
      {:ok, _reply, socket2} = subscribe_and_join(
        socket2,
        MapChannel,
        "map:#{map.slug}",
        %{}
      )
      
      # Should receive presence diff
      assert_push "presence_diff", %{joins: joins, leaves: leaves}
      assert map_size(joins) == 1
      assert leaves == %{}
      
      # User leaves
      Process.unlink(socket2.channel_pid)
      ref = leave(socket2)
      assert_reply ref, :ok
      
      # Should receive leave event
      assert_push "presence_diff", %{joins: joins, leaves: leaves}
      assert joins == %{}
      assert map_size(leaves) == 1
    end
    
    test "authorizes actions based on permissions", %{socket: socket, map: map} do
      # Try to delete system as non-owner
      ref = push(socket, "system:delete", %{"system_id" => 30000142})
      
      assert_reply ref, :error, %{reason: "unauthorized"}
      
      # Should not broadcast to others
      refute_push "system:deleted", _
    end
  end
  
  defp generate_user_token(user) do
    # Generate a Phoenix token for the user
    Phoenix.Token.sign(WandererAppWeb.Endpoint, "user socket", user.id)
  end
end
```

---

These examples demonstrate the various testing patterns used in the WandererApp project. Each example includes:

1. **Setup**: Creating necessary test data
2. **Execution**: Performing the action being tested
3. **Assertions**: Verifying the expected behavior
4. **Cleanup**: Handled automatically by ExUnit

Remember to:
- Use descriptive test names
- Keep tests focused and independent
- Mock external dependencies
- Test both success and failure cases
- Validate API contracts
- Monitor performance characteristics