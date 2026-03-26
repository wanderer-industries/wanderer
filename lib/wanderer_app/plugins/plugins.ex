defmodule WandererApp.Plugins do
  @moduledoc """
  Server-wide plugin configuration. Reads from application environment
  (set via environment variables in runtime.exs).

  Provides helper functions for accessing plugin-level settings such as API keys.
  """

  @spec get_api_key(String.t()) :: {:ok, String.t()} | {:error, :no_api_key}
  def get_api_key(plugin_name) do
    keys =
      Application.get_env(:wanderer_app, :plugins, [])
      |> Keyword.get(:api_keys, %{})

    case Map.get(keys, plugin_name) do
      nil -> {:error, :no_api_key}
      "" -> {:error, :no_api_key}
      key when is_binary(key) -> {:ok, key}
      _ -> {:error, :no_api_key}
    end
  end
end
