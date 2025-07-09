# Standalone test for the CommonAPIController
#
# This file can be run directly with:
#   elixir test/standalone/common_api_controller_test.exs
#
# It doesn't require any database connections or external dependencies.

# Start ExUnit
ExUnit.start()

defmodule CommonAPIControllerTest do
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
  end

  defmodule MockCachedInfo do
    def get_system_static_info(30_000_142) do
      {:ok,
       %{
         solar_system_id: 30_000_142,
         region_id: 10_000_002,
         constellation_id: 20_000_020,
         solar_system_name: "Jita",
         solar_system_name_lc: "jita",
         constellation_name: "Kimotoro",
         region_name: "The Forge",
         system_class: 0,
         security: "0.9",
         type_description: "High Security",
         class_title: "High Sec",
         is_shattered: false,
         effect_name: nil,
         effect_power: nil,
         statics: [],
         wandering: [],
         triglavian_invasion_status: nil,
         sun_type_id: 45041
       }}
    end

    def get_system_static_info(31_000_005) do
      {:ok,
       %{
         solar_system_id: 31_000_005,
         region_id: 11_000_000,
         constellation_id: 21_000_000,
         solar_system_name: "J123456",
         solar_system_name_lc: "j123456",
         constellation_name: "Unknown",
         region_name: "Wormhole Space",
         system_class: 1,
         security: "-0.9",
         type_description: "Wormhole",
         class_title: "Class 1",
         is_shattered: false,
         effect_name: "Wolf-Rayet Star",
         effect_power: 1,
         statics: ["N110"],
         wandering: ["K162"],
         triglavian_invasion_status: nil,
         sun_type_id: 45042
       }}
    end

    def get_system_static_info(_) do
      {:error, :not_found}
    end

    def get_wormhole_types do
      {:ok,
       [
         %{
           name: "N110",
           dest: 1,
           lifetime: "16h",
           total_mass: 500_000_000,
           max_mass_per_jump: 20_000_000,
           mass_regen: 0
         }
       ]}
    end

    def get_wormhole_classes! do
      [
        %{
          id: 1,
          title: "Class 1 Wormhole",
          short_name: "C1"
        }
      ]
    end
  end

  # Mock controller that uses our mock dependencies
  defmodule MockCommonAPIController do
    # Simplified version of show_system_static from CommonAPIController
    def show_system_static(params) do
      with {:ok, solar_system_str} <- MockUtil.require_param(params, "id"),
           {:ok, solar_system_id} <- MockUtil.parse_int(solar_system_str) do
        case MockCachedInfo.get_system_static_info(solar_system_id) do
          {:ok, system} ->
            # Get basic system data
            data = static_system_to_json(system)

            # Enhance with wormhole type information if statics exist
            enhanced_data = enhance_with_static_details(data)

            # Return the enhanced data
            {:ok, %{data: enhanced_data}}

          {:error, :not_found} ->
            {:error, :not_found, "System not found"}
        end
      else
        {:error, msg} ->
          {:error, :bad_request, msg}
      end
    end

    # Helper function to convert a system to JSON format
    defp static_system_to_json(system) do
      system
      |> Map.take([
        :solar_system_id,
        :region_id,
        :constellation_id,
        :solar_system_name,
        :solar_system_name_lc,
        :constellation_name,
        :region_name,
        :system_class,
        :security,
        :type_description,
        :class_title,
        :is_shattered,
        :effect_name,
        :effect_power,
        :statics,
        :wandering,
        :triglavian_invasion_status,
        :sun_type_id
      ])
    end

    # Helper function to enhance system data with wormhole type information
    defp enhance_with_static_details(data) do
      if data[:statics] && length(data[:statics]) > 0 do
        # Add the enhanced static details to the response
        Map.put(data, :static_details, get_static_details(data[:statics]))
      else
        # No statics, return the original data
        data
      end
    end

    # Helper function to get detailed information for each static wormhole
    defp get_static_details(statics) do
      # Get wormhole data from CachedInfo
      {:ok, wormhole_types} = MockCachedInfo.get_wormhole_types()
      wormhole_classes = MockCachedInfo.get_wormhole_classes!()

      # Create a map of wormhole classes by ID for quick lookup
      classes_by_id =
        Enum.reduce(wormhole_classes, %{}, fn class, acc ->
          Map.put(acc, class.id, class)
        end)

      # Find detailed information for each static
      Enum.map(statics, fn static_name ->
        # Find the wormhole type by name
        wh_type = Enum.find(wormhole_types, fn type -> type.name == static_name end)

        if wh_type do
          create_wormhole_details(wh_type, classes_by_id)
        else
          create_fallback_wormhole_details(static_name)
        end
      end)
    end

    # Helper function to create detailed wormhole information
    defp create_wormhole_details(wh_type, classes_by_id) do
      # Get destination class info
      dest_class = Map.get(classes_by_id, wh_type.dest)

      # Create enhanced static info
      %{
        name: wh_type.name,
        destination: %{
          id: to_string(wh_type.dest),
          name: if(dest_class, do: dest_class.title, else: wh_type.dest),
          short_name: if(dest_class, do: dest_class.short_name, else: wh_type.dest)
        },
        properties: %{
          lifetime: wh_type.lifetime,
          max_mass: wh_type.total_mass,
          max_jump_mass: wh_type.max_mass_per_jump,
          mass_regeneration: wh_type.mass_regen
        }
      }
    end

    # Helper function to create fallback information
    defp create_fallback_wormhole_details(static_name) do
      %{
        name: static_name,
        destination: %{
          id: nil,
          name: "Unknown",
          short_name: "?"
        },
        properties: %{
          lifetime: nil,
          max_mass: nil,
          max_jump_mass: nil,
          mass_regeneration: nil
        }
      }
    end
  end

  describe "show_system_static/1" do
    test "returns system static info for a high-sec system" do
      params = %{"id" => "30000142"}
      result = MockCommonAPIController.show_system_static(params)

      assert {:ok, %{data: data}} = result
      assert data.solar_system_id == 30_000_142
      assert data.solar_system_name == "Jita"
      assert data.region_name == "The Forge"
      assert data.security == "0.9"
      assert data.type_description == "High Security"
      refute Map.has_key?(data, :static_details)
    end

    test "returns system static info with static details for a wormhole system" do
      params = %{"id" => "31000005"}
      result = MockCommonAPIController.show_system_static(params)

      assert {:ok, %{data: data}} = result
      assert data.solar_system_id == 31_000_005
      assert data.solar_system_name == "J123456"
      assert data.region_name == "Wormhole Space"
      assert data.system_class == 1
      assert data.security == "-0.9"
      assert data.type_description == "Wormhole"
      assert data.effect_name == "Wolf-Rayet Star"

      # Check static details
      assert Map.has_key?(data, :static_details)
      assert length(data.static_details) == 1

      static = List.first(data.static_details)
      assert static.name == "N110"
      assert static.destination.id == "1"
      assert static.destination.name == "Class 1 Wormhole"
      assert static.destination.short_name == "C1"
      assert static.properties.lifetime == "16h"
      assert static.properties.max_mass == 500_000_000
    end

    test "returns error when system is not found" do
      params = %{"id" => "99999999"}
      result = MockCommonAPIController.show_system_static(params)

      assert {:error, :not_found, "System not found"} = result
    end

    test "returns error when system_id is not provided" do
      params = %{}
      result = MockCommonAPIController.show_system_static(params)

      assert {:error, :bad_request, message} = result
      assert message == "Missing required param: id"
    end

    test "returns error when system_id is not a valid integer" do
      params = %{"id" => "not-an-integer"}
      result = MockCommonAPIController.show_system_static(params)

      assert {:error, :bad_request, message} = result
      assert message =~ "Invalid integer for param id"
    end
  end
end
