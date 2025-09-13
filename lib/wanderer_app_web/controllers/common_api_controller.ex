defmodule WandererAppWeb.CommonAPIController do
  use WandererAppWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias WandererApp.CachedInfo
  alias WandererAppWeb.Helpers.APIUtils

  @system_static_response_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      data: %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          solar_system_id: %OpenApiSpex.Schema{type: :integer},
          region_id: %OpenApiSpex.Schema{type: :integer},
          constellation_id: %OpenApiSpex.Schema{type: :integer},
          solar_system_name: %OpenApiSpex.Schema{type: :string},
          solar_system_name_lc: %OpenApiSpex.Schema{type: :string},
          constellation_name: %OpenApiSpex.Schema{type: :string},
          region_name: %OpenApiSpex.Schema{type: :string},
          system_class: %OpenApiSpex.Schema{type: :integer},
          security: %OpenApiSpex.Schema{type: :string},
          type_description: %OpenApiSpex.Schema{type: :string},
          class_title: %OpenApiSpex.Schema{type: :string},
          is_shattered: %OpenApiSpex.Schema{type: :boolean},
          effect_name: %OpenApiSpex.Schema{type: :string},
          effect_power: %OpenApiSpex.Schema{type: :integer},
          statics: %OpenApiSpex.Schema{type: :array, items: %OpenApiSpex.Schema{type: :string}},
          static_details: %OpenApiSpex.Schema{
            type: :array,
            items: %OpenApiSpex.Schema{
              type: :object,
              properties: %{
                name: %OpenApiSpex.Schema{type: :string},
                destination: %OpenApiSpex.Schema{
                  type: :object,
                  properties: %{
                    id: %OpenApiSpex.Schema{type: :string},
                    name: %OpenApiSpex.Schema{type: :string},
                    short_name: %OpenApiSpex.Schema{type: :string}
                  }
                },
                properties: %OpenApiSpex.Schema{
                  type: :object,
                  properties: %{
                    lifetime: %OpenApiSpex.Schema{type: :string},
                    max_mass: %OpenApiSpex.Schema{type: :integer},
                    max_jump_mass: %OpenApiSpex.Schema{type: :integer},
                    mass_regeneration: %OpenApiSpex.Schema{type: :integer}
                  }
                }
              }
            }
          },
          wandering: %OpenApiSpex.Schema{type: :array, items: %OpenApiSpex.Schema{type: :string}},
          triglavian_invasion_status: %OpenApiSpex.Schema{type: :string},
          sun_type_id: %OpenApiSpex.Schema{type: :integer}
        },
        required: ["solar_system_id", "solar_system_name"]
      }
    },
    required: ["data"]
  }

  @doc """
  GET /api/common/system-static-info?id=<solar_system_id>
  """
  @spec show_system_static(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation(:show_system_static,
    summary: "Get System Static Information",
    description: "Retrieves static information for a given solar system.",
    parameters: [
      id: [
        in: :query,
        description: "Solar system ID",
        type: :string,
        example: "30000142",
        required: true
      ]
    ],
    responses: [
      ok: {
        "System static info",
        "application/json",
        @system_static_response_schema
      }
    ]
  )

  def show_system_static(conn, params) do
    with {:ok, solar_system_str} <- APIUtils.require_param(params, "id"),
         {:ok, solar_system_id} <- APIUtils.parse_int(solar_system_str) do
      case CachedInfo.get_system_static_info(solar_system_id) do
        {:ok, system} when not is_nil(system) ->
          # Get basic system data
          data = static_system_to_json(system)

          # Enhance with wormhole type information if statics exist
          enhanced_data = enhance_with_static_details(data)

          # Return the enhanced data
          json(conn, %{data: enhanced_data})

        {:error, :not_found} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "System not found"})

        {:ok, nil} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "System not found"})
      end
    else
      {:error, msg} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: msg})
    end
  end

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

  defp enhance_with_static_details(data) do
    if data[:statics] && length(data[:statics]) > 0 do
      # Add the enhanced static details to the response
      Map.put(data, :static_details, get_static_details(data[:statics]))
    else
      # No statics, return the original data
      data
    end
  end

  defp get_static_details(statics) do
    # Get wormhole data from CachedInfo
    {:ok, wormhole_types} = CachedInfo.get_wormhole_types()
    wormhole_classes = CachedInfo.get_wormhole_classes!()

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
