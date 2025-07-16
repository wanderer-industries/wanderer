defmodule WandererAppWeb.OpenApiEndpointsTest do
  use WandererAppWeb.ConnCase

  describe "OpenAPI endpoints" do
    test "legacy OpenAPI spec is accessible", %{conn: conn} do
      conn = get(conn, "/api/openapi")

      assert response = json_response(conn, 200)
      assert response["openapi"]
      assert response["info"]["title"] == "WandererApp API"
      assert response["paths"]
    end

    test "v1 JSON:API OpenAPI spec is accessible", %{conn: conn} do
      conn = get(conn, "/api/v1/open_api")

      assert response = json_response(conn, 200)
      assert response["openapi"]
      # Should contain JSON:API in title
      assert response["info"]["title"] =~ "JSON"
      assert response["paths"]

      # Check for v1 endpoints
      assert Map.has_key?(response["paths"], "/api/v1/characters")
      assert Map.has_key?(response["paths"], "/api/v1/maps")
      assert Map.has_key?(response["paths"], "/api/v1/map_systems")

      # Check for filtering/sorting parameters
      characters_get = response["paths"]["/api/v1/characters"]["get"]
      assert characters_get

      # Should have parameters for filtering, sorting, pagination
      param_names = Enum.map(characters_get["parameters"] || [], & &1["name"])
      assert Enum.any?(param_names, &String.contains?(&1, "filter"))
      assert Enum.any?(param_names, &String.contains?(&1, "sort"))
      assert Enum.any?(param_names, &String.contains?(&1, "page"))
    end

    test "combined OpenAPI spec is accessible", %{conn: conn} do
      conn = get(conn, "/api/openapi-complete")

      assert response = json_response(conn, 200)
      assert response["openapi"]
      assert response["info"]["title"] =~ "Legacy & v1"

      # Should have both legacy and v1 paths
      paths = Map.keys(response["paths"] || %{})
      # Legacy
      assert Enum.any?(paths, &String.starts_with?(&1, "/api/map"))
      # v1
      assert Enum.any?(paths, &String.starts_with?(&1, "/api/v1"))
    end

    test "swagger UI pages are accessible", %{conn: conn} do
      # Test v1 Swagger UI
      conn = get(conn, "/swaggerui/v1")
      assert response(conn, 200)
      assert response_content_type(conn, :html)

      # Test legacy Swagger UI
      conn = get(build_conn(), "/swaggerui/legacy")
      assert response(conn, 200)
      assert response_content_type(conn, :html)

      # Test combined Swagger UI
      conn = get(build_conn(), "/swaggerui")
      assert response(conn, 200)
      assert response_content_type(conn, :html)
    end
  end

  describe "v1 endpoints documentation" do
    test "characters endpoint documentation includes all operations", %{conn: conn} do
      conn = get(conn, "/api/v1/open_api")
      response = json_response(conn, 200)

      # Check that paths exist
      assert Map.has_key?(response["paths"], "/api/v1/characters")
      assert Map.has_key?(response["paths"], "/api/v1/characters/{id}")

      # Check operations exist
      characters_path = response["paths"]["/api/v1/characters"]
      assert characters_path["get"]
      assert characters_path["post"]

      character_path = response["paths"]["/api/v1/characters/{id}"]
      assert character_path["get"]
      assert character_path["patch"]
      assert character_path["delete"]

      # Check descriptions exist (AshJsonApi uses description instead of summary)
      assert characters_path["get"]["description"] =~ "characters"
      assert characters_path["post"]["description"] =~ "characters"
    end

    test "maps endpoint documentation includes filtering parameters", %{conn: conn} do
      conn = get(conn, "/api/v1/open_api")
      response = json_response(conn, 200)

      maps_params = response["paths"]["/api/v1/maps"]["get"]["parameters"] || []
      param_names = Enum.map(maps_params, & &1["name"])

      # AshJsonApi generates generic parameters
      assert "filter" in param_names
      assert "sort" in param_names
      assert "page" in param_names

      # Check for filter parameter description
      filter_param = Enum.find(maps_params, &(&1["name"] == "filter"))
      assert filter_param
      assert filter_param["description"] =~ "filter"
    end

    test "documentation includes security requirements", %{conn: conn} do
      conn = get(conn, "/api/v1/open_api")
      response = json_response(conn, 200)

      # Check global security
      assert response["security"]

      # Check security schemes
      assert response["components"]["securitySchemes"]["bearerAuth"]
      assert response["components"]["securitySchemes"]["bearerAuth"]["type"] == "http"
      assert response["components"]["securitySchemes"]["bearerAuth"]["scheme"] == "bearer"
    end

    test "documentation includes JSON:API schemas", %{conn: conn} do
      conn = get(conn, "/api/v1/open_api")
      response = json_response(conn, 200)

      schemas = response["components"]["schemas"] || %{}

      # Should have JSON:API compliant schemas
      assert Enum.any?(schemas, fn {name, _schema} ->
               String.contains?(name, "Character") || String.contains?(name, "character")
             end)

      # Check for JSON:API structure in schemas
      character_schema =
        Enum.find(schemas, fn {name, _} ->
          String.contains?(name, "Character") && String.contains?(name, "Resource")
        end)

      if character_schema do
        {_, schema} = character_schema
        assert schema["properties"]["type"]
        assert schema["properties"]["id"]
        assert schema["properties"]["attributes"]
      end
    end
  end
end
