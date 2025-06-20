defmodule WandererAppWeb.ApiValidationsPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias WandererAppWeb.Validations.ApiValidations

  @moduledoc """
  Property-based tests for ApiValidations module.

  These tests verify that our validation functions handle all possible
  inputs correctly and maintain consistent behavior.
  """

  describe "integer parsing properties" do
    property "valid integers are always parsed correctly" do
      check all(int <- StreamData.integer()) do
        string_int = Integer.to_string(int)

        assert {:ok, ^int} = ApiValidations.parse_and_validate_integer(string_int)
        assert {:ok, ^int} = ApiValidations.parse_and_validate_integer(int)
      end
    end

    property "invalid strings always return changeset errors" do
      check all(invalid <- invalid_integer_string()) do
        result = ApiValidations.parse_and_validate_integer(invalid)

        case invalid do
          "0" ->
            # "0" is a valid integer
            assert {:ok, 0} = result

          _ ->
            assert {:error, changeset} = result
            assert %Ecto.Changeset{} = changeset
            assert not changeset.valid?
        end
      end
    end

    property "nil handling is consistent" do
      assert {:ok, nil} = ApiValidations.parse_and_validate_integer(nil)
      assert {:ok, nil} = ApiValidations.validate_optional_integer(%{}, "any_key")
    end
  end

  describe "hours validation properties" do
    property "positive hours are valid" do
      check all(hours <- StreamData.positive_integer()) do
        params = %{"hours" => Integer.to_string(hours)}

        assert {:ok, validated} = ApiValidations.validate_hours_param(params)
        assert validated.hours == hours
      end
    end

    property "zero hours is rejected by validation" do
      check all(key <- StreamData.member_of(["hours", "hours_ago", "hour_ago"])) do
        params = %{key => "0"}

        # The validation actually rejects 0, it must be > 0
        assert {:error, %Ecto.Changeset{}} = ApiValidations.validate_hours_param(params)
      end
    end

    property "hours validation respects max limit" do
      check all(hours <- StreamData.integer()) do
        params = %{"hours" => Integer.to_string(hours)}
        result = ApiValidations.validate_hours_param(params)

        if hours > 0 and hours <= 168 do
          assert {:ok, _} = result
        else
          assert {:error, %Ecto.Changeset{}} = result
        end
      end
    end
  end

  describe "days validation properties" do
    property "days defaults to 7 when not provided" do
      check all(params <- map_without_key("days")) do
        assert {:ok, validated} = ApiValidations.validate_days_param(params)
        assert validated.days == 7
      end
    end

    property "positive days are valid" do
      check all(days <- StreamData.integer(1..30)) do
        params = %{"days" => days}

        assert {:ok, validated} = ApiValidations.validate_days_param(params)
        assert validated.days == days
      end
    end
  end

  describe "role validation properties" do
    property "valid roles are always accepted" do
      check all(role <- valid_role()) do
        params = %{"member" => %{"role" => role}}

        assert {:ok, validated} = ApiValidations.validate_member_update_params(params["member"])
        assert validated.role == role
      end
    end

    property "invalid roles are always rejected" do
      check all(role <- invalid_role()) do
        params = %{"member" => %{"role" => role}}
        result = ApiValidations.validate_member_update_params(params["member"])

        assert {:error, %Ecto.Changeset{}} = result
      end
    end
  end

  describe "member filter properties" do
    property "type and role filters are optional but validated when present" do
      check all(
              type <- optional_member_type(),
              role <- optional_member_role()
            ) do
        params = %{}
        params = if type, do: Map.put(params, "type", type), else: params
        params = if role, do: Map.put(params, "role", role), else: params

        result = ApiValidations.validate_member_filters(params)

        valid_type = is_nil(type) or type in ["character", "corporation", "alliance"]
        valid_role = is_nil(role) or role in ["admin", "manager", "member", "viewer"]

        if valid_type and valid_role do
          assert {:ok, _} = result
        else
          assert {:error, %Ecto.Changeset{}} = result
        end
      end
    end
  end

  describe "changeset error formatting properties" do
    property "all changesets produce consistent error format" do
      check all(
              field <- StreamData.atom(:alphanumeric),
              message <- StreamData.string(:alphanumeric, min_length: 1)
            ) do
        changeset =
          {%{}, %{field => :string}}
          |> Ecto.Changeset.cast(%{}, [])
          |> Ecto.Changeset.add_error(field, message)

        formatted = ApiValidations.format_errors(changeset)

        assert %{error: "Validation failed", errors: errors} = formatted
        assert is_map(errors)
        assert message in errors[field]
      end
    end
  end

  # Generators

  defp invalid_integer_string do
    StreamData.one_of([
      StreamData.filter(
        StreamData.string(:alphanumeric, min_length: 1),
        fn s -> not Regex.match?(~r/^\d+$/, s) end
      ),
      StreamData.constant(""),
      StreamData.constant("123abc"),
      StreamData.constant("12.34"),
      StreamData.constant("not a number")
    ])
  end

  defp map_without_key(key) do
    StreamData.map_of(
      StreamData.string(:alphanumeric),
      StreamData.string(:alphanumeric)
    )
    |> StreamData.filter(fn map -> not Map.has_key?(map, key) end)
  end

  defp valid_role do
    StreamData.member_of(["admin", "manager", "member", "viewer"])
  end

  defp invalid_role do
    StreamData.filter(
      StreamData.string(:alphanumeric, min_length: 1),
      fn s -> s not in ["admin", "manager", "member", "viewer"] end
    )
  end

  defp optional_member_type do
    StreamData.frequency([
      {1, StreamData.constant(nil)},
      {2, StreamData.member_of(["character", "corporation", "alliance"])},
      {1, StreamData.string(:alphanumeric, min_length: 1)}
    ])
  end

  defp optional_member_role do
    StreamData.frequency([
      {1, StreamData.constant(nil)},
      {2, StreamData.member_of(["admin", "manager", "member", "viewer"])},
      {1, StreamData.string(:alphanumeric, min_length: 1)}
    ])
  end
end
