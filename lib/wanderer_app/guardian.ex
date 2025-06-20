defmodule WandererApp.Guardian do
  @moduledoc """
  Guardian implementation for JWT token management in Wanderer.

  This module handles encoding, decoding, and verification of JWT tokens
  for user and character authentication.
  """

  use Guardian, otp_app: :wanderer_app

  alias WandererApp.Api.{User, Character}

  @impl Guardian
  def subject_for_token(%User{id: id}, _claims) do
    {:ok, "user:#{id}"}
  end

  def subject_for_token(%Character{id: id}, _claims) do
    {:ok, "character:#{id}"}
  end

  def subject_for_token(_, _) do
    {:error, :unhandled_resource_type}
  end

  @impl Guardian
  def resource_from_claims(%{"sub" => "user:" <> id}) do
    case User.by_id(id) do
      {:ok, user} -> {:ok, user}
      _ -> {:error, :user_not_found}
    end
  end

  def resource_from_claims(%{"sub" => "character:" <> id}) do
    case Character.by_id(id) do
      {:ok, character} -> {:ok, character}
      _ -> {:error, :character_not_found}
    end
  end

  def resource_from_claims(_claims) do
    {:error, :invalid_subject}
  end

  @doc """
  Generate a JWT token for a user.
  """
  def generate_user_token(user, claims \\ %{}) do
    default_claims = %{
      "name" => user.name
    }

    encode_and_sign(user, Map.merge(default_claims, claims))
  end

  @doc """
  Generate a JWT token for a character.
  """
  def generate_character_token(character, claims \\ %{}) do
    default_claims = %{
      "character_id" => character.id,
      "eve_id" => character.eve_id,
      "name" => character.name,
      "corporation_id" => character.corporation_id,
      "alliance_id" => character.alliance_id
    }

    encode_and_sign(character, Map.merge(default_claims, claims))
  end

  @doc """
  Validate and decode a JWT token.
  """
  def validate_token(token) do
    decode_and_verify(token)
  end
end
