defmodule WandererApp.Kills.Config do
  @moduledoc """
  Configuration for the kills WebSocket client.
  """

  @retry_delays [30_000, 60_000, 120_000]
  @max_retries 3
  @cycle_delay :timer.minutes(15)
  @health_check_interval :timer.minutes(5)
  @cleanup_interval :timer.hours(1)
  @killmail_ttl :timer.hours(24)
  @kill_count_ttl :timer.hours(1)
  @websocket_version "2.0.0"
  @active_map_cutoff_minutes 30
  @genserver_call_timeout 5_000

  def enabled? do
    Application.get_env(:wanderer_app, :wanderer_kills_service_enabled, false)
  end

  def server_url do
    Application.get_env(:wanderer_app, :wanderer_kills_base_url, "ws://wanderer-kills:4004")
  end

  def retry_delays, do: @retry_delays
  def max_retries, do: @max_retries
  def cycle_delay, do: @cycle_delay
  def health_check_interval, do: @health_check_interval
  def cleanup_interval, do: @cleanup_interval
  def killmail_ttl, do: @killmail_ttl
  def kill_count_ttl, do: @kill_count_ttl
  def websocket_version, do: @websocket_version
  def active_map_cutoff_minutes, do: @active_map_cutoff_minutes
  def genserver_call_timeout, do: @genserver_call_timeout

  def kill_list_limit do
    Application.get_env(:wanderer_app, :kill_list_limit, 100)
  end

  def client_identifier do
    case URI.parse(WandererApp.Env.base_url()) do
      %URI{host: host} when not is_nil(host) -> host
      _ -> "wanderer_app"
    end
  end
end
