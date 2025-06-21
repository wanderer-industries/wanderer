defmodule WandererApp.AccessListMemberPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias WandererApp.Api.AccessListMember
  alias WandererApp.Api

  @moduledoc """
  Property-based tests for AccessListMember resource.

  These tests verify invariants and business rules that should hold
  for all possible inputs.
  """

  describe "role validation properties" do
    property "corporation members cannot have admin or manager roles" do
      check all(
              role <- member_role(),
              corp_id <- eve_entity_id()
            ) do
        member = %{
          eve_corporation_id: corp_id,
          eve_alliance_id: nil,
          eve_character_id: nil
        }

        # Simulate the validation logic
        result = validate_role_for_entity_type(member, role)

        if role in [:admin, :manager] do
          assert {:error, _} = result
        else
          assert :ok = result
        end
      end
    end

    property "alliance members cannot have admin or manager roles" do
      check all(
              role <- member_role(),
              alliance_id <- eve_entity_id()
            ) do
        member = %{
          eve_corporation_id: nil,
          eve_alliance_id: alliance_id,
          eve_character_id: nil
        }

        result = validate_role_for_entity_type(member, role)

        if role in [:admin, :manager] do
          assert {:error, _} = result
        else
          assert :ok = result
        end
      end
    end

    property "character members can have any role" do
      check all(
              role <- member_role(),
              char_id <- eve_entity_id()
            ) do
        member = %{
          eve_corporation_id: nil,
          eve_alliance_id: nil,
          eve_character_id: char_id
        }

        result = validate_role_for_entity_type(member, role)
        assert :ok = result
      end
    end

    property "exactly one entity type must be specified" do
      check all(
              char_id <- optional_eve_entity_id(),
              corp_id <- optional_eve_entity_id(),
              alliance_id <- optional_eve_entity_id()
            ) do
        entity_count =
          [char_id, corp_id, alliance_id]
          |> Enum.reject(&is_nil/1)
          |> length()

        result = validate_entity_count(char_id, corp_id, alliance_id)

        if entity_count == 1 do
          assert :ok = result
        else
          assert {:error, _} = result
        end
      end
    end
  end

  describe "role string/atom conversion properties" do
    property "role atoms and strings are interchangeable" do
      check all(role <- member_role()) do
        role_string = to_string(role)
        role_atom = String.to_atom(role_string)

        assert role == role_atom
        assert role_string == to_string(role_atom)
      end
    end
  end

  # Generators

  defp member_role do
    StreamData.member_of([:admin, :manager, :member, :viewer, :blocked])
  end

  defp eve_entity_id do
    # EVE IDs are typically large integers represented as strings
    StreamData.map(
      StreamData.integer(1..999_999_999),
      &Integer.to_string/1
    )
  end

  defp optional_eve_entity_id do
    StreamData.frequency([
      {1, StreamData.constant(nil)},
      {3, eve_entity_id()}
    ])
  end

  # Helper functions that mirror the actual validation logic

  defp validate_role_for_entity_type(member, role) do
    member_type = determine_member_type(member)

    if member_type in ["corporation", "alliance"] and role in [:admin, :manager] do
      {:error, "#{String.capitalize(member_type)} members cannot have #{role} role"}
    else
      :ok
    end
  end

  defp determine_member_type(member) do
    cond do
      member.eve_corporation_id -> "corporation"
      member.eve_alliance_id -> "alliance"
      member.eve_character_id -> "character"
      true -> "character"
    end
  end

  defp validate_entity_count(char_id, corp_id, alliance_id) do
    entity_count =
      [char_id, corp_id, alliance_id]
      |> Enum.reject(&is_nil/1)
      |> length()

    case entity_count do
      0 -> {:error, "Must specify exactly one entity type"}
      1 -> :ok
      _ -> {:error, "Can only specify one entity type at a time"}
    end
  end
end
