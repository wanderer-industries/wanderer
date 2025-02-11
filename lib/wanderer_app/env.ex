defmodule WandererApp.Env do
  @moduledoc false
  use Nebulex.Caching

  @app :wanderer_app

  def vsn(), do: Application.spec(@app)[:vsn]
  def git_sha(), do: get_key(:git_sha, "<GIT_SHA>")
  def base_url, do: get_key(:web_app_url, "<BASE_URL>")
  def custom_route_base_url, do: get_key(:custom_route_base_url, "<CUSTOM_ROUTE_BASE_URL>")
  def invites, do: get_key(:invites, false)
  def map_subscriptions_enabled?, do: get_key(:map_subscriptions_enabled, false)
  def public_api_disabled?, do: get_key(:public_api_disabled, false)
  def zkill_preload_disabled?, do: get_key(:zkill_preload_disabled, false)
  def wallet_tracking_enabled?, do: get_key(:wallet_tracking_enabled, false)
  def admins, do: get_key(:admins, [])
  def admin_username, do: get_key(:admin_username)
  def admin_password, do: get_key(:admin_password)
  def corp_wallet, do: get_key(:corp_wallet, "")
  def corp_eve_id, do: get_key(:corp_id, -1)
  def subscription_settings, do: get_key(:subscription_settings)

  @decorate cacheable(
              cache: WandererApp.Cache,
              key: "restrict_maps_creation"
            )
  def restrict_maps_creation?, do: get_key(:restrict_maps_creation, false)

  @decorate cacheable(
              cache: WandererApp.Cache,
              key: "map-connection-auto-expire-hours"
            )
  def map_connection_auto_expire_hours, do: get_key(:map_connection_auto_expire_hours)

  @decorate cacheable(
              cache: WandererApp.Cache,
              key: "map-connection-auto-eol-hours"
            )
  def map_connection_auto_eol_hours, do: get_key(:map_connection_auto_eol_hours)

  @decorate cacheable(
              cache: WandererApp.Cache,
              key: "map-connection-eol-expire-timeout-mins"
            )
  def map_connection_eol_expire_timeout_mins,
    do: get_key(:map_connection_eol_expire_timeout_mins)

  def get_key(key, default \\ nil), do: Application.get_env(@app, key, default)

  @doc """
  A single map containing environment variables
  made available to react
  """
  def to_client_env do
    %{detailedKillsDisabled: zkill_preload_disabled?()}
  end
end
