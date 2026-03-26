defmodule WandererAppWeb.PluginConfigApiController do
  @moduledoc """
  API controller for external bots to discover which maps have enabled their
  plugin and retrieve configuration.

  GET /api/plugins/:plugin_name/config
  Authorization: Bearer {PLUGIN_API_KEY}
  """

  use WandererAppWeb, :controller

  alias WandererApp.Api.MapPluginConfig
  alias WandererApp.Plugins.PluginRegistry

  require Logger

  def show(conn, %{"plugin_name" => plugin_name}) do
    plugin = PluginRegistry.get_plugin(plugin_name)

    if is_nil(plugin) do
      conn
      |> put_status(404)
      |> json(%{error: "Unknown plugin: #{plugin_name}"})
    else
      show_plugin_config(conn, plugin_name, plugin)
    end
  end

  defp show_plugin_config(conn, plugin_name, plugin) do
    case MapPluginConfig.enabled_by_plugin(plugin_name) do
      {:ok, configs} ->
        maps_by_id = load_maps_by_id(Enum.map(configs, & &1.map_id))

        configs =
          configs
          |> filter_deleted_maps(maps_by_id)
          |> maybe_filter_by_subscription(plugin)

        {maps_data, version, updated_at} =
          Enum.reduce(configs, {[], 0, nil}, fn config, {maps_acc, max_ver, max_at} ->
            map_entry = build_map_response(config, maps_by_id)
            maps_acc = if map_entry, do: [map_entry | maps_acc], else: maps_acc
            max_ver = max(config.config_version, max_ver)

            max_at =
              case max_at do
                nil -> config.updated_at
                prev -> Enum.max([prev, config.updated_at], DateTime)
              end

            {maps_acc, max_ver, max_at}
          end)

        json(conn, %{
          data: %{
            maps: Enum.reverse(maps_data),
            version: version,
            updated_at: updated_at || DateTime.utc_now()
          }
        })

      {:error, reason} ->
        Logger.error("Failed to fetch plugin configs: #{inspect(reason)}")

        conn
        |> put_status(500)
        |> json(%{error: "Internal server error"})
    end
  end

  defp load_maps_by_id(map_ids) do
    ids = Enum.uniq(map_ids)

    case WandererApp.Api.Map.by_ids(ids, load: [:owner]) do
      {:ok, maps} ->
        Map.new(maps, fn map -> {map.id, map} end)

      {:error, _reason} ->
        %{}
    end
  end

  defp filter_deleted_maps(configs, maps_by_id) do
    Enum.filter(configs, fn config ->
      case Map.get(maps_by_id, config.map_id) do
        %{deleted: true} -> false
        %{} -> true
        nil -> false
      end
    end)
  end

  defp maybe_filter_by_subscription(configs, %{requires_subscription: true}) do
    if WandererApp.Env.map_subscriptions_enabled?() do
      Enum.filter(configs, fn config ->
        case WandererApp.Map.is_subscription_active?(config.map_id) do
          {:ok, true} -> true
          _ -> false
        end
      end)
    else
      configs
    end
  end

  defp maybe_filter_by_subscription(configs, _plugin), do: configs

  defp build_map_response(config, maps_by_id) do
    case Map.get(maps_by_id, config.map_id) do
      nil ->
        nil

      map ->
        parsed_config = PluginRegistry.parse_config_json(config.config)
        owner_name = get_owner_display_name(map.owner)

        %{
          slug: map.slug,
          name: map.name,
          map_id: map.id,
          owner: owner_name,
          discord: Map.get(parsed_config, "discord", %{}),
          features: Map.get(parsed_config, "features", %{}),
          settings: Map.get(parsed_config, "settings", %{})
        }
    end
  end

  defp get_owner_display_name(nil), do: "Unknown"

  defp get_owner_display_name(character) do
    cond do
      is_binary(character.alliance_name) and character.alliance_name != "" ->
        character.alliance_name

      is_binary(character.corporation_name) and character.corporation_name != "" ->
        character.corporation_name

      true ->
        character.name
    end
  end
end
