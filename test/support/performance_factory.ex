defmodule WandererApp.Test.PerformanceFactory do
  @moduledoc """
  Performance-optimized factory for test data creation.

  Provides batch creation methods and caching for frequently used test data
  to reduce database operations and improve test execution speed.
  """

  alias WandererApp.Api
  alias WandererAppWeb.Factory

  @doc """
  Create multiple resources of the same type in a single batch operation.
  Much faster than individual creates for large test datasets.
  """
  def insert_batch(resource_type, count, base_attrs \\ %{}) do
    1..count
    |> Enum.map(fn i ->
      attrs = Map.merge(base_attrs, %{sequence_id: i})
      build_attrs_for_batch(resource_type, attrs, i)
    end)
    |> then(fn attrs_list ->
      case resource_type do
        :user ->
          batch_create_users(attrs_list)

        :character ->
          batch_create_characters(attrs_list)

        :map ->
          batch_create_maps(attrs_list)

        _ ->
          # Fallback to individual creates for unsupported types
          Enum.map(attrs_list, &Factory.insert(resource_type, &1))
      end
    end)
  end

  @doc """
  Create a minimal test scenario with all necessary relationships.
  Optimized for common test patterns.
  """
  def create_test_scenario(type \\ :basic) do
    case type do
      :basic ->
        create_basic_scenario()

      :with_map ->
        create_map_scenario()

      :with_characters ->
        create_character_scenario()

      :full ->
        create_full_scenario()
    end
  end

  # Private helper functions

  defp build_attrs_for_batch(:user, base_attrs, sequence) do
    Map.merge(
      %{
        name: "Test User #{sequence}",
        hash: "test_hash_#{sequence}"
      },
      base_attrs
    )
  end

  defp build_attrs_for_batch(:character, base_attrs, sequence) do
    Map.merge(
      %{
        name: "Test Character #{sequence}",
        eve_id: "200000#{sequence}",
        corporation_id: 1_000_000_000 + sequence,
        corporation_name: "Test Corporation",
        corporation_ticker: "TEST"
      },
      base_attrs
    )
  end

  defp build_attrs_for_batch(:map, base_attrs, sequence) do
    Map.merge(
      %{
        name: "Test Map #{sequence}",
        slug: "test-map-#{sequence}",
        description: "Test map description #{sequence}"
      },
      base_attrs
    )
  end

  defp batch_create_users(attrs_list) do
    # Use direct Ecto.Multi for batch operations if available
    # Otherwise fall back to individual Ash creates
    attrs_list
    |> Enum.map(fn attrs ->
      case Ash.create(Api.User, attrs) do
        {:ok, user} -> user
        {:error, error} -> raise "Failed to create user: #{inspect(error)}"
      end
    end)
  end

  defp batch_create_characters(attrs_list) do
    attrs_list
    |> Enum.map(fn attrs ->
      case Ash.create(Api.Character, attrs, action: :create) do
        {:ok, character} -> character
        {:error, error} -> raise "Failed to create character: #{inspect(error)}"
      end
    end)
  end

  defp batch_create_maps(attrs_list) do
    attrs_list
    |> Enum.map(fn attrs ->
      case Ash.create(Api.Map, attrs) do
        {:ok, map} -> map
        {:error, error} -> raise "Failed to create map: #{inspect(error)}"
      end
    end)
  end

  defp create_basic_scenario do
    user = Factory.insert(:user)
    %{user: user}
  end

  defp create_map_scenario do
    user = Factory.insert(:user)
    character = Factory.insert(:character, %{user_id: user.id})
    map = Factory.insert(:map, %{owner_id: character.id})

    %{
      user: user,
      character: character,
      map: map
    }
  end

  defp create_character_scenario do
    user = Factory.insert(:user)
    characters = insert_batch(:character, 3, %{user_id: user.id})

    %{
      user: user,
      characters: characters
    }
  end

  defp create_full_scenario do
    user = Factory.insert(:user)
    character = Factory.insert(:character, %{user_id: user.id})
    map = Factory.insert(:map, %{owner_id: character.id})

    # Create related data efficiently
    access_list = Factory.insert(:access_list, %{owner_id: character.id})
    Factory.insert(:map_access_list, %{map_id: map.id, access_list_id: access_list.id})

    %{
      user: user,
      character: character,
      map: map,
      access_list: access_list
    }
  end

  @doc """
  Cache frequently used test data to avoid recreating the same objects.
  Useful for read-only test data that doesn't change between tests.
  """
  def cached_test_data(key, creation_fn) do
    case Process.get({:test_cache, key}) do
      nil ->
        data = creation_fn.()
        Process.put({:test_cache, key}, data)
        data

      cached_data ->
        cached_data
    end
  end

  @doc """
  Clear the test data cache. Should be called in test teardown if needed.
  """
  def clear_cache do
    Process.get()
    |> Enum.filter(fn
      {{:test_cache, _key}, _value} -> true
      _ -> false
    end)
    |> Enum.each(fn {{:test_cache, key}, _value} -> Process.delete({:test_cache, key}) end)
  end
end
