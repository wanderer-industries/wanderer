defmodule WandererApp.Test.AuthHelpers do
  @moduledoc """
  Authentication helpers for tests.

  Provides functions to generate proper JWT tokens for testing authenticated endpoints.
  Uses real Guardian JWT implementation for authentic token generation.
  """

  alias WandererApp.Guardian

  @doc """
  Generates a real JWT token for a user using Guardian.

  This creates a proper JWT token that matches production authentication flow.
  """
  def generate_jwt_token(user) do
    case Guardian.generate_user_token(user) do
      {:ok, token, _claims} ->
        token

      {:error, reason} ->
        raise "Failed to generate JWT token for user #{user.id}: #{inspect(reason)}"
    end
  end

  @doc """
  Generates a real JWT token for a character using Guardian.

  This creates a proper JWT token that matches production authentication flow.
  """
  def generate_character_token(character) do
    case Guardian.generate_character_token(character) do
      {:ok, token, _claims} ->
        token

      {:error, reason} ->
        raise "Failed to generate JWT token for character #{character.id}: #{inspect(reason)}"
    end
  end

  @doc """
  Decodes a JWT token using Guardian (for debugging and validation).
  """
  def decode_jwt_token(token) do
    case Guardian.decode_and_verify(token) do
      {:ok, claims} -> {:ok, claims}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Validates that a JWT token is properly formatted and signed.
  """
  def validate_jwt_token(token) do
    Guardian.validate_token(token)
  end

  @doc """
  Generates a map API key header for testing.

  ## Examples

      # Using a map with existing API key
      auth_header = generate_map_api_key_header(map)
      conn |> put_req_header("authorization", auth_header)
      
      # Using a custom API key
      auth_header = generate_map_api_key_header("custom-api-key-123")
      conn |> put_req_header("authorization", auth_header)
  """
  def generate_map_api_key_header(map_or_key) do
    api_key =
      case map_or_key do
        %{public_api_key: key} when not is_nil(key) -> key
        key when is_binary(key) -> key
        _ -> raise ArgumentError, "Invalid map or API key provided"
      end

    "Bearer #{api_key}"
  end

  @doc """
  Generates an ACL API key header for testing.

  ## Examples

      # Using an ACL with existing API key
      auth_header = generate_acl_api_key_header(acl)
      conn |> put_req_header("authorization", auth_header)
      
      # Using a custom API key
      auth_header = generate_acl_api_key_header("custom-acl-key-123")
      conn |> put_req_header("authorization", auth_header)
  """
  def generate_acl_api_key_header(acl_or_key) do
    api_key =
      case acl_or_key do
        %{api_key: key} when not is_nil(key) -> key
        key when is_binary(key) -> key
        _ -> raise ArgumentError, "Invalid ACL or API key provided"
      end

    "Bearer #{api_key}"
  end

  @doc """
  Generates a JWT authentication header for a user.

  ## Examples

      auth_header = generate_jwt_header(user)
      conn |> put_req_header("authorization", auth_header)
  """
  def generate_jwt_header(user) do
    token = generate_jwt_token(user)
    "Bearer #{token}"
  end

  @doc """
  Generates a JWT authentication header for a character.

  ## Examples

      auth_header = generate_character_jwt_header(character)
      conn |> put_req_header("authorization", auth_header)
  """
  def generate_character_jwt_header(character) do
    token = generate_character_token(character)
    "Bearer #{token}"
  end

  @doc """
  Sets up authentication headers on a connection based on the strategy.

  ## Examples

      # JWT authentication for a user
      conn = setup_auth(conn, :jwt, user)
      
      # Map API key authentication
      conn = setup_auth(conn, :map_api_key, map)
      
      # ACL API key authentication
      conn = setup_auth(conn, :acl_key, acl)
      
      # Character JWT authentication
      conn = setup_auth(conn, :character_jwt, character)
  """
  def setup_auth(conn, strategy, resource) do
    auth_header =
      case strategy do
        :jwt -> generate_jwt_header(resource)
        :character_jwt -> generate_character_jwt_header(resource)
        :map_api_key -> generate_map_api_key_header(resource)
        :acl_key -> generate_acl_api_key_header(resource)
        _ -> raise ArgumentError, "Unknown authentication strategy: #{inspect(strategy)}"
      end

    Plug.Conn.put_req_header(conn, "authorization", auth_header)
  end

  @doc """
  Creates a map with a valid API key for testing.

  Returns a map struct with public_api_key set.
  """
  def create_map_with_api_key(attrs \\ %{}) do
    api_key = "test-map-api-key-#{System.unique_integer([:positive])}"

    # Merge provided attrs with generated API key
    map_attrs = Map.merge(%{public_api_key: api_key}, attrs)

    # Use factory to create the map
    WandererApp.Factory.create(:map, map_attrs)
  end

  @doc """
  Creates an ACL with a valid API key for testing.

  Returns an ACL struct with api_key set.
  """
  def create_acl_with_api_key(attrs \\ %{}) do
    api_key = "test-acl-api-key-#{System.unique_integer([:positive])}"

    # Merge provided attrs with generated API key
    acl_attrs = Map.merge(%{api_key: api_key}, attrs)

    # Use factory to create the ACL
    WandererApp.Factory.create(:access_list, acl_attrs)
  end

  @doc """
  Tests authentication failure scenarios for a given strategy.

  ## Examples

      test_auth_failure(conn, :jwt, "invalid-token", :invalid_token)
      test_auth_failure(conn, :map_api_key, "wrong-key", :unauthorized)
  """
  def test_auth_failure(conn, strategy, invalid_credential, expected_error) do
    conn_with_auth =
      case strategy do
        :jwt ->
          Plug.Conn.put_req_header(conn, "authorization", "Bearer #{invalid_credential}")

        :character_jwt ->
          Plug.Conn.put_req_header(conn, "authorization", "Bearer #{invalid_credential}")

        :map_api_key ->
          Plug.Conn.put_req_header(conn, "authorization", "Bearer #{invalid_credential}")

        :acl_key ->
          Plug.Conn.put_req_header(conn, "authorization", "Bearer #{invalid_credential}")

        _ ->
          raise ArgumentError, "Unknown authentication strategy: #{inspect(strategy)}"
      end

    {conn_with_auth, expected_error}
  end
end
