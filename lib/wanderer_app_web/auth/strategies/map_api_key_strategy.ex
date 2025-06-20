defmodule WandererAppWeb.Auth.Strategies.MapApiKeyStrategy do
  @moduledoc """
  Authentication strategy for Map API keys using Bearer tokens.

  This strategy validates the Bearer token against the map's public API key.
  The map must be already resolved in conn.assigns.map.
  """

  @behaviour WandererAppWeb.Auth.AuthStrategy

  import Plug.Conn

  @impl true
  def name, do: :map_api_key

  @impl true
  def validate_opts(_opts), do: :ok

  @impl true
  def authenticate(conn, _opts) do
    with {:map, %{id: map_id} = map} <- {:map, conn.assigns[:map]},
         {:header, [auth_header]} <- {:header, get_req_header(conn, "authorization")},
         {:token, token} when not is_nil(token) <- {:token, extract_bearer_token(auth_header)},
         {:key, api_key} when not is_nil(api_key) <- {:key, map.public_api_key},
         {:valid, true} <- {:valid, Plug.Crypto.secure_compare(token, api_key)} do
      # Authentication successful
      auth_data = %{
        type: :map_api_key,
        map_id: map_id,
        map: map
      }

      conn =
        conn
        |> assign(:map_id, map_id)
        |> assign(:authenticated_by, :map_api_key)

      {:ok, conn, auth_data}
    else
      {:map, nil} ->
        # No map in assigns, this strategy doesn't apply
        :skip

      {:header, _} ->
        # No Bearer token, skip this strategy
        :skip

      {:token, nil} ->
        # Invalid bearer format, skip this strategy
        :skip

      {:key, nil} ->
        {:error, :api_key_not_configured}

      {:valid, false} ->
        {:error, :invalid_api_key}
    end
  end

  # Extract token from Authorization header (case-insensitive)
  defp extract_bearer_token(auth_header) do
    case String.split(auth_header, " ", parts: 2) do
      [scheme, token] ->
        if String.downcase(scheme) == "bearer" do
          token
        else
          nil
        end
      _ ->
        nil
    end
  end
end
