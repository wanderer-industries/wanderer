defmodule WandererApp.GuardianJwtTest do
  use WandererApp.DataCase
  use ExMachina

  @moduletag :unit

  import WandererApp.Factory

  alias WandererApp.Guardian
  alias WandererApp.Test.AuthHelpers

  describe "Guardian JWT generation and validation" do
    test "generates and validates user JWT token" do
      user = create_user(%{name: "Test User", hash: "test-hash"})

      # Generate token
      token = AuthHelpers.generate_jwt_token(user)

      # Validate token format (should be JWT format)
      assert String.contains?(token, ".")
      parts = String.split(token, ".")
      assert length(parts) == 3

      # Decode and verify token
      {:ok, claims} = AuthHelpers.decode_jwt_token(token)

      # Verify claims contain expected user data
      assert claims["sub"] == "user:#{user.id}"
      assert claims["name"] == user.name
      # Hash should NOT be in the JWT for security reasons
      refute Map.has_key?(claims, "hash")
      assert claims["iss"] == "wanderer_app"
    end

    test "generates and validates character JWT token" do
      user = create_user()

      character =
        create_character(
          %{
            name: "Test Character",
            user_id: user.id
          },
          user
        )

      # Update character with corporation and alliance data
      {:ok, character} =
        WandererApp.Api.Character.update_corporation(character, %{
          corporation_id: 98_000_001,
          alliance_id: 99_000_001
        })

      # Generate token
      token = AuthHelpers.generate_character_token(character)

      # Validate token format
      assert String.contains?(token, ".")
      parts = String.split(token, ".")
      assert length(parts) == 3

      # Decode and verify token
      {:ok, claims} = AuthHelpers.decode_jwt_token(token)

      # Verify claims contain expected character data
      assert claims["sub"] == "character:#{character.id}"
      assert claims["character_id"] == character.id
      assert claims["eve_id"] == character.eve_id
      assert claims["name"] == character.name
      assert claims["corporation_id"] == character.corporation_id
      assert claims["alliance_id"] == character.alliance_id
      assert claims["iss"] == "wanderer_app"
    end

    test "validates token properly" do
      user = create_user(%{name: "Test User", hash: "test-hash"})
      token = AuthHelpers.generate_jwt_token(user)

      # Valid token should pass validation
      assert {:ok, _claims} = AuthHelpers.validate_jwt_token(token)

      # Invalid token should fail validation
      assert {:error, _reason} = AuthHelpers.validate_jwt_token("invalid.token.here")
    end

    test "fails gracefully with invalid tokens" do
      # Test with completely invalid token
      assert {:error, _reason} = AuthHelpers.decode_jwt_token("not.a.valid.token")

      # Test with malformed token
      assert {:error, _reason} = AuthHelpers.decode_jwt_token("header.payload")
    end
  end
end
