defmodule WandererApp.TestHelpersTest do
  use ExUnit.Case

  alias WandererApp.TestHelpers

  describe "atomize_keys/1" do
    test "converts string keys to atom keys in a map" do
      input = %{"name" => "test", "age" => 25}
      expected = %{name: "test", age: 25}

      assert TestHelpers.atomize_keys(input) == expected
    end

    test "works recursively with nested maps" do
      input = %{"user" => %{"name" => "test", "details" => %{"age" => 25}}}
      expected = %{user: %{name: "test", details: %{age: 25}}}

      assert TestHelpers.atomize_keys(input) == expected
    end

    test "works with lists of maps" do
      input = [%{"name" => "test1"}, %{"name" => "test2"}]
      expected = [%{name: "test1"}, %{name: "test2"}]

      assert TestHelpers.atomize_keys(input) == expected
    end

    test "leaves non-map values unchanged" do
      assert TestHelpers.atomize_keys("string") == "string"
      assert TestHelpers.atomize_keys(42) == 42
      assert TestHelpers.atomize_keys(nil) == nil
    end
  end

  describe "assert_maps_equal/2" do
    test "passes when maps contain expected key-value pairs" do
      actual = %{name: "test", age: 25, extra: "data"}
      expected = %{name: "test", age: 25}

      # Should not raise
      TestHelpers.assert_maps_equal(actual, expected)
    end

    test "fails when expected key is missing" do
      actual = %{name: "test"}
      expected = %{name: "test", age: 25}

      assert_raise ExUnit.AssertionError, fn ->
        TestHelpers.assert_maps_equal(actual, expected)
      end
    end

    test "fails when values don't match" do
      actual = %{name: "test", age: 25}
      expected = %{name: "test", age: 30}

      assert_raise ExUnit.AssertionError, fn ->
        TestHelpers.assert_maps_equal(actual, expected)
      end
    end
  end

  describe "assert_list_contains/2" do
    test "passes when list contains expected item" do
      list = ["apple", "banana", "cherry"]

      # Should not raise
      TestHelpers.assert_list_contains(list, "banana")
    end

    test "passes when list contains item matching function" do
      list = [%{name: "apple"}, %{name: "banana"}]
      matcher = fn item -> item.name == "banana" end

      # Should not raise
      TestHelpers.assert_list_contains(list, matcher)
    end

    test "fails when list doesn't contain expected item" do
      list = ["apple", "cherry"]

      assert_raise ExUnit.AssertionError, fn ->
        TestHelpers.assert_list_contains(list, "banana")
      end
    end
  end

  describe "random_string/1" do
    test "generates a string of specified length" do
      result = TestHelpers.random_string(10)

      assert is_binary(result)
      assert String.length(result) == 10
    end

    test "generates different strings on multiple calls" do
      string1 = TestHelpers.random_string(10)
      string2 = TestHelpers.random_string(10)

      assert string1 != string2
    end

    test "uses default length when no argument provided" do
      result = TestHelpers.random_string()

      assert is_binary(result)
      assert String.length(result) == 10
    end
  end
end
