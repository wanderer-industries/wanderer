defmodule WandererAppWeb.Api.EveAuthController do
  @moduledoc """
  Exchanges an EVE SSO access token for a short-lived, map-scoped API token.

  Endpoint:
    - POST /api/maps/:map_identifier/auth/eve-token
      body: {"eve_token": "<EVE SSO access token>"}

  This is additive: the static `public_api_key` (see
  `WandererAppWeb.Plugs.CheckMapApiKey`) keeps working unchanged. See
  `WandererApp.Map.EveTokenAuth` for the underlying identity/ACL check.
  """

  use WandererAppWeb, :controller

  alias WandererApp.Map.EveTokenAuth
  alias WandererAppWeb.Helpers.APIUtils
  require Logger

  def create(conn, %{"map_identifier" => map_identifier} = params) do
    with {:ok, eve_token} <- APIUtils.require_param(params, "eve_token"),
         {:ok, result} <- EveTokenAuth.exchange(map_identifier, eve_token) do
      APIUtils.respond_data(conn, result)
    else
      {:error, msg} when is_binary(msg) ->
        APIUtils.error_response(conn, :bad_request, msg)

      {:error, :map_not_found} ->
        APIUtils.error_not_found(conn, "Map not found for identifier: #{map_identifier}")

      {:error, :invalid_token} ->
        APIUtils.error_response(conn, :unauthorized, "Invalid or expired EVE SSO token")

      {:error, :verify_failed} ->
        APIUtils.error_response(conn, :bad_gateway, "Could not verify token with EVE SSO")

      {:error, :character_not_tracked} ->
        APIUtils.error_response(
          conn,
          :unprocessable_entity,
          "Character has never logged into Wanderer - log in once via EVE SSO before requesting a map token"
        )

      {:error, :forbidden} ->
        APIUtils.error_response(conn, :forbidden, "Character has no access to this map")

      {:error, other} ->
        Logger.error("EVE_TOKEN_EXCHANGE_UNEXPECTED_ERROR: #{inspect(other)}")
        APIUtils.error_response(conn, :internal_server_error, "Unexpected error")
    end
  end
end
