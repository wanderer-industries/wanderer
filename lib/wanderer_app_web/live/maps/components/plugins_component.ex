defmodule WandererAppWeb.Maps.PluginsComponent do
  @moduledoc """
  LiveView component for managing plugin configuration on a map.

  Displays available plugins, allows enabling/disabling, and provides
  plugin-specific configuration forms.
  """

  use WandererAppWeb, :live_component
  require Logger

  alias WandererApp.Api.MapPluginConfig
  alias WandererApp.Plugins.PluginRegistry

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       plugins: [],
       configs: %{},
       parsed_configs: %{},
       loaded_map_id: nil,
       loading: true,
       error: nil,
       saving: false,
       show_bot_token: false,
       show_advanced: false,
       success_message: nil
     )}
  end

  @impl true
  def update(%{map_id: map_id} = assigns, socket) do
    plugins = PluginRegistry.list_plugins()

    socket =
      socket
      |> assign(assigns)
      |> assign(plugins: plugins)

    socket =
      if socket.assigns.loaded_map_id != map_id do
        socket
        |> load_configs(map_id)
        |> assign(loaded_map_id: map_id)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_plugin", %{"plugin" => plugin_name}, socket) do
    map_id = socket.assigns.map_id
    configs = socket.assigns.configs

    case Map.get(configs, plugin_name) do
      nil ->
        default_config = PluginRegistry.default_config(plugin_name)

        case MapPluginConfig.create(%{
               map_id: map_id,
               plugin_name: plugin_name,
               enabled: true,
               config: Jason.encode!(default_config)
             }) do
          {:ok, config} ->
            {:noreply,
             socket
             |> put_config(plugin_name, config, default_config)
             |> assign(success_message: "Plugin enabled", error: nil)}

          {:error, reason} ->
            Logger.error("Failed to enable plugin: #{inspect(reason)}")
            {:noreply, assign(socket, error: "Failed to enable plugin")}
        end

      config ->
        new_enabled = not config.enabled

        case MapPluginConfig.update(config, %{enabled: new_enabled}) do
          {:ok, updated} ->
            message = if new_enabled, do: "Plugin enabled", else: "Plugin disabled"

            {:noreply,
             socket
             |> put_config(plugin_name, updated)
             |> assign(success_message: message, error: nil)}

          {:error, reason} ->
            Logger.error("Failed to toggle plugin: #{inspect(reason)}")
            {:noreply, assign(socket, error: "Failed to update plugin")}
        end
    end
  end

  @impl true
  def handle_event("toggle_bot_token", _, socket) do
    {:noreply, assign(socket, show_bot_token: !socket.assigns.show_bot_token)}
  end

  @impl true
  def handle_event("toggle_advanced", _, socket) do
    {:noreply, assign(socket, show_advanced: !socket.assigns.show_advanced)}
  end

  @impl true
  def handle_event("save_plugin_config", %{"plugin" => plugin_name} = params, socket) do
    socket = assign(socket, saving: true)
    config = Map.get(socket.assigns.configs, plugin_name)

    if is_nil(config) do
      {:noreply, assign(socket, saving: false, error: "Plugin not enabled")}
    else
      with {:ok, new_config} <- build_config_from_params(plugin_name, params),
           {:ok, validated_config} <- PluginRegistry.validate_config(plugin_name, new_config),
           {:ok, updated} <-
             MapPluginConfig.update(config, %{config: Jason.encode!(validated_config)}) do
        {:noreply,
         socket
         |> put_config(plugin_name, updated, validated_config)
         |> assign(success_message: "Configuration saved", error: nil, saving: false)}
      else
        {:error, errors} when is_list(errors) ->
          {:noreply, assign(socket, error: Enum.join(errors, ", "), saving: false)}

        {:error, reason} ->
          Logger.error("Failed to save plugin config: #{inspect(reason)}")
          {:noreply, assign(socket, error: "Failed to save configuration", saving: false)}
      end
    end
  end

  @impl true
  def handle_event("dismiss_message", _, socket) do
    {:noreply, assign(socket, success_message: nil, error: nil)}
  end

  defp put_config(socket, plugin_name, config, parsed \\ nil) do
    parsed = parsed || PluginRegistry.parse_config_json(config.config)

    socket
    |> assign(configs: Map.put(socket.assigns.configs, plugin_name, config))
    |> assign(parsed_configs: Map.put(socket.assigns.parsed_configs, plugin_name, parsed))
  end

  defp load_configs(socket, map_id) do
    case MapPluginConfig.by_map(map_id) do
      {:ok, configs} ->
        {configs_map, parsed_map} =
          Enum.reduce(configs, {%{}, %{}}, fn c, {cm, pm} ->
            {Map.put(cm, c.plugin_name, c),
             Map.put(pm, c.plugin_name, PluginRegistry.parse_config_json(c.config))}
          end)

        assign(socket,
          configs: configs_map,
          parsed_configs: parsed_map,
          loading: false,
          error: nil
        )

      {:error, reason} ->
        Logger.error("Failed to load plugin configs: #{inspect(reason)}")

        assign(socket,
          configs: %{},
          parsed_configs: %{},
          loading: false,
          error: "Failed to load plugin settings"
        )
    end
  end

  defp build_config_from_params("notifier", params) do
    int_fields = [
      {"corporation_kill_focus", Map.get(params, "corporation_kill_focus", "")},
      {"character_exclude_list", Map.get(params, "character_exclude_list", "")},
      {"system_exclude_list", Map.get(params, "system_exclude_list", "")}
    ]

    {settings, errors} =
      Enum.reduce(int_fields, {%{}, []}, fn {field, raw}, {settings, errors} ->
        case parse_comma_list_int(raw) do
          {:ok, ints} ->
            {Map.put(settings, field, ints), errors}

          {:error, invalid} ->
            {Map.put(settings, field, []),
             ["#{field}: invalid values: #{Enum.join(invalid, ", ")}" | errors]}
        end
      end)

    config = %{
      "discord" => %{
        "bot_token" => Map.get(params, "bot_token", ""),
        "channels" => %{
          "primary" => Map.get(params, "channel_primary", ""),
          "system_kill" => nilify(Map.get(params, "channel_system_kill", "")),
          "character_kill" => nilify(Map.get(params, "channel_character_kill", "")),
          "system" => nilify(Map.get(params, "channel_system", "")),
          "character" => nilify(Map.get(params, "channel_character", "")),
          "rally" => nilify(Map.get(params, "channel_rally", ""))
        },
        "rally_group_ids" => parse_comma_list(Map.get(params, "rally_group_ids", ""))
      },
      "features" => %{
        "notifications_enabled" => params["notifications_enabled"] == "true",
        "kill_notifications_enabled" => params["kill_notifications_enabled"] == "true",
        "system_notifications_enabled" => params["system_notifications_enabled"] == "true",
        "character_notifications_enabled" => params["character_notifications_enabled"] == "true",
        "rally_notifications_enabled" => params["rally_notifications_enabled"] == "true",
        "wormhole_only_kill_notifications" =>
          params["wormhole_only_kill_notifications"] == "true",
        "track_kspace" => params["track_kspace"] == "true",
        "priority_systems_only" => params["priority_systems_only"] == "true"
      },
      "settings" => settings
    }

    case errors do
      [] -> {:ok, config}
      _ -> {:error, Enum.reverse(errors)}
    end
  end

  defp build_config_from_params(_, _params), do: {:ok, %{}}

  defp nilify(""), do: nil
  defp nilify(val), do: val

  defp parse_comma_list(""), do: []

  defp parse_comma_list(str) when is_binary(str) do
    str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_comma_list(_), do: []

  defp parse_comma_list_int(str) do
    {ints, invalid} =
      str
      |> parse_comma_list()
      |> Enum.reduce({[], []}, fn s, {ints, invalid} ->
        case Integer.parse(s) do
          {n, _} -> {[n | ints], invalid}
          :error -> {ints, [s | invalid]}
        end
      end)

    case invalid do
      [] -> {:ok, Enum.reverse(ints)}
      _ -> {:error, Enum.reverse(invalid)}
    end
  end

  defp config_val(parsed_configs, plugin_name, path, default) do
    case Map.get(parsed_configs, plugin_name) do
      nil -> default
      parsed -> get_in(parsed, path) || default
    end
  end

  defp enabled?(configs, plugin_name) do
    case Map.get(configs, plugin_name) do
      nil -> false
      config -> config.enabled
    end
  end

  defp comma_join(list) when is_list(list), do: Enum.join(list, ", ")
  defp comma_join(_), do: ""

  defp plugin_checkbox(assigns) do
    ~H"""
    <label class="flex items-center gap-2 cursor-pointer py-1">
      <input type="hidden" name={@name} value="false" />
      <input
        type="checkbox"
        name={@name}
        value="true"
        class="checkbox checkbox-primary checkbox-sm"
        checked={@checked}
      />
      <span class="text-sm">{@label}</span>
    </label>
    """
  end

  defp plugin_text_input(assigns) do
    assigns = assign_new(assigns, :hint, fn -> nil end)

    ~H"""
    <div>
      <label class="block text-sm text-stone-400 mb-1">{@label}</label>
      <input
        type="text"
        name={@name}
        value={@value}
        class="input input-bordered text-sm bg-neutral-800 text-white w-full"
        placeholder={@placeholder}
      />
      <p :if={@hint} class="text-xs text-stone-500 mt-1">{@hint}</p>
    </div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="plugins-config">
      <%= if @loading do %>
        <div class="flex justify-center py-4">
          <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        </div>
      <% else %>
        <%= if @error do %>
          <div
            class="border border-red-400 text-red-300 px-4 py-3 rounded mb-4 flex justify-between items-center"
            phx-click="dismiss_message"
            phx-target={@myself}
          >
            <p>{@error}</p>
            <span class="cursor-pointer text-sm">&times;</span>
          </div>
        <% end %>

        <%= if @success_message do %>
          <div
            class="border border-green-400 text-green-300 px-4 py-3 rounded mb-4 flex justify-between items-center"
            phx-click="dismiss_message"
            phx-target={@myself}
          >
            <p>{@success_message}</p>
            <span class="cursor-pointer text-sm">&times;</span>
          </div>
        <% end %>

        <%= for plugin <- @plugins do %>
          <div class="mb-6">
            <div class="flex items-start gap-4 mb-3">
              <div>
                <h3 class="text-lg font-semibold">{plugin.display_name}</h3>
                <p class="text-sm text-stone-400">{plugin.description}</p>
              </div>
              <label class="flex items-center gap-2 cursor-pointer shrink-0 ml-auto">
                <input
                  type="checkbox"
                  class="checkbox checkbox-primary"
                  checked={enabled?(@configs, plugin.name)}
                  phx-click="toggle_plugin"
                  phx-value-plugin={plugin.name}
                  phx-target={@myself}
                />
                <span class="text-sm">
                  {if enabled?(@configs, plugin.name), do: "Enabled", else: "Disabled"}
                </span>
              </label>
            </div>

            <%= if enabled?(@configs, plugin.name) and plugin.name == "notifier" do %>
              <form
                phx-submit="save_plugin_config"
                phx-target={@myself}
                class="border border-stone-700 rounded p-4 space-y-4"
              >
                <input type="hidden" name="plugin" value="notifier" />

                <%!-- Discord Setup --%>
                <div>
                  <h4 class="text-md font-semibold mb-2 text-stone-300">Discord Setup</h4>
                  <div class="space-y-3">
                    <div>
                      <label class="block text-sm text-stone-400 mb-1">Bot Token *</label>
                      <div class="flex gap-2">
                        <input
                          type={if @show_bot_token, do: "text", else: "password"}
                          name="bot_token"
                          value={
                            config_val(@parsed_configs, "notifier", ["discord", "bot_token"], "")
                          }
                          class="input input-bordered text-sm bg-neutral-800 text-white flex-1"
                          placeholder="Discord bot token"
                        />
                        <button
                          type="button"
                          phx-click="toggle_bot_token"
                          phx-target={@myself}
                          class="btn btn-sm"
                        >
                          {if @show_bot_token, do: "Hide", else: "Show"}
                        </button>
                      </div>
                    </div>
                    <.plugin_text_input
                      label="Primary Channel ID *"
                      name="channel_primary"
                      value={
                        config_val(
                          @parsed_configs,
                          "notifier",
                          ["discord", "channels", "primary"],
                          ""
                        )
                      }
                      placeholder="Channel ID for all notifications (required)"
                    />
                  </div>
                </div>

                <%!-- Notification Toggles --%>
                <div class="grid grid-cols-2 gap-2">
                  <.plugin_checkbox
                    name="notifications_enabled"
                    label="Notifications Enabled"
                    checked={
                      config_val(
                        @parsed_configs,
                        "notifier",
                        ["features", "notifications_enabled"],
                        true
                      )
                    }
                  />
                  <.plugin_checkbox
                    name="kill_notifications_enabled"
                    label="Kill Notifications"
                    checked={
                      config_val(
                        @parsed_configs,
                        "notifier",
                        ["features", "kill_notifications_enabled"],
                        true
                      )
                    }
                  />
                  <.plugin_checkbox
                    name="system_notifications_enabled"
                    label="System Notifications"
                    checked={
                      config_val(
                        @parsed_configs,
                        "notifier",
                        ["features", "system_notifications_enabled"],
                        true
                      )
                    }
                  />
                  <.plugin_checkbox
                    name="character_notifications_enabled"
                    label="Character Notifications"
                    checked={
                      config_val(
                        @parsed_configs,
                        "notifier",
                        ["features", "character_notifications_enabled"],
                        true
                      )
                    }
                  />
                  <.plugin_checkbox
                    name="rally_notifications_enabled"
                    label="Rally Notifications"
                    checked={
                      config_val(
                        @parsed_configs,
                        "notifier",
                        ["features", "rally_notifications_enabled"],
                        true
                      )
                    }
                  />
                </div>

                <%!-- Advanced Settings Toggle --%>
                <div
                  class="flex items-center gap-2 cursor-pointer py-2 text-stone-400 hover:text-stone-300"
                  phx-click="toggle_advanced"
                  phx-target={@myself}
                >
                  <span class="text-xs">{if @show_advanced, do: "▼", else: "▶"}</span>
                  <span class="text-sm font-medium">Advanced Settings</span>
                </div>

                <%= if @show_advanced do %>
                  <%!-- Channel Overrides --%>
                  <div>
                    <h4 class="text-md font-semibold mb-2 text-stone-300">Channel Overrides</h4>
                    <div class="grid grid-cols-2 gap-3">
                      <.plugin_text_input
                        label="System Kill Channel"
                        name="channel_system_kill"
                        value={
                          config_val(
                            @parsed_configs,
                            "notifier",
                            ["discord", "channels", "system_kill"],
                            ""
                          )
                        }
                        placeholder="Falls back to primary"
                      />
                      <.plugin_text_input
                        label="Character Kill Channel"
                        name="channel_character_kill"
                        value={
                          config_val(
                            @parsed_configs,
                            "notifier",
                            ["discord", "channels", "character_kill"],
                            ""
                          )
                        }
                        placeholder="Falls back to primary"
                      />
                      <.plugin_text_input
                        label="System Channel"
                        name="channel_system"
                        value={
                          config_val(
                            @parsed_configs,
                            "notifier",
                            ["discord", "channels", "system"],
                            ""
                          )
                        }
                        placeholder="Falls back to primary"
                      />
                      <.plugin_text_input
                        label="Character Channel"
                        name="channel_character"
                        value={
                          config_val(
                            @parsed_configs,
                            "notifier",
                            ["discord", "channels", "character"],
                            ""
                          )
                        }
                        placeholder="Falls back to primary"
                      />
                      <.plugin_text_input
                        label="Rally Channel"
                        name="channel_rally"
                        value={
                          config_val(
                            @parsed_configs,
                            "notifier",
                            ["discord", "channels", "rally"],
                            ""
                          )
                        }
                        placeholder="Falls back to primary"
                      />
                      <.plugin_text_input
                        label="Rally Group IDs"
                        name="rally_group_ids"
                        value={
                          comma_join(
                            config_val(
                              @parsed_configs,
                              "notifier",
                              ["discord", "rally_group_ids"],
                              []
                            )
                          )
                        }
                        placeholder="Comma-separated group IDs"
                      />
                    </div>
                  </div>

                  <%!-- Behavior Toggles --%>
                  <div>
                    <h4 class="text-md font-semibold mb-2 text-stone-300">Behavior</h4>
                    <div class="grid grid-cols-2 gap-2">
                      <.plugin_checkbox
                        name="wormhole_only_kill_notifications"
                        label="Wormhole-only Kills"
                        checked={
                          config_val(
                            @parsed_configs,
                            "notifier",
                            ["features", "wormhole_only_kill_notifications"],
                            false
                          )
                        }
                      />
                      <.plugin_checkbox
                        name="track_kspace"
                        label="Track K-Space"
                        checked={
                          config_val(
                            @parsed_configs,
                            "notifier",
                            ["features", "track_kspace"],
                            true
                          )
                        }
                      />
                      <.plugin_checkbox
                        name="priority_systems_only"
                        label="Priority Systems Only"
                        checked={
                          config_val(
                            @parsed_configs,
                            "notifier",
                            ["features", "priority_systems_only"],
                            false
                          )
                        }
                      />
                    </div>
                  </div>

                  <%!-- Filtering --%>
                  <div>
                    <h4 class="text-md font-semibold mb-2 text-stone-300">Filtering</h4>
                    <div class="space-y-3">
                      <.plugin_text_input
                        label="Corporation Kill Focus"
                        name="corporation_kill_focus"
                        value={
                          comma_join(
                            config_val(
                              @parsed_configs,
                              "notifier",
                              ["settings", "corporation_kill_focus"],
                              []
                            )
                          )
                        }
                        placeholder="Comma-separated corporation EVE IDs"
                        hint="Kills involving these corps route to character kill channel"
                      />
                      <.plugin_text_input
                        label="Character Exclude List"
                        name="character_exclude_list"
                        value={
                          comma_join(
                            config_val(
                              @parsed_configs,
                              "notifier",
                              ["settings", "character_exclude_list"],
                              []
                            )
                          )
                        }
                        placeholder="Comma-separated character EVE IDs to exclude"
                      />
                      <.plugin_text_input
                        label="System Exclude List"
                        name="system_exclude_list"
                        value={
                          comma_join(
                            config_val(
                              @parsed_configs,
                              "notifier",
                              ["settings", "system_exclude_list"],
                              []
                            )
                          )
                        }
                        placeholder="Comma-separated system IDs to exclude"
                      />
                    </div>
                  </div>
                <% end %>

                <div class="flex justify-end">
                  <button
                    type="submit"
                    class="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-6 rounded"
                    disabled={@saving}
                  >
                    {if @saving, do: "Saving...", else: "Save Configuration"}
                  </button>
                </div>
              </form>
            <% end %>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end
end
