defmodule WandererAppWeb.Auth.Strategies.JwtStrategy do
  @moduledoc """
  Authentication strategy for JWT tokens.

  This strategy validates JWT tokens issued by Guardian for user authentication.
  """

  @behaviour WandererAppWeb.Auth.AuthStrategy

  import Plug.Conn
  alias WandererApp.Guardian
  alias WandererApp.Api.User

  @impl true
  def name, do: :jwt

  @impl true
  def validate_opts(_opts), do: :ok

  @impl true
  def authenticate(conn, _opts) do
    with {:header, [auth_header]} <- {:header, get_req_header(conn, "authorization")},
         {:token, token} <- {:token, extract_bearer_token(auth_header)},
         {:decode, {:ok, claims}} <- {:decode, Guardian.decode_and_verify(token)},
         {:user, {:ok, user}} <- {:user, load_user(claims)} do
      # Authentication successful
      auth_data = %{
        type: :jwt,
        user: user,
        claims: claims
      }

      conn =
        conn
        |> assign(:current_user, user)
        |> assign(:authenticated_by, :jwt)

      {:ok, conn, auth_data}
    else
      {:header, _} ->
        # No Bearer token, skip this strategy
        :skip

      {:decode, {:error, reason}} ->
        {:error, {:invalid_token, reason}}

      {:user, {:error, reason}} ->
        {:error, {:user_not_found, reason}}
    end
  end

  defp load_user(%{"sub" => user_id}) do
    case User.by_id(user_id) do
      {:ok, user} ->
        # Load characters for use in authorization policies
        user_with_characters = Ash.load!(user, :characters)
        {:ok, user_with_characters}

      _ ->
        {:error, :not_found}
    end
  end

  defp load_user(_), do: {:error, :invalid_claims}

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
