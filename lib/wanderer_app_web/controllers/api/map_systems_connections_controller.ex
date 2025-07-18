defmodule WandererAppWeb.Api.MapSystemsConnectionsController do
  @moduledoc """
  Combined API controller for retrieving map systems and connections together.
  This provides a single endpoint that returns both systems and connections for a map,
  similar to the legacy API's combined functionality.
  """

  use WandererAppWeb, :controller
  use OpenApiSpex.ControllerSpecs

  require Ash.Query
  import Ash.Expr

  alias WandererApp.Api.MapSystem
  alias WandererApp.Api.MapConnection

  @doc """
  GET /api/v1/maps/{map_id}/systems_and_connections

  Returns both systems and connections for a map in a single response.
  This is a convenience endpoint that combines the functionality of
  separate systems and connections endpoints.
  """
  operation(:show,
    summary: "Get Map Systems and Connections",
    description: "Retrieve both systems and connections for a map in a single response",
    parameters: [
      map_id: [
        in: :path,
        description: "Map ID",
        type: :string,
        required: true,
        example: "1234567890abcdef"
      ]
    ],
    responses: [
      ok: {
        "Combined systems and connections data",
        "application/json",
        %OpenApiSpex.Schema{
          type: :object,
          properties: %{
            systems: %OpenApiSpex.Schema{
              type: :array,
              items: %OpenApiSpex.Schema{
                type: :object,
                properties: %{
                  id: %OpenApiSpex.Schema{type: :string},
                  solar_system_id: %OpenApiSpex.Schema{type: :integer},
                  name: %OpenApiSpex.Schema{type: :string},
                  status: %OpenApiSpex.Schema{type: :string},
                  visible: %OpenApiSpex.Schema{type: :boolean},
                  locked: %OpenApiSpex.Schema{type: :boolean},
                  position_x: %OpenApiSpex.Schema{type: :integer},
                  position_y: %OpenApiSpex.Schema{type: :integer}
                }
              }
            },
            connections: %OpenApiSpex.Schema{
              type: :array,
              items: %OpenApiSpex.Schema{
                type: :object,
                properties: %{
                  id: %OpenApiSpex.Schema{type: :string},
                  solar_system_source: %OpenApiSpex.Schema{type: :integer},
                  solar_system_target: %OpenApiSpex.Schema{type: :integer},
                  type: %OpenApiSpex.Schema{type: :string},
                  time_status: %OpenApiSpex.Schema{type: :string},
                  mass_status: %OpenApiSpex.Schema{type: :string}
                }
              }
            }
          }
        }
      },
      not_found: {"Map not found", "application/json", %OpenApiSpex.Schema{type: :object}},
      unauthorized: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def show(conn, %{"map_id" => map_id}) do
    case load_map_data(map_id) do
      {:ok, systems, connections} ->
        conn
        |> put_status(:ok)
        |> json(%{
          systems: Enum.map(systems, &format_system/1),
          connections: Enum.map(connections, &format_connection/1)
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Map not found"})

      {:error, :unauthorized} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Unauthorized"})
    end
  end

  defp load_map_data(map_id) do
    try do
      # Load systems for the map
      systems =
        MapSystem
        |> Ash.Query.filter(expr(map_id == ^map_id and visible == true))
        |> Ash.read!()

      # Load connections for the map
      connections =
        MapConnection
        |> Ash.Query.filter(expr(map_id == ^map_id))
        |> Ash.read!()

      {:ok, systems, connections}
    rescue
      Ash.Error.Query.NotFound -> {:error, :not_found}
      Ash.Error.Forbidden -> {:error, :unauthorized}
      _ -> {:error, :not_found}
    end
  end

  defp format_system(system) do
    %{
      id: system.id,
      solar_system_id: system.solar_system_id,
      name: system.name || system.custom_name,
      status: system.status,
      visible: system.visible,
      locked: system.locked,
      position_x: system.position_x,
      position_y: system.position_y,
      tag: system.tag,
      description: system.description,
      labels: system.labels,
      inserted_at: system.inserted_at,
      updated_at: system.updated_at
    }
  end

  defp format_connection(connection) do
    %{
      id: connection.id,
      solar_system_source: connection.solar_system_source,
      solar_system_target: connection.solar_system_target,
      type: connection.type,
      time_status: connection.time_status,
      mass_status: connection.mass_status,
      ship_size_type: connection.ship_size_type,
      inserted_at: connection.inserted_at,
      updated_at: connection.updated_at
    }
  end
end
