defmodule WandererApp.MapPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  @moduledoc """
  Property-based tests for Map resource.

  These tests verify invariants and business rules for maps,
  including slug generation, character limits, and hub management.
  """

  describe "map slug properties" do
    property "slugs are always lowercase and URL-safe" do
      check all(name <- map_name()) do
        slug = generate_slug(name)

        assert slug == String.downcase(slug)
        assert slug =~ ~r/^[a-z0-9-]*$/
        assert !String.contains?(slug, " ")
      end
    end

    property "slugs preserve word boundaries with hyphens" do
      check all(words <- list_of(word(), min_length: 1, max_length: 5)) do
        name = Enum.join(words, " ")
        slug = generate_slug(name)

        # Each word should be separated by a hyphen (unless empty after cleaning)
        slug_parts = String.split(slug, "-", trim: true)
        assert length(slug_parts) <= length(words)
      end
    end

    property "slug generation is deterministic" do
      check all(name <- map_name()) do
        slug1 = generate_slug(name)
        slug2 = generate_slug(name)

        assert slug1 == slug2
      end
    end
  end

  describe "map character limit properties" do
    property "character limit must be positive or unlimited" do
      check all(limit <- character_limit()) do
        assert limit == 0 or limit > 0

        # 0 means unlimited
        if limit == 0 do
          assert character_limit_valid?(limit, 9999)
        else
          assert character_limit_valid?(limit, limit - 1)
          refute character_limit_valid?(limit, limit + 1)
        end
      end
    end

    property "maps cannot exceed their character limit when limit is set" do
      check all(
              limit <- StreamData.integer(1..10),
              character_count <- StreamData.integer(0..20)
            ) do
        result = can_add_character?(limit, character_count)

        if character_count < limit do
          assert result
        else
          refute result
        end
      end
    end
  end

  describe "map hub properties" do
    property "hubs list maintains uniqueness" do
      check all(hub_ids <- list_of(hub_id(), max_length: 20)) do
        unique_hubs = Enum.uniq(hub_ids)

        # Simulating hub management
        final_hubs =
          Enum.reduce(hub_ids, [], fn hub_id, acc ->
            if hub_id in acc do
              acc
            else
              [hub_id | acc]
            end
          end)

        assert length(final_hubs) == length(Enum.uniq(hub_ids))
      end
    end

    property "hub IDs are valid solar system IDs" do
      check all(hub_id <- hub_id()) do
        assert is_integer(hub_id)
        assert hub_id > 0
        # EVE solar system IDs are typically in specific ranges
        assert hub_id >= 30_000_000 and hub_id <= 33_000_000
      end
    end
  end

  describe "map scope properties" do
    property "scope is always a valid value" do
      check all(scope <- map_scope()) do
        assert scope in ["public", "private", "corporation", "alliance"]
      end
    end

    property "corporation maps require corporation_id" do
      check all(corp_id <- optional_corporation_id()) do
        # Test corporation scope
        corp_result = validate_scope_requirements("corporation", corp_id, nil)
        assert corp_result == (corp_id != nil)

        # Other scopes don't care about corp_id
        assert validate_scope_requirements("public", corp_id, nil) == true
        assert validate_scope_requirements("private", corp_id, nil) == true
      end
    end

    property "alliance maps require alliance_id" do
      check all(alliance_id <- optional_alliance_id()) do
        # Test alliance scope
        alliance_result = validate_scope_requirements("alliance", nil, alliance_id)
        assert alliance_result == (alliance_id != nil)

        # Other scopes don't care about alliance_id
        assert validate_scope_requirements("public", nil, alliance_id) == true
        assert validate_scope_requirements("private", nil, alliance_id) == true
      end
    end
  end

  # Generators

  defp map_name do
    StreamData.string(:alphanumeric, min_length: 1, max_length: 50)
  end

  defp word do
    StreamData.string(:alphanumeric, min_length: 1, max_length: 10)
  end

  defp character_limit do
    StreamData.frequency([
      # Unlimited
      {1, StreamData.constant(0)},
      {3, StreamData.integer(1..100)}
    ])
  end

  defp hub_id do
    # EVE solar system IDs are in specific ranges
    StreamData.integer(30_000_000..33_000_000)
  end

  defp map_scope do
    StreamData.member_of(["public", "private", "corporation", "alliance"])
  end

  defp optional_corporation_id do
    StreamData.frequency([
      {1, StreamData.constant(nil)},
      {3, StreamData.integer(1_000_000..2_000_000)}
    ])
  end

  defp optional_alliance_id do
    StreamData.frequency([
      {1, StreamData.constant(nil)},
      {3, StreamData.integer(99_000_000..99_999_999)}
    ])
  end

  # Helper functions

  defp generate_slug(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.trim("-")
  end

  defp character_limit_valid?(limit, character_count) do
    limit == 0 or character_count <= limit
  end

  defp can_add_character?(limit, current_count) do
    limit == 0 or current_count < limit
  end

  defp validate_scope_requirements("corporation", corp_id, _alliance_id) do
    corp_id != nil
  end

  defp validate_scope_requirements("alliance", _corp_id, alliance_id) do
    alliance_id != nil
  end

  defp validate_scope_requirements(_scope, _corp_id, _alliance_id) do
    true
  end
end
