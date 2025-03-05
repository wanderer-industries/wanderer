defmodule WandererAppWeb.CommonAPIController do
  use WandererAppWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias WandererApp.CachedInfo
  alias WandererAppWeb.UtilAPIController, as: Util

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
  operation :show_system_static,
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
  def show_system_static(conn, params) do
    with {:ok, solar_system_str} <- Util.require_param(params, "id"),
         {:ok, solar_system_id} <- Util.parse_int(solar_system_str) do
      case CachedInfo.get_system_static_info(solar_system_id) do
        {:ok, system} ->
          data = static_system_to_json(system)
          json(conn, %{data: data})

        {:error, :not_found} ->
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
end
