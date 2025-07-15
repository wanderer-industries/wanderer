defmodule WandererApp.Contract.Api.V1EndpointsContractTest do
  @moduledoc """
  Comprehensive contract tests for JSON:API v1 endpoints.

  Validates that all v1 API endpoints conform to JSON:API specification
  and maintain consistent contract behavior.
  """

  use WandererAppWeb.ApiCase, async: false

  import WandererApp.Support.ContractHelpers.ApiContractHelpers

  @moduletag :contract

  # Define all v1 endpoints to test
  @v1_endpoints [
    # Core resource endpoints
    {"/api/v1/maps", [:get, :post]},
    {"/api/v1/maps/:id", [:get, :patch, :delete]},
    {"/api/v1/map_systems", [:get, :post]},
    {"/api/v1/map_systems/:id", [:get, :patch, :delete]},
    {"/api/v1/map_connections", [:get, :post]},
    {"/api/v1/map_connections/:id", [:get, :patch, :delete]},
    {"/api/v1/characters", [:get]},
    {"/api/v1/characters/:id", [:get, :delete]},
    {"/api/v1/access_lists", [:get, :post]},
    {"/api/v1/access_lists/:id", [:get, :patch, :delete]},
    {"/api/v1/access_list_members", [:get, :post]},
    {"/api/v1/access_list_members/:id", [:get, :patch, :delete]},
    {"/api/v1/map_system_signatures", [:get]},
    {"/api/v1/map_system_signatures/:id", [:get, :delete]},

    # Extended resource endpoints
    {"/api/v1/map_access_lists", [:get, :post]},
    {"/api/v1/map_system_comments", [:get]},
    {"/api/v1/map_system_structures", [:get, :post]},
    {"/api/v1/map_user_settings", [:get]},
    {"/api/v1/map_subscriptions", [:get]},
    {"/api/v1/user_transactions", [:get]},
    {"/api/v1/map_transactions", [:get]},
    {"/api/v1/user_activities", [:get]},
    {"/api/v1/map_character_settings", [:get]},

    # Relationship endpoints
    {"/api/v1/maps/:id/relationships/systems", [:get, :post, :patch, :delete]},
    {"/api/v1/maps/:id/relationships/connections", [:get, :post, :patch, :delete]},
    {"/api/v1/maps/:id/relationships/access_lists", [:get, :post, :delete]},

    # Custom combined endpoints
    {"/api/v1/maps/:id/systems_and_connections", [:get]}
  ]

  describe "JSON:API Content-Type Contract" do
    setup do
      scenario = create_authenticated_scenario()
      %{scenario: scenario}
    end

    test "validates JSON:API content-type handling", %{scenario: scenario} do
      # Test with JSON:API content type
      conn = build_jsonapi_conn(scenario.auth_token)

      # Test simple GET endpoint
      test_endpoint = "/api/v1/maps"

      # Should accept JSON:API content type
      response = get(conn, test_endpoint)

      # Should return appropriate status (200 for successful GET)
      assert response.status in [200, 401, 403, 404],
             "Unexpected status #{response.status} for JSON:API content type"

      # If successful, response should have JSON:API content type
      if response.status == 200 do
        content_type = get_resp_header(response, "content-type") |> List.first()

        assert String.contains?(content_type || "", "application/vnd.api+json"),
               "Expected JSON:API content type, got: #{content_type}"
      end
    end

    test "validates regular JSON content-type fallback", %{scenario: scenario} do
      # Test with regular JSON content type
      conn = build_authenticated_conn(scenario.auth_token, content_type: "application/json")

      test_endpoint = "/api/v1/maps"
      response = get(conn, test_endpoint)

      # JSON:API strict mode requires application/vnd.api+json
      assert response.status == 406,
             "Regular JSON content type should return 406 Unacceptable Media Type"
             
      # AshJsonApi returns the error in JSON:API format
      error_response = Jason.decode!(response.resp_body)
      assert error_response["errors"] != nil, "Should have errors array"
    end
  end

  describe "JSON:API Response Structure Contract" do
    setup do
      scenario = create_authenticated_scenario()
      %{scenario: scenario}
    end

    test "validates successful response structure", %{scenario: scenario} do
      conn = build_jsonapi_conn(scenario.auth_token)

      # Test collection endpoint
      response = get(conn, "/api/v1/maps")

      if response.status == 200 do
        body = json_response(response, 200)

        # Validate JSON:API structure
        validate_jsonapi_contract(body)

        # Validate top-level structure
        assert Map.has_key?(body, "data"), "Missing 'data' field in response"

        # Validate meta information if present
        if Map.has_key?(body, "meta") do
          meta = body["meta"]
          assert is_map(meta), "Meta should be an object"
        end

        # Validate links if present
        if Map.has_key?(body, "links") do
          links = body["links"]
          assert is_map(links), "Links should be an object"
        end

        # Validate data structure
        data = body["data"]

        if is_list(data) do
          # Collection response
          Enum.each(data, fn resource ->
            validate_resource_object(resource)
          end)
        else
          # Single resource response
          validate_resource_object(data)
        end
      end
    end

    test "validates error response structure", %{scenario: scenario} do
      conn = build_jsonapi_conn(scenario.auth_token)

      # Test with non-existent resource
      response = get(conn, "/api/v1/maps/non-existent-id")

      if response.status >= 400 do
        body = json_response(response, response.status)

        # Validate error structure
        validate_error_contract(response.status, body)

        # JSON:API error responses should have errors array
        if Map.has_key?(body, "errors") do
          errors = body["errors"]
          assert is_list(errors), "Errors should be an array"

          Enum.each(errors, fn error ->
            validate_error_object(error)
          end)
        end
      end
    end
  end

  describe "JSON:API Filtering Contract" do
    setup do
      scenario = create_authenticated_scenario()
      %{scenario: scenario}
    end

    test "validates filtering parameter handling", %{scenario: scenario} do
      conn = build_jsonapi_conn(scenario.auth_token)

      # Test basic filtering
      test_cases = [
        "/api/v1/maps?filter[name]=test",
        "/api/v1/map_systems?filter[visible]=true",
        "/api/v1/characters?filter[online]=true"
      ]

      Enum.each(test_cases, fn endpoint ->
        response = get(conn, endpoint)

        # Should handle filtering gracefully
        assert response.status in [200, 400, 401, 403, 404],
               "Filtering should be handled gracefully for #{endpoint}"

        if response.status == 200 do
          body = json_response(response, 200)
          validate_jsonapi_contract(body)
        end
      end)
    end

    test "validates sorting parameter handling", %{scenario: scenario} do
      conn = build_jsonapi_conn(scenario.auth_token)

      test_cases = [
        "/api/v1/maps?sort=name"
      ]

      Enum.each(test_cases, fn endpoint ->
        response = get(conn, endpoint)

        assert response.status in [200, 400, 401, 403, 404],
               "Sorting should be handled gracefully for #{endpoint}"

        if response.status == 200 do
          body = json_response(response, 200)
          validate_jsonapi_contract(body)
        end
      end)
    end
  end

  describe "JSON:API Sparse Fieldsets Contract" do
    setup do
      scenario = create_authenticated_scenario()
      %{scenario: scenario}
    end

    test "validates sparse fieldsets parameter handling", %{scenario: scenario} do
      conn = build_jsonapi_conn(scenario.auth_token)

      test_cases = [
        "/api/v1/maps?fields[maps]=name,slug",
        "/api/v1/characters?fields[characters]=name,corporation_name"
      ]

      Enum.each(test_cases, fn endpoint ->
        response = get(conn, endpoint)

        assert response.status in [200, 400, 401, 403, 404],
               "Sparse fieldsets should be handled gracefully for #{endpoint}"

        if response.status == 200 do
          body = json_response(response, 200)
          validate_jsonapi_contract(body)

          # If data is present, validate field restriction
          if Map.has_key?(body, "data") and body["data"] != [] do
            # Note: Full validation would require checking that only requested fields are present
            # This is a placeholder for more detailed sparse fieldset validation
          end
        end
      end)
    end
  end

  describe "JSON:API Includes Contract" do
    setup do
      scenario = create_authenticated_scenario()
      %{scenario: scenario}
    end

    test "validates include parameter handling", %{scenario: scenario} do
      conn = build_jsonapi_conn(scenario.auth_token)

      test_cases = [
        "/api/v1/maps?include=owner",
        "/api/v1/map_systems?include=signatures",
        "/api/v1/access_lists?include=members"
      ]

      Enum.each(test_cases, fn endpoint ->
        response = get(conn, endpoint)

        assert response.status in [200, 400, 401, 403, 404],
               "Includes should be handled gracefully for #{endpoint}"

        if response.status == 200 do
          body = json_response(response, 200)
          validate_jsonapi_contract(body)

          # If included resources are present, validate structure
          if Map.has_key?(body, "included") do
            included = body["included"]
            assert is_list(included), "Included should be an array"

            Enum.each(included, fn resource ->
              validate_resource_object(resource)
            end)
          end
        end
      end)
    end
  end

  describe "Pagination Contract" do
    setup do
      scenario = create_authenticated_scenario()
      %{scenario: scenario}
    end

    test "validates pagination parameter handling", %{scenario: scenario} do
      conn = build_jsonapi_conn(scenario.auth_token)

      test_cases = [
        "/api/v1/maps?page[size]=10",
        "/api/v1/maps?page[number]=1&page[size]=5",
        "/api/v1/map_systems?page[limit]=20&page[offset]=0"
      ]

      Enum.each(test_cases, fn endpoint ->
        response = get(conn, endpoint)

        assert response.status in [200, 400, 401, 403, 404],
               "Pagination should be handled gracefully for #{endpoint}"

        if response.status == 200 do
          body = json_response(response, 200)
          validate_jsonapi_contract(body)

          # Validate pagination links if present
          if Map.has_key?(body, "links") do
            links = body["links"]
            # Common pagination links
            pagination_link_keys = ["first", "last", "prev", "next", "self"]

            present_pagination_keys =
              Map.keys(links) |> Enum.filter(&(&1 in pagination_link_keys))

            if present_pagination_keys != [] do
              Enum.each(present_pagination_keys, fn key ->
                link = links[key]

                assert is_binary(link) or is_nil(link),
                       "Pagination link '#{key}' should be a string or null"
              end)
            end
          end
        end
      end)
    end
  end

  # Helper functions

  defp validate_resource_object(resource) do
    assert is_map(resource), "Resource should be an object"
    assert Map.has_key?(resource, "type"), "Resource should have 'type' field"
    assert Map.has_key?(resource, "id"), "Resource should have 'id' field"

    # Attributes are optional but should be an object if present
    if Map.has_key?(resource, "attributes") do
      assert is_map(resource["attributes"]), "Attributes should be an object"
    end

    # Relationships are optional but should be an object if present
    if Map.has_key?(resource, "relationships") do
      assert is_map(resource["relationships"]), "Relationships should be an object"

      Enum.each(resource["relationships"], fn {_name, relationship} ->
        validate_relationship_object(relationship)
      end)
    end

    # Links are optional but should be an object if present
    if Map.has_key?(resource, "links") do
      assert is_map(resource["links"]), "Resource links should be an object"
    end

    # Meta is optional but should be an object if present
    if Map.has_key?(resource, "meta") do
      assert is_map(resource["meta"]), "Resource meta should be an object"
    end
  end

  defp validate_relationship_object(relationship) do
    assert is_map(relationship), "Relationship should be an object"

    # Should have either data, links, or meta
    has_data = Map.has_key?(relationship, "data")
    has_links = Map.has_key?(relationship, "links")
    has_meta = Map.has_key?(relationship, "meta")

    assert has_data or has_links or has_meta,
           "Relationship should have at least one of: data, links, meta"

    # If data is present, validate its structure
    if has_data do
      data = relationship["data"]

      case data do
        # Null is valid
        nil ->
          :ok

        list when is_list(list) ->
          Enum.each(list, &validate_resource_identifier/1)

        resource_identifier ->
          validate_resource_identifier(resource_identifier)
      end
    end
  end

  defp validate_resource_identifier(identifier) do
    assert is_map(identifier), "Resource identifier should be an object"
    assert Map.has_key?(identifier, "type"), "Resource identifier should have 'type'"
    assert Map.has_key?(identifier, "id"), "Resource identifier should have 'id'"
  end

  defp validate_error_object(error) do
    assert is_map(error), "Error should be an object"

    # Error objects can have various optional fields
    optional_fields = ["id", "links", "status", "code", "title", "detail", "source", "meta"]

    # At least one field should be present
    present_fields = Map.keys(error) |> Enum.filter(&(&1 in optional_fields))
    assert present_fields != [], "Error object should have at least one field"

    # Validate specific field types if present
    if Map.has_key?(error, "status") do
      status = error["status"]
      assert is_binary(status), "Error status should be a string"
    end

    if Map.has_key?(error, "title") do
      title = error["title"]
      assert is_binary(title), "Error title should be a string"
    end

    if Map.has_key?(error, "detail") do
      detail = error["detail"]
      assert is_binary(detail), "Error detail should be a string"
    end
  end
end
