defmodule WandererApp.Env do
  @moduledoc false

  @app :wanderer_app

  def vsn(), do: Application.spec(@app)[:vsn]
  def git_sha(), do: get_key(:git_sha, "<GIT_SHA>")
  def base_url, do: get_key(:web_app_url, "<BASE_URL>")
  def custom_route_base_url, do: get_key(:custom_route_base_url, "<CUSTOM_ROUTE_BASE_URL>")
  def invites, do: get_key(:invites, false)
  def map_subscriptions_enabled?, do: get_key(:map_subscriptions_enabled, false)
  def wallet_tracking_enabled?, do: get_key(:wallet_tracking_enabled, false)
  def admins, do: get_key(:admins, [])
  def admin_username, do: get_key(:admin_username)
  def admin_password, do: get_key(:admin_password)
  def corp_wallet, do: get_key(:corp_wallet, "")
  def corp_eve_id, do: get_key(:corp_id, -1)
  def subscription_settings, do: get_key(:subscription_settings)
  def get_key(key, default \\ nil), do: Application.get_env(@app, key, default)
end
