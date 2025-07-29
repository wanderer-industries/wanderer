defmodule WandererApp.Ueberauth.Strategy.Eve.OAuth do
  @moduledoc """
  OAuth2 for Eve.

  Add `client_id` and `client_secret` to your configuration:

      config :wanderer_app, WandererApp.Ueberauth.Strategy.Eve.OAuth,
        client_id: System.get_env("EVE_APP_ID"),
        client_secret: System.get_env("EVE_APP_SECRET")

  """
  use OAuth2.Strategy

  @defaults [
    strategy: __MODULE__,
    site: "https://login.eveonline.com",
    authorize_url: "/v2/oauth/authorize/",
    token_url: "https://login.eveonline.com/v2/oauth/token"
  ]

  @doc """
  Construct a client for requests to Eve.

  This will be setup automatically for you in `Ueberauth.Strategy.Eve`.

  These options are only useful for usage outside the normal callback phase of Ueberauth.
  """
  def client(opts \\ []) do
    config = Application.get_env(:ueberauth, __MODULE__, [])

    json_library = Ueberauth.json_library()

    @defaults
    |> Keyword.merge(config)
    |> Keyword.merge(opts)
    |> resolve_values()
    |> generate_client_id()
    |> generate_client_secret()
    |> OAuth2.Client.new()
    |> OAuth2.Client.put_serializer("application/json", json_library)
  end

  @doc """
  Provides the authorize url for the request phase of Ueberauth. No need to call this usually.
  """
  def authorize_url!(params \\ [], opts \\ []) do
    opts
    |> Keyword.put(:redirect_uri, "#{WandererApp.Env.base_url()}/auth/eve/callback")
    |> client
    |> OAuth2.Client.authorize_url!(params)
  end

  def get(token, url, headers \\ [], opts \\ []) do
    [token: token]
    |> Keyword.put(:redirect_uri, "#{WandererApp.Env.base_url()}/auth/eve/callback")
    |> client
    |> put_param("response_type", "code")
    |> put_param("client_id", client().client_id)
    |> put_param("state", "ccp_auth_response")
    |> OAuth2.Client.get(url, headers, opts)
  end

  def get_access_token(params \\ [], opts \\ []) do
    case opts
         |> client
         |> OAuth2.Client.get_token(params ++ [grant_type: "authorization_code"], []) do
      {:ok, %OAuth2.Client{token: token}} ->
        case Map.get(token, :access_token) do
          nil ->
            %{"error" => error, "error_description" => description} = token.other_params
            {:error, {error, description}}

          _ ->
            {:ok, token}
        end

      {:error, %OAuth2.Response{body: %{"error" => error}} = response} ->
        description = Map.get(response.body, "error_description", "")
        {:error, {error, description}}

      {:error, %OAuth2.Error{reason: reason}} ->
        {:error, {"error", to_string(reason)}}
    end
  end

  def get_refresh_token(params \\ [], opts \\ []) do
    case opts
         |> client
         |> refresh_token(params) do
      {:ok, %OAuth2.Client{token: token} = _response} ->
        case Map.get(token, :access_token) do
          nil ->
            %{"error" => error, "error_description" => description} = token.other_params
            {:error, {error, description}}

          _ ->
            {:ok, token}
        end

      {:error, %OAuth2.Response{body: %{"error" => error}} = response} ->
        description = Map.get(response.body, "error_description", "")
        {:error, {error, description}}

      {:error, %OAuth2.Response{body: body}} ->
        {:error, to_string(body)}

      {:error, error} ->
        {:error, error}
    end
  end

  # Strategy Callbacks

  def authorize_url(client, params) do
    OAuth2.Strategy.AuthCode.authorize_url(client, params)
  end

  def get_token(client, params, headers) do
    client
    |> put_header("Accept", "application/x-www-form-urlencoded")
    |> put_header("Host", "login.eveonline.com")
    |> merge_params(params)
    |> basic_auth()
    |> put_headers(headers)
  end

  defp resolve_values(list) do
    for {key, value} <- list do
      {key, resolve_value(value)}
    end
  end

  defp resolve_value({m, f, a}) when is_atom(m) and is_atom(f), do: apply(m, f, a)
  defp resolve_value(v), do: v

  defp generate_client_secret(opts) do
    if is_tuple(opts[:client_secret]) do
      {module, fun} = opts[:client_secret]
      secret = apply(module, fun, [opts])
      Keyword.put(opts, :client_secret, secret)
    else
      opts
    end
  end

  defp generate_client_id(opts) do
    if is_tuple(opts[:client_id]) do
      {module, fun} = opts[:client_id]
      secret = apply(module, fun, [opts])
      Keyword.put(opts, :client_id, secret)
    else
      opts
    end
  end
end
