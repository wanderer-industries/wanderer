# Standalone test for the MapAPIController
#
# This file can be run directly with:
#   elixir test/standalone/map_api_controller_test.exs
#
# It doesn't require any database connections or external dependencies.

# Start ExUnit
ExUnit.start()

defmodule MapAPIControllerTest do
  use ExUnit.Case

  # Mock modules to simulate the behavior of the controller's dependencies
  defmodule MockUtil do
    def require_param(params, key) do
      case params[key] do
        nil -> {:error, "Missing required param: #{key}"}
        "" -> {:error, "Param #{key} cannot be empty"}
        val -> {:ok, val}
      end
    end

    def parse_int(str) do
      case Integer.parse(str) do
        {num, ""} -> {:ok, num}
        _ -> {:error, "Invalid integer for param id=#{str}"}
      end
    end

    def fetch_map_id(params) do
      cond do
        params["map_id"] ->
          case parse_int(params["map_id"]) do
            {:ok, map_id} -> {:ok, map_id}
            {:error, _} -> {:error, "Invalid map_id format"}
          end

        params["slug"] ->
          # In a real app, this would look up the map by slug
          # For testing, we'll just use a simple mapping
          case params["slug"] do
            "test-map" -> {:ok, 1}
            "another-map" -> {:ok, 2}
            _ -> {:error, "Map not found"}
          end

        true ->
          {:error, "Missing required param: map_id or slug"}
      end
    end
  end

  defmodule MockMapSystemRepo do
    def get_visible_systems_by_map_id(1) do
      [
        %{id: 30_000_142, name: "Jita", security: 0.9, region_id: 10_000_002},
        %{id: 30_002_659, name: "Dodixie", security: 0.9, region_id: 10_000_032},
        %{id: 30_002_187, name: "Amarr", security: 1.0, region_id: 10_000_043}
      ]
    end

    def get_visible_systems_by_map_id(_) do
      []
    end

    def get_system_by_id(1, 30_000_142) do
      %{id: 30_000_142, name: "Jita", security: 0.9, region_id: 10_000_002}
    end

    def get_system_by_id(1, 30_002_659) do
      %{id: 30_002_659, name: "Dodixie", security: 0.9, region_id: 10_000_032}
    end

    def get_system_by_id(1, 30_002_187) do
      %{id: 30_002_187, name: "Amarr", security: 1.0, region_id: 10_000_043}
    end

    def get_system_by_id(_, _) do
      nil
    end
  end

  defmodule MockMapSolarSystem do
    def get_name_by_id(30_000_142), do: "Jita"
    def get_name_by_id(30_002_659), do: "Dodixie"
    def get_name_by_id(30_002_187), do: "Amarr"
    def get_name_by_id(_), do: nil
  end

  # Mock controller that uses our mock dependencies
  defmodule MockMapAPIController do
    # Simplified version of list_systems from MapAPIController
    def list_systems(params) do
      with {:ok, map_id} <- MockUtil.fetch_map_id(params) do
        systems = MockMapSystemRepo.get_visible_systems_by_map_id(map_id)

        if systems == [] do
          {:error, :not_found, "No systems found for this map"}
        else
          # Format the response
          formatted_systems =
            Enum.map(systems, fn system ->
              %{
                id: system.id,
                name: system.name,
                security: system.security
              }
            end)

          {:ok, %{data: formatted_systems}}
        end
      else
        {:error, msg} ->
          {:error, :bad_request, msg}
      end
    end

    # Simplified version of show_system from MapAPIController
    def show_system(params) do
      with {:ok, map_id} <- MockUtil.fetch_map_id(params),
           {:ok, system_id_str} <- MockUtil.require_param(params, "id"),
           {:ok, system_id} <- MockUtil.parse_int(system_id_str) do
        system = MockMapSystemRepo.get_system_by_id(map_id, system_id)

        if system == nil do
          {:error, :not_found, "System not found"}
        else
          # Format the response
          formatted_system = %{
            id: system.id,
            name: system.name,
            security: system.security
          }

          {:ok, %{data: formatted_system}}
        end
      else
        {:error, msg} ->
          {:error, :bad_request, msg}
      end
    end
  end

  describe "list_systems/1" do
    test "returns systems with valid map_id" do
      params = %{"map_id" => "1"}
      result = MockMapAPIController.list_systems(params)

      assert {:ok, %{data: data}} = result
      assert length(data) == 3

      # Check that the data contains the expected systems
      jita = Enum.find(data, fn system -> system.id == 30_000_142 end)
      assert jita.name == "Jita"
      assert jita.security == 0.9

      dodixie = Enum.find(data, fn system -> system.id == 30_002_659 end)
      assert dodixie.name == "Dodixie"
      assert dodixie.security == 0.9
    end

    test "returns systems with valid slug" do
      params = %{"slug" => "test-map"}
      result = MockMapAPIController.list_systems(params)

      assert {:ok, %{data: data}} = result
      assert length(data) == 3
    end

    test "returns error when no systems found" do
      params = %{"map_id" => "2"}
      result = MockMapAPIController.list_systems(params)

      assert {:error, :not_found, message} = result
      assert message == "No systems found for this map"
    end

    test "returns error when map_id is missing" do
      params = %{}
      result = MockMapAPIController.list_systems(params)

      assert {:error, :bad_request, message} = result
      assert message == "Missing required param: map_id or slug"
    end

    test "returns error when invalid map_id is provided" do
      params = %{"slug" => "non-existent-map"}
      result = MockMapAPIController.list_systems(params)

      assert {:error, :bad_request, message} = result
      assert message == "Map not found"
    end
  end

  describe "show_system/1" do
    test "returns system with valid parameters" do
      params = %{"map_id" => "1", "id" => "30000142"}
      result = MockMapAPIController.show_system(params)

      assert {:ok, %{data: data}} = result
      assert data.id == 30_000_142
      assert data.name == "Jita"
      assert data.security == 0.9
    end

    test "returns error when system is not found" do
      params = %{"map_id" => "1", "id" => "99999999"}
      result = MockMapAPIController.show_system(params)

      assert {:error, :not_found, message} = result
      assert message == "System not found"
    end
  end
end
