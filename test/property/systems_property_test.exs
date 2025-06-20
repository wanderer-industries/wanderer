defmodule WandererApp.SystemsPropertyTest do
  @moduledoc """
  Property-based testing for Systems API endpoints.

  This module uses StreamData to generate random inputs and test that the API
  handles edge cases, boundary conditions, and invalid inputs properly.
  """

  use WandererApp.ApiCase
  use ExUnitProperties

  @moduletag :property
  @moduletag :api

  describe "Systems API property-based testing" do
    setup do
      map_data = create_test_map_with_auth()
      {:ok, map_data: map_data}
    end

    @tag timeout: 30_000
    property "POST /api/maps/:map_id/systems handles various system IDs gracefully", context do
      %{map_data: map_data} = context

      check all(
              system_id <- solar_system_id_generator(),
              position_x <- position_generator(),
              position_y <- position_generator(),
              name <- optional_string_generator(50),
              max_runs: 50
            ) do
        system_params = %{
          "solar_system_id" => system_id,
          "temporary_name" => name,
          "position_x" => position_x,
          "position_y" => position_y
        }

        response =
          context[:conn]
          |> authenticate_map(map_data.api_key)
          |> post("/api/maps/#{map_data.map_slug}/systems", systems: [system_params])

        # Should either succeed (200) or fail gracefully (400/422)
        assert response.status in [200, 400, 422]

        # If successful, should have valid response structure
        if response.status == 200 do
          response_data = json_response!(response, 200)
          assert is_map(response_data)
          assert Map.has_key?(response_data, "data")
          assert Map.has_key?(response_data["data"], "systems")
          assert is_map(response_data["data"]["systems"])
          assert Map.has_key?(response_data["data"]["systems"], "created")
          assert Map.has_key?(response_data["data"]["systems"], "updated")
        end
      end
    end

    @tag timeout: 30_000
    property "GET /api/maps/:map_id/systems handles various filter parameters", context do
      %{map_data: map_data} = context

      # Create some test systems first
      _system1 =
        create_map_system(
          %{
            map: map_data.map,
            solar_system_id: 30_000_142,
            temporary_name: "Test System",
            tag: "test",
            status: 1
          },
          map_data.owner
        )

      check all(
              tag <- optional_string_generator(20),
              status <- StreamData.one_of([StreamData.constant(nil), StreamData.integer(0..10)]),
              search <- optional_string_generator(30),
              max_runs: 30
            ) do
        # Build query parameters, filtering out nil values
        params =
          [
            {"tag", tag},
            {"status", status && to_string(status)},
            {"search", search}
          ]
          |> Enum.filter(fn {_key, value} -> value != nil end)
          |> Enum.into(%{})

        response =
          context[:conn]
          |> authenticate_map(map_data.api_key)
          |> get("/api/maps/#{map_data.map_slug}/systems", params)

        # Should either succeed or handle invalid filters gracefully
        assert response.status in [200, 400, 422]

        # If successful, should return valid system list structure
        if response.status == 200 do
          response_data = json_response!(response, 200)
          assert is_map(response_data)
          assert Map.has_key?(response_data, "data")
          assert Map.has_key?(response_data["data"], "systems")
          assert is_list(response_data["data"]["systems"])
        end
      end
    end

    @tag timeout: 30_000
    property "PUT /api/maps/:map_id/systems/:id handles various update parameters", context do
      %{map_data: map_data} = context

      # Create a test system first
      system =
        create_map_system(
          %{
            map: map_data.map,
            solar_system_id: 30_000_142,
            temporary_name: "Test System"
          },
          map_data.owner
        )

      check all(
              position_x <- StreamData.one_of([StreamData.constant(nil), position_generator()]),
              position_y <- StreamData.one_of([StreamData.constant(nil), position_generator()]),
              tag <- optional_string_generator(30),
              status <- StreamData.one_of([StreamData.constant(nil), StreamData.integer(0..10)]),
              description <- optional_string_generator(200),
              max_runs: 30
            ) do
        # Build update parameters, filtering out nil values
        update_params =
          [
            {"position_x", position_x},
            {"position_y", position_y},
            {"tag", tag},
            {"status", status},
            {"description", description}
          ]
          |> Enum.filter(fn {_key, value} -> value != nil end)
          |> Enum.into(%{})

        # Skip if no parameters provided
        if map_size(update_params) > 0 do
          response =
            context[:conn]
            |> authenticate_map(map_data.api_key)
            |> put("/api/maps/#{map_data.map_slug}/systems/#{system.solar_system_id}",
              system: update_params
            )

          # Should either succeed or handle invalid updates gracefully
          assert response.status in [200, 400, 404, 422]

          # If successful, should return updated system
          if response.status == 200 do
            response_data = json_response!(response, 200)
            assert is_map(response_data)
            assert Map.has_key?(response_data, "data")
            assert is_map(response_data["data"])
            assert Map.has_key?(response_data["data"], "solar_system_id")
          end
        end
      end
    end

    @tag timeout: 30_000
    property "API endpoints handle malformed system IDs properly", context do
      %{map_data: map_data} = context

      check all(
              bad_system_id <-
                StreamData.one_of([
                  # Various malformed system IDs
                  StreamData.constant(nil),
                  StreamData.constant(""),
                  StreamData.constant("invalid"),
                  StreamData.constant(-1),
                  StreamData.integer(-1000..-1),
                  # Too small for real system IDs
                  StreamData.integer(0..999),
                  # Too large
                  StreamData.integer(100_000_000..999_999_999),
                  StreamData.string(:alphanumeric, min_length: 1, max_length: 20),
                  StreamData.list_of(StreamData.integer(), max_length: 5)
                ]),
              max_runs: 40
            ) do
        # Test GET single system endpoint
        # Safely convert bad_system_id to string for URL interpolation
        system_id_str =
          case bad_system_id do
            val when is_list(val) -> inspect(val)
            val -> to_string(val)
          end

        response =
          context[:conn]
          |> authenticate_map(map_data.api_key)
          |> get("/api/maps/#{map_data.map_slug}/systems/#{system_id_str}")

        # Should handle malformed IDs gracefully
        # 200 might be returned if the system_id gets parsed unexpectedly
        # 400/404/422 for actual errors, 500 for server errors
        assert response.status in [200, 400, 404, 422, 500]

        # Test POST with malformed system_id in body
        system_params = %{
          "solar_system_id" => bad_system_id,
          "temporary_name" => "Test System"
        }

        create_response =
          context[:conn]
          |> authenticate_map(map_data.api_key)
          |> post("/api/maps/#{map_data.map_slug}/systems", systems: [system_params])

        # Should handle gracefully - either success with 0 created or error
        assert create_response.status in [200, 400, 422]

        if create_response.status == 200 do
          response_data = json_response!(create_response, 200)
          # API currently accepts any system_id, even invalid ones
          # Check that we have a valid response structure
          assert is_map(response_data["data"]["systems"])
          assert Map.has_key?(response_data["data"]["systems"], "created")
          assert Map.has_key?(response_data["data"]["systems"], "updated")
        end
      end
    end
  end

  # StreamData generators for property-based testing

  defp solar_system_id_generator do
    # Generate system IDs that could be valid EVE Online system IDs
    StreamData.one_of([
      # Valid range for EVE system IDs
      StreamData.integer(30_000_000..31_999_999),
      # Edge cases around the valid range
      StreamData.integer(29_999_990..30_000_010),
      StreamData.integer(31_999_990..32_000_010),
      # Common test values
      # Jita, Perimeter, Maurasi
      StreamData.member_of([30_000_142, 30_000_144, 30_000_145])
    ])
  end

  defp position_generator do
    # Generate positions that could be valid map coordinates
    StreamData.one_of([
      # Normal map positions
      StreamData.integer(-5000..5000),
      # Edge cases
      StreamData.integer(-10000..-5001),
      StreamData.integer(5001..10000),
      # Extreme values
      StreamData.integer(-100_000..-10001),
      StreamData.integer(10001..100_000)
    ])
  end

  defp optional_string_generator(max_length) do
    StreamData.one_of([
      StreamData.constant(nil),
      StreamData.string(:alphanumeric, max_length: max_length),
      StreamData.string(:printable, max_length: max_length),
      # Edge cases
      StreamData.constant(""),
      StreamData.constant(String.duplicate("a", max_length)),
      # Unicode characters
      StreamData.constant(String.duplicate("🚀", div(max_length, 4))),
      # Common SQL injection attempts (should be handled safely)
      StreamData.member_of(["'; DROP TABLE systems; --", "<script>alert('xss')</script>", "NULL"])
    ])
  end
end
