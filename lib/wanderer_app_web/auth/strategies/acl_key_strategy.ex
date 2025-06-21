defmodule WandererAppWeb.Auth.Strategies.AclKeyStrategy do
  @moduledoc """
  Authentication strategy for ACL API keys.

  This strategy validates API keys for Access Control Lists, allowing
  programmatic access to ACL-protected resources.
  """

  @behaviour WandererAppWeb.Auth.AuthStrategy

  import Plug.Conn
  alias WandererApp.Api.AccessList

  @impl true
  def name, do: :acl_key

  @impl true
  def validate_opts(_opts), do: :ok

  @impl true
  def authenticate(conn, opts) do
    # Try to get ACL ID from various sources
    # Routes use both :id (for show/update/delete) and :acl_id (for members)
    acl_id = opts[:acl_id] || conn.params["id"] || conn.params["acl_id"] || conn.assigns[:acl_id]

    with {:acl_id, acl_id} when not is_nil(acl_id) <- {:acl_id, acl_id},
         {:header, [auth_header]} <- {:header, get_req_header(conn, "authorization")},
         {:token, token} when not is_nil(token) <- {:token, extract_bearer_token(auth_header)},
         {:acl, {:ok, acl}} <- {:acl, AccessList.by_id(acl_id)},
         {:key, api_key} when not is_nil(api_key) <- {:key, acl.api_key},
         {:valid, true} <- {:valid, Plug.Crypto.secure_compare(token, api_key)} do
      # Authentication successful
      auth_data = %{
        type: :acl_key,
        acl: acl,
        acl_id: acl.id
      }

      conn =
        conn
        |> assign(:current_acl, acl)
        |> assign(:authenticated_by, :acl_key)

      {:ok, conn, auth_data}
    else
      {:acl_id, nil} ->
        # No ACL ID available, skip this strategy
        :skip

      {:header, _} ->
        # No Bearer token, skip this strategy
        :skip

      {:acl, {:error, _}} ->
        {:error, :acl_not_found}

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
