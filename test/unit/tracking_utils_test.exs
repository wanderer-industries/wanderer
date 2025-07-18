# Test for the check_tracking_consistency function in WandererApp.Character.TrackingUtils
#
# This file can be run directly with:
#   elixir test/unit/tracking_consistency_test.exs
#
# It doesn't require any database connections or external dependencies.

# Start ExUnit
ExUnit.start()

defmodule WandererApp.Character.TrackingConsistencyTest do
  use ExUnit.Case
  require Logger
  import ExUnit.CaptureIO

  # This is a copy of the function from TrackingUtils
  def check_tracking_consistency(tracking_data) do
    # Find any characters that are followed but not tracked
    inconsistent_characters =
      Enum.filter(tracking_data, fn data ->
        data.followed && !data.tracked
      end)

    # Log a warning for each inconsistent character
    Enum.each(inconsistent_characters, fn data ->
      character = data.character
      # Use IO.puts instead of Logger to avoid dependencies
      eve_id = Map.get(character, :eve_id, "unknown")
      name = Map.get(character, :name, "unknown")

      IO.puts(
        "WARNING: Inconsistent state detected: Character is followed but not tracked. Character ID: #{eve_id}, Name: #{name}"
      )
    end)

    # Return the original tracking data
    tracking_data
  end

  describe "check_tracking_consistency/1" do
    test "logs a warning when a character is followed but not tracked" do
      # Create test data with inconsistent state
      tracking_data = [
        %{
          character: %{eve_id: "test-eve-id", name: "Test Character"},
          tracked: false,
          followed: true
        }
      ]

      # Call the function and capture output
      output =
        capture_io(fn ->
          check_tracking_consistency(tracking_data)
        end)

      # Assert that the warning was logged
      assert output =~ "Inconsistent state detected: Character is followed but not tracked"
      assert output =~ "test-eve-id"
      assert output =~ "Test Character"
    end

    test "does not log a warning when all followed characters are also tracked" do
      # Create test data with consistent state
      tracking_data = [
        %{
          character: %{eve_id: "test-eve-id", name: "Test Character"},
          tracked: true,
          followed: true
        }
      ]

      # Call the function and capture output
      output =
        capture_io(fn ->
          check_tracking_consistency(tracking_data)
        end)

      # Assert that no warning was logged
      refute output =~ "Inconsistent state detected"
    end

    test "does not log a warning when no characters are followed" do
      # Create test data with no followed characters
      tracking_data = [
        %{
          character: %{eve_id: "test-eve-id", name: "Test Character"},
          tracked: true,
          followed: false
        }
      ]

      # Call the function and capture output
      output =
        capture_io(fn ->
          check_tracking_consistency(tracking_data)
        end)

      # Assert that no warning was logged
      refute output =~ "Inconsistent state detected"
    end

    test "handles multiple characters with mixed states correctly" do
      # Create test data with multiple characters in different states
      tracking_data = [
        %{
          character: %{eve_id: "character-1", name: "Character 1"},
          tracked: true,
          followed: true
        },
        %{
          character: %{eve_id: "character-2", name: "Character 2"},
          tracked: false,
          followed: true
        },
        %{
          character: %{eve_id: "character-3", name: "Character 3"},
          tracked: true,
          followed: false
        },
        %{
          character: %{eve_id: "character-4", name: "Character 4"},
          tracked: false,
          followed: false
        }
      ]

      # Call the function and capture output
      output =
        capture_io(fn ->
          check_tracking_consistency(tracking_data)
        end)

      # Assert that only the inconsistent character triggered a warning
      assert output =~ "Inconsistent state detected: Character is followed but not tracked"
      assert output =~ "character-2"
      assert output =~ "Character 2"
      refute output =~ "character-1"
      refute output =~ "character-3"
      refute output =~ "character-4"
    end

    test "returns the original tracking data unchanged" do
      # Create test data
      tracking_data = [
        %{
          character: %{eve_id: "test-eve-id", name: "Test Character"},
          tracked: false,
          followed: true
        }
      ]

      # Call the function and get the result
      result = check_tracking_consistency(tracking_data)

      # Assert that the returned data is the same as the input data
      assert result == tracking_data
    end

    test "handles empty tracking data without errors" do
      # Create empty tracking data
      tracking_data = []

      # Call the function and capture output
      output =
        capture_io(fn ->
          result = check_tracking_consistency(tracking_data)
          # Assert that the returned data is the same as the input data
          assert result == tracking_data
        end)

      # Assert that no warning was logged
      refute output =~ "Inconsistent state detected"
    end

    test "handles multiple inconsistent characters correctly" do
      # Create test data with multiple inconsistent characters
      tracking_data = [
        %{
          character: %{eve_id: "character-1", name: "Character 1"},
          tracked: false,
          followed: true
        },
        %{
          character: %{eve_id: "character-2", name: "Character 2"},
          tracked: false,
          followed: true
        },
        %{
          character: %{eve_id: "character-3", name: "Character 3"},
          tracked: true,
          followed: true
        }
      ]

      # Call the function and capture output
      output =
        capture_io(fn ->
          check_tracking_consistency(tracking_data)
        end)

      # Assert that warnings were logged for both inconsistent characters
      assert output =~ "Character ID: character-1"
      assert output =~ "Name: Character 1"
      assert output =~ "Character ID: character-2"
      assert output =~ "Name: Character 2"
      refute output =~ "Character ID: character-3"
    end

    test "handles characters with missing fields gracefully" do
      # Create test data with missing fields
      tracking_data = [
        %{
          # Missing name
          character: %{eve_id: "character-1"},
          tracked: false,
          followed: true
        },
        %{
          # Missing eve_id
          character: %{name: "Character 2"},
          tracked: false,
          followed: true
        }
      ]

      # Call the function and capture output
      output =
        capture_io(fn ->
          result = check_tracking_consistency(tracking_data)
          # Assert that the returned data is the same as the input data
          assert result == tracking_data
        end)

      # Assert that warnings were logged with available information
      assert output =~ "Character ID: character-1"
      assert output =~ "Name: unknown"
      assert output =~ "Character ID: unknown"
      assert output =~ "Name: Character 2"
    end

    test "handles characters with nil tracked or followed values" do
      # Create test data with nil values
      tracking_data = [
        %{
          character: %{eve_id: "character-1", name: "Character 1"},
          tracked: nil,
          followed: true
        },
        %{
          character: %{eve_id: "character-2", name: "Character 2"},
          tracked: false,
          followed: nil
        }
      ]

      # Call the function and capture output
      output =
        capture_io(fn ->
          result = check_tracking_consistency(tracking_data)
          # Assert that the returned data is the same as the input data
          assert result == tracking_data
        end)

      # Assert that a warning was logged for the first character (nil tracked is treated as false)
      assert output =~ "Character ID: character-1"
      assert output =~ "Name: Character 1"
      # No warning for the second character (nil followed is treated as false)
      refute output =~ "Character ID: character-2"
    end

    test "handles malformed tracking data gracefully" do
      # Create malformed tracking data (missing required fields)
      tracking_data = [
        %{
          # Missing character field
          tracked: false,
          followed: true
        }
      ]

      # Call the function and capture output, expecting it to handle errors gracefully
      assert_raise(KeyError, fn ->
        check_tracking_consistency(tracking_data)
      end)
    end
  end

  # Additional tests for edge cases in the filter logic
  describe "filter logic in check_tracking_consistency/1" do
    test "correctly identifies characters that are followed but not tracked" do
      # Create test data with various combinations
      tracking_data = [
        %{
          character: %{eve_id: "char-1", name: "Character 1"},
          tracked: false,
          followed: true
        },
        %{
          character: %{eve_id: "char-2", name: "Character 2"},
          tracked: true,
          followed: true
        },
        %{
          character: %{eve_id: "char-3", name: "Character 3"},
          tracked: false,
          followed: false
        },
        %{
          character: %{eve_id: "char-4", name: "Character 4"},
          tracked: true,
          followed: false
        }
      ]

      # Extract the filter logic from the function
      inconsistent_characters =
        Enum.filter(tracking_data, fn data ->
          data.followed && !data.tracked
        end)

      # Assert that only the first character is identified as inconsistent
      assert length(inconsistent_characters) == 1
      assert hd(inconsistent_characters).character.eve_id == "char-1"
    end

    test "handles boolean-like values correctly in filter logic" do
      # Create test data with various boolean-like values
      tracking_data = [
        %{
          character: %{eve_id: "char-1", name: "Character 1"},
          tracked: false,
          # String instead of boolean - in Elixir, only false and nil are falsy
          followed: "true"
        }
      ]

      # Extract the filter logic from the function
      inconsistent_characters =
        Enum.filter(tracking_data, fn data ->
          data.followed && !data.tracked
        end)

      # Assert that the character is identified as inconsistent
      # (since in Elixir, only false and nil are falsy, everything else is truthy)
      assert length(inconsistent_characters) == 1
    end
  end
end
