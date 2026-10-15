defmodule WandererApp.EveSso do
  @moduledoc """
  Minimal client for validating EVE SSO access tokens against the
  `/oauth/verify` endpoint.

  Used by `WandererApp.Map.EveTokenAuth` to authenticate API callers by their
  EVE identity instead of a static, shared map API key. Unlike
  `WandererApp.Ueberauth.Strategy.Eve.OAuth` (used for the web login flow),
  this does not need Wanderer's own EVE application credentials - `/oauth/verify`
  only requires the caller's bearer token.

  Swappable via `config :wanderer_app, :eve_sso, SomeModule` (see `config/test.exs`),
  following the same pattern used for `:logger` in `WandererApp.Esi.ApiClient`.
  """

  require Logger

  @callback verify_token(String.t()) ::
              {:ok, %{character_id: integer(), character_name: String.t(), scopes: String.t()}}
              | {:error, :invalid_token | :verify_failed}

  @verify_url "https://login.eveonline.com/oauth/verify"
  @wanderrer_user_agent "(wanderer-industries@proton.me; +https://github.com/wanderer-industries/wanderer)"

  @doc """
  Verifies an EVE SSO access token and returns the character it belongs to.
  """
  @spec verify_token(String.t()) ::
          {:ok, %{character_id: integer(), character_name: String.t(), scopes: String.t()}}
          | {:error, :invalid_token | :verify_failed}
  def verify_token(access_token) when is_binary(access_token) do
    @verify_url
    |> Req.get(
      auth: {:bearer, access_token},
      headers: [{:user_agent, "Wanderer/#{WandererApp.Env.vsn()} #{@wanderrer_user_agent}"}],
      retry: false
    )
    |> case do
      {:ok,
       %{
         status: 200,
         body: %{"CharacterID" => character_id, "CharacterName" => character_name} = body
       }} ->
        {:ok,
         %{
           character_id: character_id,
           character_name: character_name,
           scopes: body["Scopes"] || ""
         }}

      {:ok, %{status: status}} when status in [401, 403] ->
        {:error, :invalid_token}

      {:ok, %{status: status}} ->
        Logger.warning("EVE_SSO_VERIFY_UNEXPECTED_STATUS", status: status)
        {:error, :verify_failed}

      {:error, reason} ->
        Logger.warning("EVE_SSO_VERIFY_REQUEST_FAILED", reason: inspect(reason))
        {:error, :verify_failed}
    end
  end
end
