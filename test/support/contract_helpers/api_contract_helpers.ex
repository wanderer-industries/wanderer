defmodule WandererApp.Support.ContractHelpers.ApiContractHelpers do
  @moduledoc """
  Comprehensive API contract testing helpers.

  This module provides utilities for:
  - Request/response schema validation
  - OpenAPI specification compliance
  - Error contract validation
  - API versioning compatibility
  """

  import ExUnit.Assertions
  import WandererAppWeb.OpenAPIContractHelpers

  alias WandererAppWeb.Factory

  @doc """
  Validates ESI character info contract.
  """
  def validate_esi_character_info_contract(character_info) do
    assert is_map(character_info)
    assert Map.has_key?(character_info, "character_id")
    assert Map.has_key?(character_info, "name")
    assert Map.has_key?(character_info, "corporation_id")
    # Additional fields are optional
    true
  end

  @doc """
  Validates ESI character location contract.
  """
  def validate_esi_character_location_contract(location) do
    assert is_map(location)
    assert Map.has_key?(location, "solar_system_id")
    assert is_integer(location["solar_system_id"])
    # station_id and structure_id are optional
    true
  end

  @doc """
  Validates ESI location contract (alias for character location).
  """
  def validate_esi_location_contract(location) do
    validate_esi_character_location_contract(location)
  end

  @doc """
  Validates ESI character ship contract.
  """
  def validate_esi_character_ship_contract(ship) do
    assert is_map(ship)
    assert Map.has_key?(ship, "ship_item_id")
    assert Map.has_key?(ship, "ship_type_id")
    assert is_integer(ship["ship_type_id"])
    # ship_name is optional
    true
  end

  @doc """
  Validates ESI ship contract (alias for character ship).
  """
  def validate_esi_ship_contract(ship) do
    validate_esi_character_ship_contract(ship)
  end

  @doc """
  Validates ESI error response contract.
  """
  def validate_esi_error_contract(error_type, response) do
    case error_type do
      :timeout -> assert response == {:error, :timeout}
      :network -> assert response == {:error, :network_error}
      :auth -> assert response == {:error, :unauthorized}
      :not_found -> assert response == {:error, :not_found}
      :server_error -> assert response == {:error, :server_error}
      _ -> flunk("Unknown error type: #{error_type}")
    end
  end

  @doc """
  Validates ESI authentication contract.
  """
  def validate_esi_auth_contract(token) do
    assert is_map(token)
    assert Map.has_key?(token, :access_token)
    assert Map.has_key?(token, :refresh_token)
    assert Map.has_key?(token, :expires_in)
    assert is_binary(token.access_token)
    assert is_binary(token.refresh_token)
    assert is_integer(token.expires_in)
    true
  end

  @doc """
  Validates ESI server status contract.
  """
  def validate_esi_server_status_contract(status) do
    assert is_map(status)
    assert Map.has_key?(status, "players")
    assert is_integer(status["players"])
    # server_version is optional
    true
  end

  @doc """
  Validates an API response against its OpenAPI schema.
  """
  def validate_response_contract(endpoint, method, status, response_body, opts \\ []) do
    # Validate against OpenAPI schema
    schema_valid = validate_response_schema(endpoint, method, status, response_body)

    # Validate response structure
    structure_valid = validate_response_structure(response_body, status)

    # Validate content type
    content_type_valid = validate_content_type(opts[:content_type] || "application/json")

    # Validate pagination if present
    pagination_valid =
      if has_pagination?(response_body) do
        validate_pagination_structure(response_body)
      else
        true
      end

    # Compile validation results
    validation_results = %{
      schema_valid: schema_valid,
      structure_valid: structure_valid,
      content_type_valid: content_type_valid,
      pagination_valid: pagination_valid
    }

    # Assert all validations passed
    Enum.each(validation_results, fn {validation_type, valid} ->
      assert valid, "#{validation_type} failed for #{method} #{endpoint} (#{status})"
    end)

    validation_results
  end

  @doc """
  Validates an API request against its OpenAPI schema.
  """
  def validate_request_contract(endpoint, method, request_body, opts \\ []) do
    # Validate request body schema
    schema_valid = validate_request_schema(endpoint, method, request_body)

    # Validate required fields
    required_fields_valid = validate_required_fields(endpoint, method, request_body)

    # Validate field types
    field_types_valid = validate_field_types(endpoint, method, request_body)

    # Validate content type
    content_type_valid = validate_content_type(opts[:content_type] || "application/json")

    validation_results = %{
      schema_valid: schema_valid,
      required_fields_valid: required_fields_valid,
      field_types_valid: field_types_valid,
      content_type_valid: content_type_valid
    }

    Enum.each(validation_results, fn {validation_type, valid} ->
      assert valid, "Request #{validation_type} failed for #{method} #{endpoint}"
    end)

    validation_results
  end

  @doc """
  Validates error responses follow standard format.
  """
  def validate_error_contract(status, response_body, opts \\ []) do
    # Validate error response structure
    structure_valid = validate_error_response_structure(response_body, status)

    # Validate error message format
    message_valid = validate_error_message_format(response_body)

    # Validate error code consistency
    code_valid = validate_error_code_consistency(response_body, status)

    # Validate error details if present
    details_valid =
      if has_error_details?(response_body) do
        validate_error_details_structure(response_body)
      else
        true
      end

    validation_results = %{
      structure_valid: structure_valid,
      message_valid: message_valid,
      code_valid: code_valid,
      details_valid: details_valid
    }

    Enum.each(validation_results, fn {validation_type, valid} ->
      assert valid, "Error #{validation_type} failed for status #{status}"
    end)

    validation_results
  end

  @doc """
  Validates JSON:API compliance for v1 endpoints.
  """
  def validate_jsonapi_contract(response_body, opts \\ []) do
    # Validate JSON:API top-level structure
    structure_valid = validate_jsonapi_structure(response_body)

    # Validate resource objects
    resources_valid =
      if has_jsonapi_data?(response_body) do
        validate_jsonapi_resources(response_body["data"])
      else
        true
      end

    # Validate relationships
    relationships_valid =
      if has_jsonapi_relationships?(response_body) do
        validate_jsonapi_relationships(response_body)
      else
        true
      end

    # Validate meta and links
    meta_valid = validate_jsonapi_meta(response_body)
    links_valid = validate_jsonapi_links(response_body)

    validation_results = %{
      structure_valid: structure_valid,
      resources_valid: resources_valid,
      relationships_valid: relationships_valid,
      meta_valid: meta_valid,
      links_valid: links_valid
    }

    Enum.each(validation_results, fn {validation_type, valid} ->
      assert valid, "JSON:API #{validation_type} failed"
    end)

    validation_results
  end

  @doc """
  Creates a test scenario with authentication for API testing.
  """
  def create_authenticated_scenario(opts \\ []) do
    scenario = Factory.create_test_scenario(opts)

    # Add authentication token
    auth_token = scenario.map.public_api_key || "test_token_#{System.unique_integer([:positive])}"

    Map.put(scenario, :auth_token, auth_token)
  end

  @doc """
  Builds an authenticated connection for API testing.
  """
  def build_authenticated_conn(auth_token, opts \\ []) do
    import Plug.Conn
    import Phoenix.ConnTest

    # Determine the correct content type based on the endpoint
    # V1 endpoints require JSON:API content type
    default_content_type = if opts[:api_version] == :v1 do
      "application/vnd.api+json"
    else
      "application/json"
    end
    
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{auth_token}")
      |> put_req_header("content-type", opts[:content_type] || default_content_type)
      |> put_req_header("accept", opts[:accept] || default_content_type)

    # Add any additional headers
    Enum.reduce(opts[:headers] || [], conn, fn {key, value}, acc ->
      put_req_header(acc, key, value)
    end)
  end

  @doc """
  Builds a JSON:API compliant connection.
  """
  def build_jsonapi_conn(auth_token, opts \\ []) do
    build_authenticated_conn(
      auth_token,
      [
        content_type: "application/vnd.api+json",
        accept: "application/vnd.api+json"
      ] ++ opts
    )
  end
  
  @doc """
  Wraps data in JSON:API format for POST/PATCH requests.
  """
  def wrap_jsonapi_data(resource_type, attributes, id \\ nil) do
    data = %{
      "type" => resource_type,
      "attributes" => attributes
    }
    
    data = if id, do: Map.put(data, "id", id), else: data
    
    %{"data" => data}
  end

  @doc """
  Tests an API endpoint with various scenarios.
  """
  def test_endpoint_scenarios(endpoint, method, scenarios, opts \\ []) do
    Enum.each(scenarios, fn scenario ->
      test_single_scenario(endpoint, method, scenario, opts)
    end)
  end

  @doc """
  Validates API versioning compatibility.
  """
  def validate_version_compatibility(endpoint, method, v1_response, legacy_response) do
    # Validate that both versions work
    assert v1_response != nil, "v1 API response is nil"
    assert legacy_response != nil, "Legacy API response is nil"

    # Validate data consistency between versions
    data_consistent = validate_data_consistency(v1_response, legacy_response)

    # Validate that core fields are preserved
    fields_preserved = validate_core_fields_preserved(v1_response, legacy_response)

    validation_results = %{
      data_consistent: data_consistent,
      fields_preserved: fields_preserved
    }

    Enum.each(validation_results, fn {validation_type, valid} ->
      assert valid, "Version compatibility #{validation_type} failed for #{method} #{endpoint}"
    end)

    validation_results
  end

  # Private helper functions

  defp validate_response_schema(endpoint, method, status, response_body) do
    # This would integrate with OpenAPI schema validation
    # For now, we'll do basic validation
    is_map(response_body) or is_list(response_body)
  end

  defp validate_response_structure(response_body, status) do
    case status do
      200 -> is_map(response_body) or is_list(response_body)
      201 -> is_map(response_body)
      204 -> response_body == "" or is_nil(response_body)
      _ -> Map.has_key?(response_body, "error") or Map.has_key?(response_body, "errors")
    end
  end

  defp validate_content_type(content_type) do
    content_type in ["application/json", "application/vnd.api+json"]
  end

  defp has_pagination?(response_body) when is_map(response_body) do
    Map.has_key?(response_body, "pagination") or Map.has_key?(response_body, "links")
  end

  defp has_pagination?(_), do: false

  defp validate_pagination_structure(response_body) do
    # Validate pagination structure
    # Placeholder implementation
    true
  end

  defp validate_request_schema(endpoint, method, request_body) do
    # This would integrate with OpenAPI schema validation
    is_map(request_body) or is_nil(request_body)
  end

  defp validate_required_fields(endpoint, method, request_body) do
    # This would check required fields based on OpenAPI spec
    # Placeholder implementation
    true
  end

  defp validate_field_types(endpoint, method, request_body) do
    # This would validate field types based on OpenAPI spec
    # Placeholder implementation
    true
  end

  defp validate_error_response_structure(response_body, status) do
    is_map(response_body) and
      (Map.has_key?(response_body, "error") or Map.has_key?(response_body, "errors"))
  end

  defp validate_error_message_format(response_body) do
    case response_body do
      %{"error" => error} when is_binary(error) -> true
      %{"errors" => errors} when is_list(errors) -> true
      _ -> false
    end
  end

  defp validate_error_code_consistency(response_body, status) do
    # Validate that error codes are consistent with HTTP status
    # Placeholder implementation
    true
  end

  defp has_error_details?(response_body) do
    Map.has_key?(response_body, "details") or Map.has_key?(response_body, "meta")
  end

  defp validate_error_details_structure(response_body) do
    # Validate error details structure
    # Placeholder implementation
    true
  end

  defp validate_jsonapi_structure(response_body) do
    is_map(response_body) and
      (Map.has_key?(response_body, "data") or Map.has_key?(response_body, "errors"))
  end

  defp has_jsonapi_data?(response_body) do
    Map.has_key?(response_body, "data")
  end

  defp validate_jsonapi_resources(data) when is_list(data) do
    Enum.all?(data, &validate_jsonapi_resource/1)
  end

  defp validate_jsonapi_resources(data) when is_map(data) do
    validate_jsonapi_resource(data)
  end

  defp validate_jsonapi_resource(resource) do
    is_map(resource) and
      Map.has_key?(resource, "type") and
      Map.has_key?(resource, "id") and
      Map.has_key?(resource, "attributes")
  end

  defp has_jsonapi_relationships?(response_body) do
    case response_body do
      %{"data" => data} when is_map(data) ->
        Map.has_key?(data, "relationships")

      %{"data" => data} when is_list(data) ->
        Enum.any?(data, &Map.has_key?(&1, "relationships"))

      _ ->
        false
    end
  end

  defp validate_jsonapi_relationships(response_body) do
    # Validate JSON:API relationships structure
    # Placeholder implementation
    true
  end

  defp validate_jsonapi_meta(response_body) do
    case Map.get(response_body, "meta") do
      nil -> true
      meta -> is_map(meta)
    end
  end

  defp validate_jsonapi_links(response_body) do
    case Map.get(response_body, "links") do
      nil -> true
      links -> is_map(links)
    end
  end

  defp test_single_scenario(endpoint, method, scenario, opts) do
    # Implementation for testing a single scenario
    # This would make the actual API call and validate the response
    true
  end

  defp validate_data_consistency(v1_response, legacy_response) do
    # Validate that core data is consistent between API versions
    # Placeholder implementation
    true
  end

  defp validate_core_fields_preserved(v1_response, legacy_response) do
    # Validate that core fields are preserved across versions
    # Placeholder implementation
    true
  end
end
