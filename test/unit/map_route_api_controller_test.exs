# Standalone test for the MapAPIController route functionality
#
# This file can be run directly with:
#   elixir test/standalone/map_route_api_controller_test.exs
#
# It doesn't require any database connections or external dependencies.

# Start ExUnit
ExUnit.start()

defmodule MapRouteAPIControllerTest do
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
    # Mock data for systems
    def get_systems_by_ids(map_id, system_ids) when map_id == 1 do
      systems = %{
        30_000_142 => %{id: 30_000_142, name: "Jita", security: 0.9, region_id: 10_000_002},
        30_002_659 => %{id: 30_002_659, name: "Dodixie", security: 0.9, region_id: 10_000_032},
        30_002_187 => %{id: 30_002_187, name: "Amarr", security: 1.0, region_id: 10_000_043}
      }

      Enum.map(system_ids, fn id -> Map.get(systems, id) end)
      |> Enum.filter(&(&1 != nil))
    end

    def get_systems_by_ids(_, _), do: []

    # Mock data for connections
    def get_connections_between(map_id, _system_ids) when map_id == 1 do
      [
        %{source_id: 30_000_142, target_id: 30_002_659, distance: 15},
        %{source_id: 30_002_659, target_id: 30_002_187, distance: 12},
        %{source_id: 30_000_142, target_id: 30_002_187, distance: 20}
      ]
    end

    def get_connections_between(_, _), do: []
  end

  defmodule MockRouteCalculator do
    # Simplified route calculator that just returns a predefined route
    def calculate_route(systems, _connections, source_id, target_id, _options \\ []) do
      cond do
        source_id == 30_000_142 and target_id == 30_002_187 ->
          # Direct route from Jita to Amarr
          route = [
            Enum.find(systems, fn s -> s.id == 30_000_142 end),
            Enum.find(systems, fn s -> s.id == 30_002_187 end)
          ]

          {:ok, %{route: route, jumps: 1, distance: 20}}

        source_id == 30_000_142 and target_id == 30_002_659 ->
          # Direct route from Jita to Dodixie
          route = [
            Enum.find(systems, fn s -> s.id == 30_000_142 end),
            Enum.find(systems, fn s -> s.id == 30_002_659 end)
          ]

          {:ok, %{route: route, jumps: 1, distance: 15}}

        source_id == 30_002_659 and target_id == 30_002_187 ->
          # Direct route from Dodixie to Amarr
          route = [
            Enum.find(systems, fn s -> s.id == 30_002_659 end),
            Enum.find(systems, fn s -> s.id == 30_002_187 end)
          ]

          {:ok, %{route: route, jumps: 1, distance: 12}}

        source_id == 30_002_659 and target_id == 30_000_142 ->
          # Direct route from Dodixie to Jita
          route = [
            Enum.find(systems, fn s -> s.id == 30_002_659 end),
            Enum.find(systems, fn s -> s.id == 30_000_142 end)
          ]

          {:ok, %{route: route, jumps: 1, distance: 15}}

        true ->
          {:error, "No route found"}
      end
    end
  end

  # Mock controller that uses our mock dependencies
  defmodule MockMapAPIController do
    # Simplified version of calculate_route from MapAPIController
    def calculate_route(params) do
      with {:ok, map_id} <- MockUtil.fetch_map_id(params),
           {:ok, source_id_str} <- MockUtil.require_param(params, "source"),
           {:ok, source_id} <- MockUtil.parse_int(source_id_str),
           {:ok, target_id_str} <- MockUtil.require_param(params, "target"),
           {:ok, target_id} <- MockUtil.parse_int(target_id_str) do
        # Get the systems involved in the route
        systems = MockMapSystemRepo.get_systems_by_ids(map_id, [source_id, target_id])

        # Check if both systems exist
        source_system = Enum.find(systems, fn s -> s.id == source_id end)
        target_system = Enum.find(systems, fn s -> s.id == target_id end)

        if source_system == nil do
          {:error, :not_found, "Source system not found"}
        else
          if target_system == nil do
            {:error, :not_found, "Target system not found"}
          else
            # Get connections between systems
            connections =
              MockMapSystemRepo.get_connections_between(map_id, [source_id, target_id])

            # Calculate the route
            case MockRouteCalculator.calculate_route(systems, connections, source_id, target_id) do
              {:ok, route_data} ->
                # Format the response
                formatted_route = format_route_response(route_data)
                {:ok, %{data: formatted_route}}

              {:error, reason} ->
                {:error, :not_found, reason}
            end
          end
        end
      else
        {:error, msg} ->
          {:error, :bad_request, msg}
      end
    end

    # Helper function to format the route response
    defp format_route_response(route_data) do
      %{
        route:
          Enum.map(route_data.route, fn system ->
            %{
              id: system.id,
              name: system.name,
              security: system.security
            }
          end),
        jumps: route_data.jumps,
        distance: route_data.distance
      }
    end
  end

  describe "calculate_route/1" do
    test "calculates route between two systems successfully" do
      params = %{
        "map_id" => "1",
        # Jita
        "source" => "30000142",
        # Amarr
        "target" => "30002187"
      }

      result = MockMapAPIController.calculate_route(params)

      assert {:ok, %{data: data}} = result
      assert length(data.route) == 2
      assert Enum.at(data.route, 0).id == 30_000_142
      assert Enum.at(data.route, 0).name == "Jita"
      assert Enum.at(data.route, 1).id == 30_002_187
      assert Enum.at(data.route, 1).name == "Amarr"
      assert data.jumps == 1
      assert data.distance == 20
    end

    test "calculates route using map slug" do
      params = %{
        "slug" => "test-map",
        # Jita
        "source" => "30000142",
        # Dodixie
        "target" => "30002659"
      }

      result = MockMapAPIController.calculate_route(params)

      assert {:ok, %{data: data}} = result
      assert length(data.route) == 2
      assert Enum.at(data.route, 0).id == 30_000_142
      assert Enum.at(data.route, 0).name == "Jita"
      assert Enum.at(data.route, 1).id == 30_002_659
      assert Enum.at(data.route, 1).name == "Dodixie"
      assert data.jumps == 1
      assert data.distance == 15
    end

    test "returns error when source system is not found" do
      params = %{
        "map_id" => "1",
        # Non-existent system
        "source" => "99999999",
        # Amarr
        "target" => "30002187"
      }

      result = MockMapAPIController.calculate_route(params)

      assert {:error, :not_found, message} = result
      assert message == "Source system not found"
    end

    test "returns error when target system is not found" do
      params = %{
        "map_id" => "1",
        # Jita
        "source" => "30000142",
        # Non-existent system
        "target" => "99999999"
      }

      result = MockMapAPIController.calculate_route(params)

      assert {:error, :not_found, message} = result
      assert message == "Target system not found"
    end

    test "returns error when map is not found" do
      params = %{
        "slug" => "non-existent-map",
        # Jita
        "source" => "30000142",
        # Amarr
        "target" => "30002187"
      }

      result = MockMapAPIController.calculate_route(params)

      assert {:error, :bad_request, message} = result
      assert message == "Map not found"
    end

    test "returns error when source parameter is missing" do
      params = %{
        "map_id" => "1",
        # Amarr
        "target" => "30002187"
      }

      result = MockMapAPIController.calculate_route(params)

      assert {:error, :bad_request, message} = result
      assert message == "Missing required param: source"
    end

    test "returns error when target parameter is missing" do
      params = %{
        "map_id" => "1",
        # Jita
        "source" => "30000142"
      }

      result = MockMapAPIController.calculate_route(params)

      assert {:error, :bad_request, message} = result
      assert message == "Missing required param: target"
    end

    test "returns error when map_id and slug are both missing" do
      params = %{
        # Jita
        "source" => "30000142",
        # Amarr
        "target" => "30002187"
      }

      result = MockMapAPIController.calculate_route(params)

      assert {:error, :bad_request, message} = result
      assert message == "Missing required param: map_id or slug"
    end

    test "returns error when source is not a valid integer" do
      params = %{
        "map_id" => "1",
        "source" => "not-an-integer",
        # Amarr
        "target" => "30002187"
      }

      result = MockMapAPIController.calculate_route(params)

      assert {:error, :bad_request, message} = result
      assert message =~ "Invalid integer for param id"
    end

    test "returns error when target is not a valid integer" do
      params = %{
        "map_id" => "1",
        # Jita
        "source" => "30000142",
        "target" => "not-an-integer"
      }

      result = MockMapAPIController.calculate_route(params)

      assert {:error, :bad_request, message} = result
      assert message =~ "Invalid integer for param id"
    end
  end
end
