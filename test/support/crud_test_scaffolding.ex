defmodule WandererApp.Test.CrudTestScaffolding do
  @moduledoc """
  CRUD Test Scaffolding - Reusable patterns for consistent API testing

  This module provides macros and helper functions to ensure consistent test patterns
  across all CRUD operations. It follows the test pyramid approach and includes
  comprehensive coverage of:

  - Basic CRUD operations (Create, Read, Update, Delete)
  - Validation scenarios
  - Authorization and permission testing  
  - Error handling and edge cases
  - Performance and concurrency considerations
  """

  defmacro __using__(_opts) do
    quote do
      import WandererApp.Test.CrudTestScaffolding
      import ExUnit.Assertions
      import Plug.Conn
      import Phoenix.ConnTest
    end
  end

  @doc """
  Standard CRUD test patterns for API resources.

  ## Parameters
  - `resource_name`: The name of the resource (e.g., "ACL", "System", "Connection")
  - `base_path`: Base API path (e.g., "/api/acls", "/api/maps/:map_id/systems")
  - `auth_type`: Authentication type (:character, :acl, :map)
  - `test_data`: Map containing test data setup functions

  ## Example
      test_crud_operations("ACL", "/api/acls", :acl, %{
        create_params: fn -> %{"name" => "Test ACL", "description" => "Test"} end,
        update_params: fn -> %{"name" => "Updated ACL"} end,
        invalid_params: fn -> %{"name" => ""} end,
        setup_auth: fn -> create_test_acl_with_auth() end
      })
  """
  defmacro test_crud_operations(resource_name, base_path, auth_type, test_data) do
    quote do
      describe "#{unquote(resource_name)} CRUD operations" do
        setup do
          setup_data = unquote(test_data)[:setup_auth].() || %{}
          {:ok, setup_data}
        end

        # READ operations
        test "GET #{unquote(base_path)} - lists all #{unquote(resource_name)}s", context do
          response =
            context[:conn]
            |> authenticate_request(unquote(auth_type), context)
            |> get(build_path(unquote(base_path), context))
            |> assert_success_response(200)

          assert is_list(response["data"])
        end

        test "GET #{unquote(base_path)}/:id - retrieves single #{unquote(resource_name)}",
             context do
          # Create test resource first
          resource = create_test_resource(unquote(resource_name), context)

          response =
            context[:conn]
            |> authenticate_request(unquote(auth_type), context)
            |> get(build_path(unquote(base_path) <> "/#{resource.id}", context))
            |> assert_success_response(200)

          assert response["data"]["id"] == resource.id
        end

        # CREATE operations
        test "POST #{unquote(base_path)} - creates new #{unquote(resource_name)}", context do
          create_params = unquote(test_data)[:create_params].()

          response =
            context[:conn]
            |> authenticate_request(unquote(auth_type), context)
            |> post(build_path(unquote(base_path), context), create_params)
            |> assert_success_response(201)

          # Verify required fields are returned
          assert response["data"]["id"] != nil
          verify_response_matches_input(response["data"], create_params)
        end

        # UPDATE operations
        test "PUT #{unquote(base_path)}/:id - updates #{unquote(resource_name)}", context do
          resource = create_test_resource(unquote(resource_name), context)
          update_params = unquote(test_data)[:update_params].()

          response =
            context[:conn]
            |> authenticate_request(unquote(auth_type), context)
            |> put(build_path(unquote(base_path) <> "/#{resource.id}", context), update_params)
            |> assert_success_response(200)

          assert response["data"]["id"] == resource.id
          verify_response_matches_input(response["data"], update_params)
        end

        # DELETE operations
        test "DELETE #{unquote(base_path)}/:id - removes #{unquote(resource_name)}", context do
          resource = create_test_resource(unquote(resource_name), context)

          context[:conn]
          |> authenticate_request(unquote(auth_type), context)
          |> delete(build_path(unquote(base_path) <> "/#{resource.id}", context))
          |> assert_success_response(204)

          # Verify resource is deleted
          context[:conn]
          |> authenticate_request(unquote(auth_type), context)
          |> get(build_path(unquote(base_path) <> "/#{resource.id}", context))
          |> assert_error_format(404)
        end
      end
    end
  end

  @doc """
  Standard validation test patterns for API resources.
  """
  defmacro test_validation_scenarios(resource_name, base_path, auth_type, test_data) do
    quote do
      describe "#{unquote(resource_name)} validation scenarios" do
        setup do
          setup_data = unquote(test_data)[:setup_auth].() || %{}
          {:ok, setup_data}
        end

        test "POST #{unquote(base_path)} - validates required fields", context do
          invalid_params = unquote(test_data)[:invalid_params].()

          response =
            context[:conn]
            |> authenticate_request(unquote(auth_type), context)
            |> post(build_path(unquote(base_path), context), invalid_params)
            |> assert_error_format(422)

          assert response["errors"] != nil
        end

        test "PUT #{unquote(base_path)}/:id - validates update parameters", context do
          resource = create_test_resource(unquote(resource_name), context)
          invalid_params = unquote(test_data)[:invalid_params].()

          response =
            context[:conn]
            |> authenticate_request(unquote(auth_type), context)
            |> put(build_path(unquote(base_path) <> "/#{resource.id}", context), invalid_params)
            |> assert_error_format(422)

          assert response["errors"] != nil
        end

        test "GET #{unquote(base_path)}/nonexistent - returns 404 for missing resource",
             context do
          context[:conn]
          |> authenticate_request(unquote(auth_type), context)
          |> get(build_path(unquote(base_path) <> "/99999", context))
          |> assert_error_format(404)
        end
      end
    end
  end

  @doc """
  Standard authorization test patterns for API resources.
  """
  defmacro test_authorization_scenarios(resource_name, base_path, auth_type, test_data) do
    quote do
      describe "#{unquote(resource_name)} authorization scenarios" do
        setup do
          setup_data = unquote(test_data)[:setup_auth].() || %{}
          {:ok, setup_data}
        end

        test "GET #{unquote(base_path)} - returns 401 without authentication", context do
          context[:conn]
          |> get(build_path(unquote(base_path), context))
          |> assert_error_format(401)
        end

        test "POST #{unquote(base_path)} - returns 401 without authentication", context do
          create_params = unquote(test_data)[:create_params].()

          context[:conn]
          |> post(build_path(unquote(base_path), context), create_params)
          |> assert_error_format(401)
        end

        test "GET #{unquote(base_path)} - returns 401 with invalid credentials", context do
          context[:conn]
          |> authenticate_request(unquote(auth_type), %{api_key: "invalid-key"})
          |> get(build_path(unquote(base_path), context))
          |> assert_error_format(401)
        end
      end
    end
  end

  @doc """
  Standard concurrency and edge case test patterns.
  """
  defmacro test_edge_case_scenarios(resource_name, base_path, auth_type, test_data) do
    quote do
      describe "#{unquote(resource_name)} edge case scenarios" do
        setup do
          setup_data = unquote(test_data)[:setup_auth].() || %{}
          {:ok, setup_data}
        end

        test "POST #{unquote(base_path)} - handles concurrent creation attempts", context do
          create_params = unquote(test_data)[:create_params].()

          # Simulate concurrent requests
          tasks =
            for _ <- 1..3 do
              Task.async(fn ->
                context[:conn]
                |> authenticate_request(unquote(auth_type), context)
                |> post(build_path(unquote(base_path), context), create_params)
              end)
            end

          results = Enum.map(tasks, &Task.await/1)

          # At least one should succeed
          assert Enum.any?(results, fn conn -> conn.status in [200, 201] end)
        end

        test "PUT #{unquote(base_path)}/:id - handles non-existent resource updates", context do
          update_params = unquote(test_data)[:update_params].()

          context[:conn]
          |> authenticate_request(unquote(auth_type), context)
          |> put(build_path(unquote(base_path) <> "/99999", context), update_params)
          |> assert_error_format(404)
        end

        test "DELETE #{unquote(base_path)}/:id - handles double deletion gracefully", context do
          resource = create_test_resource(unquote(resource_name), context)
          auth_context = context

          # First deletion
          context[:conn]
          |> authenticate_request(unquote(auth_type), auth_context)
          |> delete(build_path(unquote(base_path) <> "/#{resource.id}", context))
          |> assert_success_response(204)

          # Second deletion should return 404
          context[:conn]
          |> authenticate_request(unquote(auth_type), auth_context)
          |> delete(build_path(unquote(base_path) <> "/#{resource.id}", context))
          |> assert_error_format(404)
        end
      end
    end
  end

  # Helper functions

  def authenticate_request(conn, :character, context) do
    # Handle invalid credentials test case
    if context[:api_key] == "invalid-key" do
      conn |> Plug.Conn.put_req_header("authorization", "Bearer invalid-jwt-token")
    else
      WandererApp.ApiCase.authenticate_character(conn, context[:owner] || context[:character])
    end
  end

  def authenticate_request(conn, :acl, context) do
    WandererApp.ApiCase.authenticate_acl(conn, context[:api_key])
  end

  def authenticate_request(conn, :map, context) do
    WandererApp.ApiCase.authenticate_map(conn, context[:api_key])
  end

  def build_path(path, context) do
    path
    |> String.replace(":map_id", context[:map_slug] || context[:map_id] || "test-map")
    |> String.replace(":acl_id", context[:acl_id] || "test-acl")
  end

  def create_test_resource("ACL", context) do
    # Use the character from the test context as the owner
    owner = context[:owner] || context[:character]
    acl_data = WandererApp.ApiCase.create_test_acl_with_auth(%{character: owner})
    acl_data.acl
  end

  def create_test_resource("System", _context) do
    # Systems are created via factory helpers in the actual test context
    %{
      id: :rand.uniform(99_999_999) + 30_000_000,
      solar_system_id: :rand.uniform(99_999_999) + 30_000_000
    }
  end

  def create_test_resource("Connection", _context) do
    # Connections are created via factory helpers in the actual test context  
    %{id: :rand.uniform(99_999_999)}
  end

  def create_test_resource(resource_name, _context) do
    raise "Unknown resource type: #{resource_name}. Please implement create_test_resource for this type."
  end

  def verify_response_matches_input(response_data, input_params) do
    # Verify that response contains the expected values from input
    Enum.each(input_params, fn {key, expected_value} ->
      if is_binary(key) and Map.has_key?(response_data, key) do
        ExUnit.Assertions.assert(
          response_data[key] == expected_value,
          "Expected #{key} to be #{inspect(expected_value)}, got #{inspect(response_data[key])}"
        )
      end
    end)
  end
end
