defmodule WandererAppWeb.APIController do
  use WandererAppWeb, :controller

  import Ash.Query, only: [filter: 2]
  alias WandererApp.Api

  alias WandererApp.Api.Map, as: MapResource
  alias WandererApp.MapSystemRepo
  alias WandererApp.MapCharacterSettingsRepo
  alias WandererApp.Api.Character


  plug :check_api_key

  # -----------------------------------------------------------------
  # SYSTEMS
  # -----------------------------------------------------------------

  @doc """
  GET /api/systems

  Requires either ?map_id=<UUID> OR ?slug=<map-slug> in the query params.

  Example:
      GET /api/systems?map_id=466e922b-e758-485e-9b86-afae06b88363
      GET /api/systems?slug=my-unique-wormhole-map
  """
  def list_systems(conn, params) do
    with {:ok, map_id} <- fetch_map_id(params) do
      case MapSystemRepo.get_visible_by_map(map_id) do
        {:ok, systems} ->
          # Convert each system to JSON-friendly map
          data = Enum.map(systems, &map_system_to_json/1)
          json(conn, %{data: data})

        {:error, reason} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "Could not fetch systems for map_id=#{map_id}: #{inspect(reason)}"})
      end
    else
      {:error, msg} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: msg})
    end
  end

  @doc """
  GET /api/system

  Requires 'id' (the solar_system_id)
  plus either ?map_id=<UUID> or ?slug=<map-slug>.

  Example:
      GET /api/system?id=31002229&map_id=466e922b-e758-485e-9b86-afae06b88363
      GET /api/system?id=31002229&slug=my-unique-wormhole-map
  """
  def show_system(conn, params) do
    with {:ok, solar_system_str} <- require_param(params, "id"),
         {:ok, solar_system_id} <- parse_int(solar_system_str),
         {:ok, map_id} <- fetch_map_id(params) do
      case MapSystemRepo.get_by_map_and_solar_system_id(map_id, solar_system_id) do
        {:ok, system} ->
          data = map_system_to_json(system)
          json(conn, %{data: data})

        {:error, :not_found} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "System not found in map=#{map_id}"})
      end
    else
      {:error, msg} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: msg})
    end
  end


  # -----------------------------------------------------------------
  # Characters
  # -----------------------------------------------------------------

   @doc """
  GET /api/tracked_characters_with_info

  Example usage:
    GET /api/tracked_characters_with_info?map_id=<uuid>
    GET /api/tracked_characters_with_info?slug=<map-slug>

  Returns a list of tracked records, plus their fully-loaded `character` data.
  """
  def tracked_characters_with_info(conn, params) do
    with {:ok, map_id} <- fetch_map_id(params) do
      case MapCharacterSettingsRepo.get_tracked_by_map_all(map_id) do
        {:ok, settings_list} ->
          character_ids = Enum.map(settings_list, & &1.character_id)

          case read_characters_by_ids(character_ids) do
            {:ok, char_list} ->
              chars_by_id = Map.new(char_list, &{&1.id, &1})

              data =
                Enum.map(settings_list, fn setting ->
                  found_char = Map.get(chars_by_id, setting.character_id)

                  %{
                    id: setting.id,
                    map_id: setting.map_id,
                    character_id: setting.character_id,
                    tracked: setting.tracked,
                    inserted_at: setting.inserted_at,
                    updated_at: setting.updated_at,
                    character:
                      if found_char do
                        character_to_json(found_char)
                      else
                        %{}
                      end
                  }
                end)

              json(conn, %{data: data})

            {:error, reason} ->
              conn
              |> put_status(:internal_server_error)
              |> json(%{error: "Could not load Character records: #{inspect(reason)}"})
          end

        {:error, reason} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "No tracked records found for map_id=#{map_id}: #{inspect(reason)}"})
      end
    else
      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: message})
    end
  end

  defp check_api_key(conn, _opts) do
    header = get_req_header(conn, "authorization") |> List.first()

    case header do
      "Bearer " <> incoming_token ->
        case fetch_map_id(conn.query_params) do
          {:ok, map_id} ->
            case WandererApp.Api.Map.by_id(map_id) do
              {:ok, map} ->
                if map.public_api_key == incoming_token do
                  conn
                else
                  conn
                  |> send_resp(401, "Unauthorized (invalid token for that map)")
                  |> halt()
                end

              {:error, _reason} ->
                conn
                |> send_resp(404, "Map not found")
                |> halt()
            end

          {:error, msg} ->
            conn
            |> send_resp(400, msg)
            |> halt()
        end

      _ ->
        conn
        |> send_resp(401, "Missing or invalid 'Bearer' token")
        |> halt()
    end
  end


  defp fetch_map_id(%{"map_id" => mid}) when is_binary(mid) and mid != "" do
    {:ok, mid}
  end

  defp fetch_map_id(%{"slug" => slug}) when is_binary(slug) and slug != "" do
    case MapResource.get_map_by_slug(slug) do
      {:ok, map} ->
        {:ok, map.id}

      {:error, _reason} ->
        {:error, "No map found for slug=#{slug}"}
    end
  end

  defp fetch_map_id(_), do: {:error, "Must provide either ?map_id=UUID or ?slug=SLUG"}

  defp require_param(params, key) do
    case params[key] do
      nil -> {:error, "Missing required param: #{key}"}
      "" -> {:error, "Param #{key} cannot be empty"}
      val -> {:ok, val}
    end
  end

  defp parse_int(str) do
    case Integer.parse(str) do
      {num, ""} -> {:ok, num}
      _ -> {:error, "Invalid integer for param id=#{str}"}
    end
  end

  defp read_characters_by_ids(ids) when is_list(ids) do
    if ids == [] do
      {:ok, []}
    else
      query =
        Character
        |> filter(id in ^ids)

      Api.read(query)
    end
  end


  defp map_system_to_json(system) do
    %{
      id: system.id,
      map_id: system.map_id,
      solar_system_id: system.solar_system_id,
      name: system.name,
      custom_name: system.custom_name,
      description: system.description,
      tag: system.tag,
      labels: system.labels,
      locked: system.locked,
      visible: system.visible,
      status: system.status,
      position_x: system.position_x,
      position_y: system.position_y,
      inserted_at: system.inserted_at,
      updated_at: system.updated_at
    }
  end


  defp character_to_json(ch) do
    %{
      id: ch.id,
      eve_id: ch.eve_id,
      name: ch.name,
      corporation_id: ch.corporation_id,
      corporation_name: ch.corporation_name,
      corporation_ticker: ch.corporation_ticker,
      alliance_id: ch.alliance_id,
      alliance_name: ch.alliance_name,
      alliance_ticker: ch.alliance_ticker,
      inserted_at: ch.inserted_at,
      updated_at: ch.updated_at
    }
  end
end
