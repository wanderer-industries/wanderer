defmodule WandererApp.Ueberauth.Strategy.Eve do
  @moduledoc """
  Eve Strategy for Überauth.
  """

  use Ueberauth.Strategy,
    uid_field: "CharacterId",
    default_scope: "email",
    hd: nil,
    userinfo_endpoint: "https://login.eveonline.com/oauth/verify"

  alias Ueberauth.Auth.Credentials
  alias Ueberauth.Auth.Extra

  @doc """
  Handles initial request for Eve authentication.
  """
  def handle_request!(%{params: params} = conn) do
    with_wallet = Map.get(params, "w", "false") in ~w(true 1)
    is_admin? = Map.get(params, "admin", "false") in ~w(true 1)
    invite_token = Map.get(params, "invite", nil)

    {invite_token_valid, invite_type} = check_invite_valid(invite_token)

    is_admin? = is_admin? || invite_type == :admin

    case invite_token_valid do
      true ->
        scopes =
          cond do
            is_admin? -> option(conn, :admin_scope) || params["scope"]
            with_wallet -> option(conn, :wallet_scope) || params["scope"]
            true -> option(conn, :default_scope) || params["scope"]
          end

        params =
          [scope: scopes]
          |> with_optional(:hd, conn)
          |> with_optional(:prompt, conn)
          |> with_optional(:access_type, conn)
          |> with_optional(:login_hint, conn)
          |> with_optional(:include_granted_scopes, conn)
          |> with_param(:access_type, conn)
          |> with_param(:prompt, conn)
          |> with_param(:login_hint, conn)
          |> with_param(:hl, conn)
          |> with_state_param(conn)

        WandererApp.Cache.put(
          "eve_auth_#{params[:state]}",
          [with_wallet: with_wallet, is_admin?: is_admin?],
          ttl: :timer.minutes(15)
        )

        opts = oauth_client_options_from_conn(conn, with_wallet, is_admin?)

        redirect!(conn, WandererApp.Ueberauth.Strategy.Eve.OAuth.authorize_url!(params, opts))

      false ->
        conn
        |> redirect!("/welcome")
    end
  end

  @doc """
  Handles the callback from Eve.
  """
  def handle_callback!(%Plug.Conn{params: %{"code" => code, "state" => state}} = conn) do
    opts =
      WandererApp.Cache.get("eve_auth_#{state}")

    params = [code: code]

    case WandererApp.Ueberauth.Strategy.Eve.OAuth.get_access_token(params, opts) do
      {:ok, token} ->
        fetch_user(conn, token)

      {:error, {error_code, error_description}} ->
        set_errors!(conn, [error(error_code, error_description)])
    end
  end

  @doc false
  def handle_callback!(conn) do
    set_errors!(conn, [error("missing_code", "No code received")])
  end

  @doc false
  def handle_cleanup!(conn) do
    conn
    |> put_private(:eve_user, nil)
    |> put_private(:eve_token, nil)
  end

  @doc """
  Fetches the uid field from the response.
  """
  def uid(conn) do
    uid_field =
      conn
      |> option(:uid_field)
      |> to_string

    conn.private.eve_user[uid_field]
  end

  @doc """
  Includes the credentials from the eve response.
  """
  def credentials(conn) do
    token = conn.private.eve_token
    user = conn.private.eve_user

    %Credentials{
      expires: !!token.expires_at,
      expires_at: token.expires_at,
      scopes: user["Scopes"] || "",
      token_type: Map.get(token, :token_type),
      refresh_token: token.refresh_token,
      token: token.access_token
    }
  end

  @doc """
  Fetches the fields to populate the info section of the `Ueberauth.Auth` struct.
  """
  def info(
        %{
          private: %{
            eve_user: %{"CharacterID" => character_id, "CharacterName" => character_name}
          }
        } = _conn
      )
      when is_integer(character_id) and is_binary(character_name) do
    %Ueberauth.Auth.Info{
      email: "#{character_id}",
      name: character_name,
      urls: %{profile: "https://login.eveonline.com/Character/#{character_id}"}
    }
  end

  @doc """
  Stores the raw information (including the token) obtained from the google callback.
  """
  def extra(conn) do
    %Extra{
      raw_info: %{
        token: conn.private.eve_token,
        user: conn.private.eve_user
      }
    }
  end

  defp fetch_user(conn, token) do
    conn = put_private(conn, :eve_token, token)

    case WandererApp.Ueberauth.Strategy.Eve.OAuth.get(token, get_userinfo_endpoint(conn)) do
      {:ok, %OAuth2.Response{status_code: 401, body: body}} ->
        set_errors!(conn, [error("token", "unauthorized" <> body)])

      {:ok, %OAuth2.Response{status_code: status_code, body: user}}
      when status_code in 200..399 ->
        put_private(conn, :eve_user, user)

      {:error, %OAuth2.Response{status_code: status_code}} ->
        set_errors!(conn, [error("OAuth2", "#{status_code}")])

      {:error, %OAuth2.Error{reason: reason}} ->
        set_errors!(conn, [error("OAuth2", reason)])
    end
  end

  defp get_userinfo_endpoint(conn) do
    case option(conn, :userinfo_endpoint) do
      {:system, varname, default} ->
        System.get_env(varname) || default

      {:system, varname} ->
        System.get_env(varname) || Keyword.get(default_options(), :userinfo_endpoint)

      other ->
        other
    end
  end

  defp with_param(opts, key, conn) do
    if value = conn.params[to_string(key)], do: Keyword.put(opts, key, value), else: opts
  end

  defp with_optional(opts, key, conn) do
    if option(conn, key), do: Keyword.put(opts, key, option(conn, key)), else: opts
  end

  defp oauth_client_options_from_conn(conn, with_wallet, is_admin?) do
    tracking_pool = WandererApp.Character.TrackingConfigUtils.get_active_pool!()

    base_options = [
      redirect_uri: "#{WandererApp.Env.base_url()}/auth/eve/callback",
      with_wallet: with_wallet,
      is_admin?: is_admin?,
      tracking_pool: tracking_pool
    ]

    request_options = conn.private[:ueberauth_request_options].options

    case {request_options[:client_id], request_options[:client_secret]} do
      {nil, _} -> base_options
      {_, nil} -> base_options
      {id, secret} -> [client_id: id, client_secret: secret] ++ base_options
    end
  end

  defp option(conn, key) do
    Keyword.get(options(conn), key, Keyword.get(default_options(), key))
  end

  defp check_invite_valid(invite_token) do
    case invite_token do
      token when not is_nil(token) and token != "" ->
        check_token_valid(token)

      _ ->
        {not WandererApp.Env.invites(), :user}
    end
  end

  defp check_token_valid(token) do
    WandererApp.Cache.lookup!("invite_#{token}", false)
    |> case do
      true -> {true, :user}
      _ -> check_map_token_valid(token)
    end
  end

  def check_map_token_valid(token) do
    {:ok, invites} = WandererApp.Api.MapInvite.read()

    invites
    |> Enum.find(fn invite -> invite.token == token end)
    |> case do
      nil -> {false, nil}
      invite -> {true, invite.type}
    end
  end
end
