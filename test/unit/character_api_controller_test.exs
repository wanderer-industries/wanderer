# Standalone test for the CharacterAPIController
#
# This file can be run directly with:
#   elixir test/standalone/character_api_controller_test.exs
#
# It doesn't require any database connections or external dependencies.

# Start ExUnit
ExUnit.start()

defmodule CharacterAPIControllerTest do
  use ExUnit.Case

  # Mock modules to simulate the behavior of the controller's dependencies
  defmodule MockUtil do
    def require_param(params, key) do
      case params[key] do
        nil -> {:error, "Missing required param: #{key}"}
        "" -> {:error, "Param #{key} cannot be empty"}
        val -> {:ok, val}
      end
    end

    def parse_int(str) do
      case Integer.parse(str) do
        {num, ""} -> {:ok, num}
        _ -> {:error, "Invalid integer for param id=#{str}"}
      end
    end

    def parse_bool(str) do
      case str do
        "true" -> {:ok, true}
        "false" -> {:ok, false}
        _ -> {:error, "Invalid boolean value: #{str}"}
      end
    end
  end

  defmodule MockCharacterRepo do
    # In-memory storage for character tracking data
    def init_storage do
      :ets.new(:character_tracking, [:set, :public, :named_table])

      # Initialize with some test data
      :ets.insert(
        :character_tracking,
        {"user1",
         [
           %{eve_id: "123456", name: "Character One", tracked: true, followed: true},
           %{eve_id: "234567", name: "Character Two", tracked: true, followed: false},
           %{eve_id: "345678", name: "Character Three", tracked: false, followed: false}
         ]}
      )

      :ets.insert(
        :character_tracking,
        {"user2",
         [
           %{eve_id: "456789", name: "Character Four", tracked: true, followed: true}
         ]}
      )
    end

    def get_tracking_data(user_id) do
      case :ets.lookup(:character_tracking, user_id) do
        [{^user_id, data}] -> {:ok, data}
        [] -> {:ok, []}
      end
    end

    def update_tracking_data(user_id, new_data) do
      :ets.insert(:character_tracking, {user_id, new_data})
      {:ok, new_data}
    end

    def toggle_character_follow(user_id, character_id, follow_state) do
      case get_tracking_data(user_id) do
        {:ok, data} ->
          # Find the character and update its followed state
          updated_data =
            Enum.map(data, fn char ->
              if char.eve_id == character_id do
                %{char | followed: follow_state}
              else
                char
              end
            end)

          # Update the storage
          update_tracking_data(user_id, updated_data)

          # Return the updated character
          updated_char = Enum.find(updated_data, fn char -> char.eve_id == character_id end)
          {:ok, updated_char}

        error ->
          error
      end
    end

    def toggle_character_track(user_id, character_id, track_state) do
      case get_tracking_data(user_id) do
        {:ok, data} ->
          # Find the character and update its tracked state
          updated_data =
            Enum.map(data, fn char ->
              if char.eve_id == character_id do
                %{char | tracked: track_state}
              else
                char
              end
            end)

          # Update the storage
          update_tracking_data(user_id, updated_data)

          # Return the updated character
          updated_char = Enum.find(updated_data, fn char -> char.eve_id == character_id end)
          {:ok, updated_char}

        error ->
          error
      end
    end
  end

  defmodule MockTrackingUtils do
    def check_tracking_consistency(tracking_data) do
      # Log warnings for characters that are followed but not tracked
      inconsistent_chars =
        Enum.filter(tracking_data, fn char ->
          char[:followed] == true && char[:tracked] == false
        end)

      if length(inconsistent_chars) > 0 do
        Enum.each(inconsistent_chars, fn char ->
          eve_id = Map.get(char, :eve_id, "unknown")
          name = Map.get(char, :name, "Unknown Character")

          IO.puts(
            "WARNING: Inconsistent state detected - Character (ID: #{eve_id}, Name: #{name}) is followed but not tracked"
          )
        end)
      end

      # Return the original data unchanged
      tracking_data
    end
  end

  # Mock controller that uses our mock dependencies
  defmodule MockCharacterAPIController do
    # Simplified version of toggle_follow from CharacterAPIController
    def toggle_follow(params, user_id) do
      with {:ok, character_id} <- MockUtil.require_param(params, "character_id"),
           {:ok, follow_str} <- MockUtil.require_param(params, "follow"),
           {:ok, follow} <- MockUtil.parse_bool(follow_str) do
        case MockCharacterRepo.toggle_character_follow(user_id, character_id, follow) do
          {:ok, updated_char} ->
            # Get all tracking data to check consistency
            {:ok, all_tracking} = MockCharacterRepo.get_tracking_data(user_id)

            # Check for inconsistencies (characters followed but not tracked)
            MockTrackingUtils.check_tracking_consistency(all_tracking)

            # Return the updated character
            {:ok, %{data: updated_char}}

          {:error, reason} ->
            {:error, :internal_server_error, "Failed to update character: #{reason}"}
        end
      else
        {:error, msg} ->
          {:error, :bad_request, msg}
      end
    end

    # Simplified version of toggle_track from CharacterAPIController
    def toggle_track(params, user_id) do
      with {:ok, character_id} <- MockUtil.require_param(params, "character_id"),
           {:ok, track_str} <- MockUtil.require_param(params, "track"),
           {:ok, track} <- MockUtil.parse_bool(track_str) do
        # If we're untracking a character, we should also unfollow it
        result =
          if track == false do
            # First unfollow if needed
            MockCharacterRepo.toggle_character_follow(user_id, character_id, false)
            # Then untrack
            MockCharacterRepo.toggle_character_track(user_id, character_id, false)
          else
            # Just track
            MockCharacterRepo.toggle_character_track(user_id, character_id, true)
          end

        case result do
          {:ok, updated_char} ->
            # Get all tracking data to check consistency
            {:ok, all_tracking} = MockCharacterRepo.get_tracking_data(user_id)

            # Check for inconsistencies (characters followed but not tracked)
            MockTrackingUtils.check_tracking_consistency(all_tracking)

            # Return the updated character
            {:ok, %{data: updated_char}}

          {:error, reason} ->
            {:error, :internal_server_error, "Failed to update character: #{reason}"}
        end
      else
        {:error, msg} ->
          {:error, :bad_request, msg}
      end
    end

    # Simplified version of list_tracking from CharacterAPIController
    def list_tracking(user_id) do
      case MockCharacterRepo.get_tracking_data(user_id) do
        {:ok, tracking_data} ->
          # Check for inconsistencies
          checked_data = MockTrackingUtils.check_tracking_consistency(tracking_data)

          # Return the data
          {:ok, %{data: checked_data}}

        {:error, reason} ->
          {:error, :internal_server_error, "Failed to get tracking data: #{reason}"}
      end
    end
  end

  # Setup for tests
  setup do
    # Initialize the mock storage
    MockCharacterRepo.init_storage()
    :ok
  end

  describe "toggle_follow/2" do
    test "follows a character successfully" do
      params = %{"character_id" => "345678", "follow" => "true"}
      result = MockCharacterAPIController.toggle_follow(params, "user1")

      assert {:ok, %{data: data}} = result
      assert data.eve_id == "345678"
      assert data.name == "Character Three"
      assert data.followed == true
      assert data.tracked == false

      # This should have created an inconsistency (followed but not tracked)
      # The check_tracking_consistency function should have logged a warning
    end

    test "unfollows a character successfully" do
      params = %{"character_id" => "123456", "follow" => "false"}
      result = MockCharacterAPIController.toggle_follow(params, "user1")

      assert {:ok, %{data: data}} = result
      assert data.eve_id == "123456"
      assert data.followed == false
      assert data.tracked == true
    end

    test "returns error when character_id is missing" do
      params = %{"follow" => "true"}
      result = MockCharacterAPIController.toggle_follow(params, "user1")

      assert {:error, :bad_request, message} = result
      assert message == "Missing required param: character_id"
    end

    test "returns error when follow is not a valid boolean" do
      params = %{"character_id" => "123456", "follow" => "not-a-boolean"}
      result = MockCharacterAPIController.toggle_follow(params, "user1")

      assert {:error, :bad_request, message} = result
      assert message =~ "Invalid boolean value"
    end
  end

  describe "toggle_track/2" do
    test "tracks a character successfully" do
      params = %{"character_id" => "345678", "track" => "true"}
      result = MockCharacterAPIController.toggle_track(params, "user1")

      assert {:ok, %{data: data}} = result
      assert data.eve_id == "345678"
      assert data.tracked == true
    end

    test "untracks and unfollows a character" do
      # First, make sure the character is followed
      follow_params = %{"character_id" => "123456", "follow" => "true"}
      MockCharacterAPIController.toggle_follow(follow_params, "user1")

      # Now untrack the character
      params = %{"character_id" => "123456", "track" => "false"}
      result = MockCharacterAPIController.toggle_track(params, "user1")

      assert {:ok, %{data: data}} = result
      assert data.eve_id == "123456"
      assert data.tracked == false
      # Should also be unfollowed
      assert data.followed == false
    end

    test "returns error when character_id is missing" do
      params = %{"track" => "true"}
      result = MockCharacterAPIController.toggle_track(params, "user1")

      assert {:error, :bad_request, message} = result
      assert message == "Missing required param: character_id"
    end

    test "returns error when track is not a valid boolean" do
      params = %{"character_id" => "123456", "track" => "not-a-boolean"}
      result = MockCharacterAPIController.toggle_track(params, "user1")

      assert {:error, :bad_request, message} = result
      assert message =~ "Invalid boolean value"
    end
  end

  describe "list_tracking/1" do
    test "returns tracking data for a user" do
      result = MockCharacterAPIController.list_tracking("user1")

      assert {:ok, %{data: data}} = result
      assert length(data) == 3

      # Check that the data contains the expected characters
      char_one = Enum.find(data, fn char -> char.eve_id == "123456" end)
      assert char_one.name == "Character One"
      assert char_one.tracked == true
      assert char_one.followed == true

      char_two = Enum.find(data, fn char -> char.eve_id == "234567" end)
      assert char_two.name == "Character Two"
      assert char_two.tracked == true
      assert char_two.followed == false
    end

    test "returns empty list for user with no tracking data" do
      result = MockCharacterAPIController.list_tracking("non-existent-user")

      assert {:ok, %{data: data}} = result
      assert data == []
    end
  end
end
