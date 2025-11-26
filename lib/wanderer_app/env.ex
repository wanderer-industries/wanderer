defmodule WandererApp.Env do
  @moduledoc false
  use Nebulex.Caching

  @app :wanderer_app

  @decorate cacheable(
              cache: WandererApp.Cache,
              key: "vsn_version"
            )
  def vsn(), do: Application.spec(@app)[:vsn]

  def git_sha(), do: get_key(:git_sha, "<GIT_SHA>")
  def base_url(), do: get_key(:web_app_url, "<BASE_URL>")
  def base_metrics_only(), do: get_key(:base_metrics_only, false)
  def custom_route_base_url(), do: get_key(:custom_route_base_url, "<CUSTOM_ROUTE_BASE_URL>")
  def invites(), do: get_key(:invites, false)

  def map_subscriptions_enabled?(), do: get_key(:map_subscriptions_enabled, false)
  def websocket_events_enabled?(), do: get_key(:websocket_events_enabled, false)
  def public_api_disabled?(), do: get_key(:public_api_disabled, false)

  @decorate cacheable(
              cache: WandererApp.Cache,
              key: "active_tracking_pool"
            )
  def active_tracking_pool(), do: get_key(:active_tracking_pool, "default")

  @decorate cacheable(
              cache: WandererApp.Cache,
              key: "tracking_pool_max_size"
            )
  def tracking_pool_max_size(), do: get_key(:tracking_pool_max_size, 300)
  def character_tracking_pause_disabled?(), do: get_key(:character_tracking_pause_disabled, true)
  def character_api_disabled?(), do: get_key(:character_api_disabled, false)
  def wanderer_kills_service_enabled?(), do: get_key(:wanderer_kills_service_enabled, false)
  def wallet_tracking_enabled?(), do: get_key(:wallet_tracking_enabled, false)
  def admins(), do: get_key(:admins, [])
  def admin_username(), do: get_key(:admin_username)
  def admin_password(), do: get_key(:admin_password)
  def corp_wallet(), do: get_key(:corp_wallet, "")
  def corp_wallet_eve_id(), do: get_key(:corp_wallet_eve_id, "-1")
  def corp_eve_id(), do: get_key(:corp_id, -1)
  def subscription_settings(), do: get_key(:subscription_settings)

  @decorate cacheable(
              cache: WandererApp.Cache,
              key: "restrict_maps_creation"
            )
  def restrict_maps_creation?(), do: get_key(:restrict_maps_creation, false)

  @decorate cacheable(
              cache: WandererApp.Cache,
              key: "restrict_acls_creation"
            )
  def restrict_acls_creation?(), do: get_key(:restrict_acls_creation, false)

  def sse_enabled?() do
    Application.get_env(@app, :sse, [])
    |> Keyword.get(:enabled, false)
  end

  def webhooks_enabled?() do
    Application.get_env(@app, :external_events, [])
    |> Keyword.get(:webhooks_enabled, false)
  end

  @decorate cacheable(
              cache: WandererApp.Cache,
              key: "map-connection-auto-expire-hours"
            )
  def map_connection_auto_expire_hours(), do: get_key(:map_connection_auto_expire_hours)

  @decorate cacheable(
              cache: WandererApp.Cache,
              key: "map-connection-auto-eol-hours"
            )
  def map_connection_auto_eol_hours(), do: get_key(:map_connection_auto_eol_hours)

  @decorate cacheable(
              cache: WandererApp.Cache,
              key: "map-connection-eol-expire-timeout-mins"
            )
  def map_connection_eol_expire_timeout_mins(),
    do: get_key(:map_connection_eol_expire_timeout_mins)

  def get_key(key, default \\ nil), do: Application.get_env(@app, key, default)

  @doc """
  A single map containing environment variables
  made available to react
  """
  def to_client_env() do
    %{detailedKillsDisabled: not wanderer_kills_service_enabled?()}
  end
end
