defmodule WandererApp.Map.Operations.Systems do
  @moduledoc """
  CRUD and batch upsert for map systems.
  """

  alias WandererApp.MapSystemRepo
  alias WandererApp.Map.Server
  alias WandererApp.Map.Operations.Connections
  require Logger

  @spec list_systems(String.t()) :: [map()]
  def list_systems(map_id) do
    with {:ok, systems} <- MapSystemRepo.get_visible_by_map(map_id) do
      systems
    else
      _ -> []
    end
  end

  @spec get_system(String.t(), integer()) :: {:ok, map()} | {:error, :not_found}
  def get_system(map_id, system_id) do
    MapSystemRepo.get_by_map_and_solar_system_id(map_id, system_id)
  end

  @spec create_system(Plug.Conn.t(), map()) :: {:ok, map()} | {:error, atom()}
  def create_system(
        %{assigns: %{map_id: map_id, owner_character_id: char_id, owner_user_id: user_id}} =
          _conn,
        params
      ) do
    do_create_system(map_id, user_id, char_id, params)
  end

  def create_system(_conn, _params), do: {:error, :missing_params}

  # Private helper for batch upsert
  defp create_system_batch(%{map_id: map_id, user_id: user_id, char_id: char_id}, params) do
    do_create_system(map_id, user_id, char_id, params)
  end

  defp do_create_system(map_id, user_id, char_id, params) do
    with {:ok, system_id} <- fetch_system_id(params),
         coords <- normalize_coordinates(params),
         :ok <-
           Server.add_system(
             map_id,
             %{solar_system_id: system_id, coordinates: coords},
             user_id,
             char_id
           ) do
      # System creation is async, but if add_system returns :ok, 
      # it means the operation was queued successfully
      {:ok, %{solar_system_id: system_id}}
    else
      {:error, reason} when is_binary(reason) ->
        Logger.warning("[do_create_system] Expected error: #{inspect(reason)}")
        {:error, :expected_error}

      error ->
        Logger.error("[do_create_system] Unexpected error: #{inspect(error)}")
        {:error, :unexpected_error}
    end
  end

  @spec update_system(Plug.Conn.t(), integer(), map()) :: {:ok, map()} | {:error, atom()}
  def update_system(%{assigns: %{map_id: map_id}} = _conn, system_id, attrs) do
    with {:ok, current} <- MapSystemRepo.get_by_map_and_solar_system_id(map_id, system_id),
         x_raw <- Map.get(attrs, "position_x", Map.get(attrs, :position_x, current.position_x)),
         y_raw <- Map.get(attrs, "position_y", Map.get(attrs, :position_y, current.position_y)),
         {:ok, x} <- parse_int(x_raw, "position_x"),
         {:ok, y} <- parse_int(y_raw, "position_y"),
         coords = %{x: x, y: y},
         :ok <- apply_system_updates(map_id, system_id, attrs, coords),
         {:ok, system} <- MapSystemRepo.get_by_map_and_solar_system_id(map_id, system_id) do
      {:ok, system}
    else
      {:error, reason} when is_binary(reason) ->
        Logger.warning("[update_system] Expected error: #{inspect(reason)}")
        {:error, :expected_error}

      _ ->
        Logger.error("[update_system] Unexpected error")
        {:error, :unexpected_error}
    end
  end

  def update_system(_conn, _system_id, _attrs), do: {:error, :missing_params}

  @spec delete_system(Plug.Conn.t(), integer()) :: {:ok, integer()} | {:error, atom()}
  def delete_system(
        %{assigns: %{map_id: map_id, owner_character_id: char_id, owner_user_id: user_id}} =
          _conn,
        system_id
      ) do
    with {:ok, _} <- MapSystemRepo.get_by_map_and_solar_system_id(map_id, system_id),
         :ok <- Server.delete_systems(map_id, [system_id], user_id, char_id) do
      {:ok, 1}
    else
      {:error, :not_found} ->
        Logger.warning("[delete_system] System not found: #{inspect(system_id)}")
        {:error, :not_found}

      _ ->
        Logger.error("[delete_system] Unexpected error")
        {:error, :unexpected_error}
    end
  end

  def delete_system(_conn, _system_id), do: {:error, :missing_params}

  @spec upsert_systems_and_connections(Plug.Conn.t(), [map()], [map()]) ::
          {:ok, map()} | {:error, atom()}
  def upsert_systems_and_connections(
        %{assigns: %{map_id: map_id, owner_character_id: char_id, owner_user_id: user_id}} = conn,
        systems,
        connections
      ) do
    assigns = %{map_id: map_id, user_id: user_id, char_id: char_id}

    {created_s, updated_s, _skipped_s} =
      upsert_each(systems, fn sys -> create_system_batch(assigns, sys) end, 0, 0, 0)

    conn_results =
      connections
      |> Enum.reduce(%{created: 0, updated: 0, skipped: 0}, fn conn_data, acc ->
        case Connections.upsert_single(conn, conn_data) do
          {:ok, :created} -> %{acc | created: acc.created + 1}
          {:ok, :updated} -> %{acc | updated: acc.updated + 1}
          _ -> %{acc | skipped: acc.skipped + 1}
        end
      end)

    {:ok,
     %{
       systems: %{created: created_s, updated: updated_s},
       connections: %{created: conn_results.created, updated: conn_results.updated}
     }}
  end

  def upsert_systems_and_connections(_conn, _systems, _connections), do: {:error, :missing_params}

  # -- Internal Helpers -------------------------------------------------------

  defp fetch_system_id(%{"solar_system_id" => id}), do: parse_int(id, "solar_system_id")

  defp fetch_system_id(%{solar_system_id: id}) when not is_nil(id),
    do: parse_int(id, "solar_system_id")

  defp fetch_system_id(_), do: {:error, "Missing system identifier (id)"}

  defp parse_int(val, _field) when is_integer(val), do: {:ok, val}

  defp parse_int(val, field) when is_binary(val) do
    case Integer.parse(val) do
      {i, _} -> {:ok, i}
      _ -> {:error, "Invalid #{field}: #{val}"}
    end
  end

  defp parse_int(nil, field), do: {:error, "Missing #{field}"}
  defp parse_int(val, field), do: {:error, "Invalid #{field} type: #{inspect(val)}"}

  defp normalize_coordinates(%{"coordinates" => %{"x" => x, "y" => y}})
       when is_number(x) and is_number(y),
       do: %{x: x, y: y}

  defp normalize_coordinates(%{coordinates: %{x: x, y: y}}) when is_number(x) and is_number(y),
    do: %{x: x, y: y}

  defp normalize_coordinates(params) do
    %{
      x: params |> Map.get("position_x", Map.get(params, :position_x, 0)),
      y: params |> Map.get("position_y", Map.get(params, :position_y, 0))
    }
  end

  defp apply_system_updates(map_id, system_id, attrs, %{x: x, y: y}) do
    with :ok <-
           Server.update_system_position(map_id, %{
             solar_system_id: system_id,
             position_x: round(x),
             position_y: round(y)
           }) do
      attrs
      |> Map.drop([
        :coordinates,
        :position_x,
        :position_y,
        :solar_system_id,
        "coordinates",
        "position_x",
        "position_y",
        "solar_system_id"
      ])
      |> Enum.reduce_while(:ok, fn {key, val}, _ ->
        case update_system_field(map_id, system_id, to_string(key), val) do
          :ok -> {:cont, :ok}
          err -> {:halt, err}
        end
      end)
    end
  end

  defp update_system_field(map_id, system_id, field, val) do
    case field do
      "status" ->
        Server.update_system_status(map_id, %{
          solar_system_id: system_id,
          status: convert_status(val)
        })

      "description" ->
        Server.update_system_description(map_id, %{solar_system_id: system_id, description: val})

      "tag" ->
        Server.update_system_tag(map_id, %{solar_system_id: system_id, tag: val})

      "locked" ->
        bool = val in [true, "true", 1, "1"]
        Server.update_system_locked(map_id, %{solar_system_id: system_id, locked: bool})

      f when f in ["label", "labels"] ->
        labels =
          cond do
            is_list(val) -> val
            is_binary(val) -> String.split(val, ",", trim: true)
            true -> []
          end

        Server.update_system_labels(map_id, %{
          solar_system_id: system_id,
          labels: Enum.join(labels, ",")
        })

      "temporary_name" ->
        Server.update_system_temporary_name(map_id, %{
          solar_system_id: system_id,
          temporary_name: val
        })

      _ ->
        :ok
    end
  end

  defp convert_status("CLEAR"), do: 0
  defp convert_status("DANGEROUS"), do: 1
  defp convert_status("OCCUPIED"), do: 2
  defp convert_status("MASS_CRITICAL"), do: 3
  defp convert_status("TIME_CRITICAL"), do: 4
  defp convert_status("REINFORCED"), do: 5
  defp convert_status(i) when is_integer(i), do: i

  defp convert_status(s) when is_binary(s) do
    case Integer.parse(s) do
      {i, _} -> i
      _ -> 0
    end
  end

  defp convert_status(_), do: 0

  defp upsert_each([], _fun, c, u, d), do: {c, u, d}

  defp upsert_each([item | rest], fun, c, u, d) do
    case fun.(item) do
      {:ok, _} -> upsert_each(rest, fun, c + 1, u, d)
      :ok -> upsert_each(rest, fun, c + 1, u, d)
      {:skip, _} -> upsert_each(rest, fun, c, u + 1, d)
      _ -> upsert_each(rest, fun, c, u, d + 1)
    end
  end
end
