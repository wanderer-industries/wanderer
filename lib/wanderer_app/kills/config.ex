defmodule WandererApp.Kills.Config do
  @moduledoc """
  Simple configuration helpers for the kills subsystem.
  Following the pattern of other modules that use Application.get_env directly.
  """

  def enabled? do
    Application.get_env(:wanderer_app, :wanderer_kills_service_enabled, false)
  end

  def websocket_url do
    Application.get_env(:wanderer_app, :wanderer_kills_base_url, "ws://wanderer-kills:4004")
  end

  def server_url do
    # Remove /socket/websocket suffix if present for backward compatibility
    websocket_url()
    |> String.replace(~r/\/socket\/websocket$/, "")
  end

  def kill_list_limit do
    Application.get_env(:wanderer_app, :kill_list_limit, 100)
    |> to_integer()
  end

  def max_concurrent_tasks do
    :wanderer_app
    |> Application.get_env(:kills_max_concurrent_tasks, 50)
    |> ensure_integer()
  end

  def max_task_queue_size do
    :wanderer_app
    |> Application.get_env(:kills_max_task_queue_size, 5000)
    |> ensure_integer()
  end

  def killmail_ttl do
    :timer.hours(24)
  end

  def kill_count_ttl do
    :timer.hours(24)
  end

  # Simple conversion helper
  defp to_integer(value) when is_binary(value), do: String.to_integer(value)
  defp to_integer(value) when is_integer(value), do: value
  defp to_integer(_), do: 100

  defp ensure_integer(value) when is_integer(value), do: value

  defp ensure_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      # Default fallback
      _ -> 50
    end
  end

  defp ensure_integer(_), do: 50
end
