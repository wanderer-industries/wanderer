defmodule WandererApp.Plugins.PluginRegistry do
  @moduledoc """
  Fixed catalog of known plugins. Plugins are defined in code, not in the database.
  Adding a new plugin requires a code change to this module.
  """

  require Logger

  @plugins %{
    "notifier" => %{
      name: "notifier",
      display_name: "Discord Notifier",
      description:
        "Sends map events (kills, new systems, characters, rallies) to Discord channels",
      requires_subscription: true
    }
  }

  @notifier_default_config %{
    "discord" => %{
      "bot_token" => "",
      "channels" => %{
        "primary" => "",
        "system_kill" => nil,
        "character_kill" => nil,
        "system" => nil,
        "character" => nil,
        "rally" => nil
      },
      "rally_group_ids" => []
    },
    "features" => %{
      "notifications_enabled" => true,
      "kill_notifications_enabled" => true,
      "system_notifications_enabled" => true,
      "character_notifications_enabled" => true,
      "rally_notifications_enabled" => true,
      "wormhole_only_kill_notifications" => false,
      "track_kspace" => true,
      "priority_systems_only" => false
    },
    "settings" => %{
      "corporation_kill_focus" => [],
      "character_exclude_list" => [],
      "system_exclude_list" => []
    }
  }

  @spec list_plugins() :: [map()]
  def list_plugins, do: Map.values(@plugins)

  @spec get_plugin(String.t()) :: map() | nil
  def get_plugin(name), do: Map.get(@plugins, name)

  @spec plugin_exists?(String.t()) :: boolean()
  def plugin_exists?(name), do: Map.has_key?(@plugins, name)

  @spec plugin_names() :: [String.t()]
  def plugin_names, do: Map.keys(@plugins)

  @spec default_config(String.t()) :: map() | nil
  def default_config("notifier"), do: @notifier_default_config
  def default_config(_), do: nil

  @spec parse_config_json(nil | String.t()) :: map()
  def parse_config_json(nil), do: %{}
  def parse_config_json(""), do: %{}

  def parse_config_json(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, parsed} ->
        parsed

      {:error, error} ->
        Logger.warning(
          "Failed to decode plugin config JSON: #{inspect(error)}, input: #{String.slice(json, 0, 200)}"
        )

        %{}
    end
  end

  @spec validate_config(String.t(), map()) :: {:ok, map()} | {:error, [String.t()]}
  def validate_config("notifier", config) when is_map(config) do
    with :ok <- validate_top_level_types(config),
         :ok <- validate_nested_types(config),
         :ok <- validate_required_fields(config) do
      {:ok, normalize_notifier_config(config)}
    end
  end

  def validate_config(plugin_name, _config) do
    if plugin_exists?(plugin_name),
      do: {:error, ["config must be a map"]},
      else: {:error, ["unknown plugin: #{plugin_name}"]}
  end

  defp validate_top_level_types(config) do
    errors =
      []
      |> check_is_map(Map.get(config, "discord", %{}), "discord must be a map")
      |> check_is_map(Map.get(config, "features", %{}), "features must be a map")
      |> check_is_map(Map.get(config, "settings", %{}), "settings must be a map")

    if errors == [], do: :ok, else: {:error, Enum.reverse(errors)}
  end

  defp validate_nested_types(config) do
    discord = Map.get(config, "discord", %{})

    errors =
      []
      |> check_is_map(Map.get(discord, "channels", %{}), "discord.channels must be a map")

    if errors == [], do: :ok, else: {:error, Enum.reverse(errors)}
  end

  defp validate_required_fields(config) do
    discord = Map.get(config, "discord", %{})

    errors =
      []
      |> require_non_blank(Map.get(discord, "bot_token"), "discord.bot_token is required")
      |> require_non_blank(
        get_in(discord, ["channels", "primary"]),
        "discord.channels.primary is required"
      )

    if errors == [], do: :ok, else: {:error, Enum.reverse(errors)}
  end

  defp normalize_notifier_config(config) do
    default = @notifier_default_config
    discord = ensure_map(Map.get(config, "discord"), Map.get(default, "discord"))
    channels = ensure_map(Map.get(discord, "channels"), get_in(default, ["discord", "channels"]))
    features = ensure_map(Map.get(config, "features"), Map.get(default, "features"))
    settings = ensure_map(Map.get(config, "settings"), Map.get(default, "settings"))

    normalized_discord = %{
      "bot_token" => Map.get(discord, "bot_token", ""),
      "channels" => Map.merge(get_in(default, ["discord", "channels"]), channels),
      "rally_group_ids" => ensure_list(Map.get(discord, "rally_group_ids", []))
    }

    normalized_features = Map.merge(Map.get(default, "features"), features)
    normalized_settings = Map.merge(Map.get(default, "settings"), settings)

    %{
      "discord" => normalized_discord,
      "features" => normalized_features,
      "settings" => normalized_settings
    }
  end

  defp require_non_blank(errors, value, message) do
    if is_binary(value) and String.trim(value) != "",
      do: errors,
      else: [message | errors]
  end

  defp check_is_map(errors, value, message) do
    if is_map(value),
      do: errors,
      else: [message | errors]
  end

  defp ensure_map(value, _default) when is_map(value), do: value
  defp ensure_map(_value, default) when is_map(default), do: default
  defp ensure_map(_value, _default), do: %{}

  defp ensure_list(value) when is_list(value), do: value
  defp ensure_list(_), do: []
end
