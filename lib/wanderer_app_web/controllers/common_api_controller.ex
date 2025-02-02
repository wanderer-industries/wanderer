defmodule WandererAppWeb.CommonAPIController do
  use WandererAppWeb, :controller

  alias WandererApp.CachedInfo
  alias WandererAppWeb.UtilAPIController, as: Util

  @doc """
  GET /api/common/system_static?id=<solar_system_id>

  Requires 'id' (the solar_system_id).

  Example:
      GET /api/common/system_static?id=31002229
  """
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

  # ----------------------------------------------
  # Private helpers
  # ----------------------------------------------

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
