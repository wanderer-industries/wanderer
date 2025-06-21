defmodule WandererAppWeb.Legacy.CheckAclAuth do
  @moduledoc """
  A flexible authentication plug for ACL endpoints that supports both:
  1. Character JWT authentication (for listing/creating ACLs)
  2. ACL API key authentication (for accessing specific ACLs)
  """

  @deprecated "Use WandererAppWeb.Auth.AuthPipeline with strategies: [:acl_key, :character_jwt] instead. This plug will be removed after 2025-12-31."

  import Plug.Conn
  alias WandererApp.Api.{AccessList, Character}
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    header = get_req_header(conn, "authorization") |> List.first()

    case header do
      bearer_header when is_binary(bearer_header) ->
        # Make Bearer token matching case-insensitive
        case extract_bearer_token(bearer_header) do
          {:ok, token} ->
            # Try ACL API key authentication first if we have an ACL ID
            acl_id = conn.params["id"] || conn.params["acl_id"]

            if acl_id do
              case try_acl_api_key_auth(conn, acl_id, token) do
                {:ok, conn} -> conn
                {:error, _} -> try_character_auth(conn, token)
              end
            else
              # No ACL ID, try character authentication
              try_character_auth(conn, token)
            end

          {:error, _} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(401, Jason.encode!(%{error: "Invalid authorization header format"}))
            |> halt()
        end

      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "Unauthorized"}))
        |> halt()
    end
  end

  # Try to authenticate using ACL API key
  defp try_acl_api_key_auth(conn, acl_id, token) do
    case AccessList.by_id(acl_id) do
      {:ok, acl} ->
        cond do
          is_nil(acl.api_key) ->
            {:error, :no_api_key}

          Plug.Crypto.secure_compare(acl.api_key, token) ->
            {:ok, conn |> assign(:current_acl, acl)}

          true ->
            {:error, :invalid_api_key}
        end

      {:error, _} ->
        {:error, :acl_not_found}
    end
  end

  # Try to authenticate using character JWT token
  defp try_character_auth(conn, token) do
    case decode_character_token(token) do
      {:ok, character_id} ->
        case Character.by_id(character_id) do
          {:ok, character} ->
            conn |> assign(:current_character, character)

          {:error, _} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(401, Jason.encode!(%{error: "Unauthorized"}))
            |> halt()
        end

      {:error, _} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "Unauthorized"}))
        |> halt()
    end
  end

  # Extract Bearer token in a case-insensitive manner
  defp extract_bearer_token(header) do
    case Regex.run(~r/^bearer\s+(.+)$/i, header, capture: :all_but_first) do
      [token] -> {:ok, String.trim(token)}
      _ -> {:error, :invalid_format}
    end
  end

  # Decode JWT token using Guardian for proper authentication
  defp decode_character_token(token) do
    case WandererApp.Guardian.decode_and_verify(token) do
      {:ok, claims} ->
        # Extract character_id from Guardian claims
        character_id = claims["character_id"] || claims["sub"]

        if character_id do
          {:ok, character_id}
        else
          {:error, :no_character_id}
        end

      {:error, reason} ->
        Logger.debug("Failed to decode JWT token: #{inspect(reason)}")
        {:error, :decode_failed}
    end
  end
end
