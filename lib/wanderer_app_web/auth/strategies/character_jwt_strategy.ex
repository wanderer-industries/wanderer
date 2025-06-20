defmodule WandererAppWeb.Auth.Strategies.CharacterJwtStrategy do
  @moduledoc """
  Authentication strategy for character-specific JWT tokens.

  This strategy validates JWT tokens that include character information,
  typically used for ACL-based authentication where a specific character
  needs to be authenticated.
  """

  @behaviour WandererAppWeb.Auth.AuthStrategy

  import Plug.Conn
  alias WandererApp.Guardian
  alias WandererApp.Api.Character

  @impl true
  def name, do: :character_jwt

  @impl true
  def validate_opts(_opts), do: :ok

  @impl true
  def authenticate(conn, opts) do
    with {:header, [auth_header]} <- {:header, get_req_header(conn, "authorization")},
         {:token, token} when not is_nil(token) <- {:token, extract_bearer_token(auth_header)},
         {:decode, {:ok, claims}} <- {:decode, Guardian.decode_and_verify(token)},
         {:character_id, {:ok, character_id}} <-
           {:character_id, extract_character_id(claims, conn, opts)},
         {:character, {:ok, character}} <- {:character, load_character(character_id)} do
      # Authentication successful
      auth_data = %{
        type: :character_jwt,
        character: character,
        claims: claims
      }

      conn =
        conn
        |> assign(:current_character, character)
        |> assign(:authenticated_by, :character_jwt)

      {:ok, conn, auth_data}
    else
      {:header, _} ->
        # No Bearer token, skip this strategy
        :skip

      {:token, nil} ->
        # Invalid bearer format, skip this strategy
        :skip

      {:decode, {:error, reason}} ->
        {:error, {:invalid_token, reason}}

      {:character_id, :skip} ->
        :skip

      {:character_id, {:error, reason}} ->
        {:error, {:invalid_character_id, reason}}

      {:character, {:error, reason}} ->
        {:error, {:character_not_found, reason}}
    end
  end

  defp extract_character_id(claims, conn, opts) do
    # Priority order:
    # 1. Explicit character_id in opts
    # 2. character_id in conn.params
    # 3. character_id claim in JWT
    # 4. Extract from sub claim if it's in format "character:uuid"

    cond do
      opts[:character_id] ->
        {:ok, opts[:character_id]}

      conn.params["character_id"] ->
        {:ok, conn.params["character_id"]}

      claims["character_id"] ->
        {:ok, claims["character_id"]}

      claims["sub"] ->
        case claims["sub"] do
          "character:" <> character_id -> {:ok, character_id}
          _ -> {:error, :no_character_id_in_token}
        end

      true ->
        :skip
    end
  end

  defp load_character(character_id) do
    case Character.by_id(character_id) do
      {:ok, character} -> {:ok, character}
      _ -> {:error, :not_found}
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
