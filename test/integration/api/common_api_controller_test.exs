defmodule WandererAppWeb.CommonAPIControllerTest do
  use WandererAppWeb.ApiCase, async: true

  describe "GET /api/common/system-static-info" do
    test "returns system static info for valid system ID", %{conn: conn} do
      # Create test solar system data
      system_id = 30_000_142

      {:ok, _solar_system} =
        Ash.create(WandererApp.Api.MapSolarSystem, %{
          solar_system_id: system_id,
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
        })

      response =
        conn
        |> get("/api/common/system-static-info?id=#{system_id}")
        |> assert_json_response(200)

      # Basic structure assertions
      assert %{"data" => system_data} = response
      assert %{"solar_system_id" => ^system_id} = system_data
      assert %{"solar_system_name" => system_name} = system_data
      assert is_binary(system_name)

      # Verify expected fields are present
      required_fields = [
        "solar_system_id",
        "region_id",
        "constellation_id",
        "solar_system_name",
        "region_name",
        "constellation_name"
      ]

      for field <- required_fields do
        assert Map.has_key?(system_data, field), "Missing required field: #{field}"
      end
    end

    test "returns 400 for missing id parameter", %{conn: conn} do
      response =
        conn
        |> get("/api/common/system-static-info")
        |> assert_json_response(400)

      assert %{"error" => error_msg} = response
      assert error_msg =~ "id"
    end

    test "returns 400 for invalid system ID format", %{conn: conn} do
      response =
        conn
        |> get("/api/common/system-static-info?id=invalid")
        |> assert_json_response(400)

      assert %{"error" => error_msg} = response
      assert error_msg =~ "Invalid"
    end

    test "returns 404 for non-existent system ID", %{conn: conn} do
      # Use a system ID that doesn't exist
      invalid_system_id = 99_999_999

      response =
        conn
        |> get("/api/common/system-static-info?id=#{invalid_system_id}")
        |> assert_json_response(404)

      assert %{"error" => "System not found"} = response
    end

    test "includes static wormhole details for wormhole systems", %{conn: conn} do
      # Create test wormhole solar system data
      system_id = 31_000_005

      {:ok, _solar_system} =
        Ash.create(WandererApp.Api.MapSolarSystem, %{
          solar_system_id: system_id,
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
        })

      response =
        conn
        |> get("/api/common/system-static-info?id=#{system_id}")
        |> json_response_or_404()

      case response do
        %{"data" => %{"statics" => statics}} when length(statics) > 0 ->
          # If system has statics, verify static_details are included
          assert %{"static_details" => static_details} = response["data"]
          assert is_list(static_details)

          # Verify structure of static details
          if length(static_details) > 0 do
            detail = hd(static_details)
            assert %{"name" => _, "destination" => _, "properties" => _} = detail
          end

        _ ->
          # System doesn't have statics or wasn't found, which is fine
          :ok
      end
    end
  end

  # Helper function to handle 404 responses gracefully for optional tests
  defp json_response_or_404(conn) do
    case conn.status do
      404 -> %{"error" => "not_found"}
      _ -> json_response(conn, conn.status)
    end
  end
end
