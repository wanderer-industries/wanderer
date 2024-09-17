defmodule WandererApp.Map do
  @moduledoc """
  Represents the map structure and exposes actions that can be taken to update
  it
  """
  require Logger

  defstruct map_id: nil,
            name: nil,
            scope: :none,
            characters: [],
            systems: Map.new(),
            hubs: [],
            connections: Map.new(),
            acls: [],
            characters_limit: nil,
            hubs_limit: nil

  def new(%{id: map_id, name: name, scope: scope, acls: acls, hubs: hubs}) do
    map =
      struct!(__MODULE__,
        map_id: map_id,
        scope: scope,
        name: name,
        acls: acls,
        hubs: hubs
      )

    update_map(map_id, map)

    map
  end

  def get_map(map_id) do
    case Cachex.get(:map_cache, map_id) do
      {:ok, nil} ->
        {:error, :not_found}

      {:ok, map} ->
        {:ok, map}
    end
  end

  def get_map!(map_id) do
    case get_map(map_id) do
      {:ok, map} ->
        map

      _ ->
        Logger.error(fn -> "Failed to get map #{map_id}" end)
        %{}
    end
  end

  def update_map(map_id, map_update) do
    Cachex.get_and_update(:map_cache, map_id, fn map ->
      case map do
        nil ->
          {:commit, map_update}

        _ ->
          {:commit, Map.merge(map, map_update)}
      end
    end)
  end

  def get_characters_limit(map_id),
    do: {:ok, map_id |> get_map!() |> Map.get(:characters_limit, 100)}

  @doc """
  Returns a full list of characters in the map
  """
  def list_characters(map_id),
    do:
      map_id
      |> get_map!()
      |> Map.get(:characters, [])
      |> Enum.map(&WandererApp.Character.get_character!(&1))

  def list_systems(map_id),
    do: {:ok, map_id |> get_map!() |> Map.get(:systems, Map.new()) |> Map.values()}

  def list_systems!(map_id) do
    {:ok, systems} = list_systems(map_id)
    systems
  end

  def list_hubs(map_id) do
    {:ok, map} = map_id |> get_map()
    hubs = map |> Map.get(:hubs, [])
    hubs_limit = map |> Map.get(:hubs_limit, 20)

    {:ok, hubs |> _maybe_limit_list(hubs_limit)}
  end

  def list_connections(map_id),
    do: {:ok, map_id |> get_map!() |> Map.get(:connections, Map.new()) |> Map.values()}

  def list_connections!(map_id) do
    {:ok, connections} = list_connections(map_id)
    connections
  end

  def get_connection(map_id, solar_system_source, solar_system_target),
    do:
      map_id
      |> get_map!()
      |> Map.get(:connections, Map.new())
      |> Map.get("#{solar_system_source}_#{solar_system_target}")

  def add_characters!(map, []), do: map

  def add_characters!(%{map_id: map_id} = map, [character | rest]) do
    case add_character(map_id, character) do
      :ok ->
        add_characters!(map, rest)

      {:error, :already_exists} ->
        add_characters!(map, rest)
    end
  end

  def add_character(
        map_id,
        %{
          id: character_id,
          alliance_id: alliance_id,
          corporation_id: corporation_id,
          solar_system_id: solar_system_id,
          ship: ship_type_id,
          ship_name: ship_name
        } = _character
      ) do
    characters = map_id |> get_map!() |> Map.get(:characters, [])

    case not (characters |> Enum.member?(character_id)) do
      true ->
        map_id
        |> update_map(%{characters: [character_id | characters]})

        WandererApp.Cache.insert(
          "map:#{map_id}:character:#{character_id}:alliance_id",
          alliance_id
        )

        WandererApp.Cache.insert(
          "map:#{map_id}:character:#{character_id}:corporation_id",
          corporation_id
        )

        WandererApp.Cache.insert(
          "map:#{map_id}:character:#{character_id}:solar_system_id",
          solar_system_id
        )

        WandererApp.Cache.insert(
          "map:#{map_id}:character:#{character_id}:ship_type_id",
          ship_type_id
        )

        WandererApp.Cache.insert(
          "map:#{map_id}:character:#{character_id}:ship_name",
          ship_name
        )

        :ok

      _ ->
        {:error, :already_exists}
    end
  end

  def get_system_characters(map_id, solar_system_id),
    do:
      map_id
      |> list_characters()
      |> filter(%{solar_system_id: solar_system_id}, match: :any)

  @doc """
  Removes a character with a given id
  """
  def remove_character(map_id, character_id) do
    characters = map_id |> get_map!() |> Map.get(:characters, [])

    case characters |> Enum.member?(character_id) do
      true ->
        map_id
        |> update_map(%{characters: Enum.reject(characters, fn id -> id == character_id end)})

        :ok

      _ ->
        :ok
    end
  end

  def check_location(map_id, location) do
    case find_system_by_location(map_id, location) do
      nil ->
        {:ok, location}

      %{} ->
        {:error, :already_exists}
    end
  end

  def find_system_by_location(_map_id, nil), do: nil

  def find_system_by_location(map_id, %{solar_system_id: solar_system_id} = _location) do
    case map_id |> get_map!() |> Map.get(:systems, Map.new()) |> Map.get(solar_system_id) do
      nil ->
        nil

      %{visible: true} = system ->
        system

      _ ->
        nil
    end
  end

  def check_connection(
        map_id,
        %{solar_system_id: solar_system_id} = _location,
        %{solar_system_id: old_solar_system_id} = _old_location
      ) do
    case map_id
         |> get_map!()
         |> Map.get(:connections, Map.new())
         |> is_connection_exist?(%{
           solar_system_source: solar_system_id,
           solar_system_target: old_solar_system_id
         }) do
      true ->
        {:error, :already_exists}

      _ ->
        :ok
    end
  end

  def update_subscription_settings!(%{map_id: map_id} = map, %{
        characters_limit: characters_limit,
        hubs_limit: hubs_limit
      }) do
    map_id
    |> update_map(%{characters_limit: characters_limit, hubs_limit: hubs_limit})

    map
  end

  def add_systems!(map, []), do: map

  def add_systems!(%{map_id: map_id} = map, [system | rest]) do
    :ok = add_system(map_id, system)
    add_systems!(map, rest)
  end

  def add_system(map_id, %{solar_system_id: solar_system_id} = system) do
    systems = map_id |> get_map!() |> Map.get(:systems, Map.new())

    case not Map.has_key?(systems, solar_system_id) do
      true ->
        map_id
        |> update_map(%{systems: Map.put_new(systems, solar_system_id, system)})

        :ok

      _ ->
        :ok
    end
  end

  def update_system_by_solar_system_id(
        map_id,
        update
      ) do
    updated_systems =
      map_id |> get_map!() |> Map.get(:systems, Map.new()) |> update_by_solar_system_id(update)

    map_id
    |> update_map(%{systems: updated_systems})

    :ok
  end

  def remove_system(map_id, solar_system_id) do
    systems = map_id |> get_map!() |> Map.get(:systems, Map.new())

    case systems |> Map.get(solar_system_id) do
      nil ->
        :ok

      _system ->
        map_id
        |> update_map(%{systems: Map.drop(systems, [solar_system_id])})

        :ok
    end
  end

  def remove_systems(_map_id, []), do: :ok

  def remove_systems(map_id, [solar_system_id | rest]) do
    :ok = remove_system(map_id, solar_system_id)
    remove_systems(map_id, rest)
  end

  def add_hub(map_id, %{solar_system_id: solar_system_id} = _hub_info) do
    hubs = map_id |> get_map!() |> Map.get(:hubs, [])

    case hubs |> Enum.member?("#{solar_system_id}") do
      false ->
        map_id
        |> update_map(%{hubs: ["#{solar_system_id}" | hubs]})

        :ok

      _ ->
        :ok
    end
  end

  def remove_hub(map_id, %{solar_system_id: solar_system_id} = _hub_info) do
    hubs = map_id |> get_map!() |> Map.get(:hubs, [])

    case hubs |> Enum.member?("#{solar_system_id}") do
      true ->
        map_id
        |> update_map(%{hubs: Enum.reject(hubs, fn hub -> hub == "#{solar_system_id}" end)})

        :ok

      _ ->
        :ok
    end
  end

  def add_connections!(map, []), do: map

  def add_connections!(%{map_id: map_id} = map, [connection | rest]) do
    case add_connection(map_id, connection) do
      :ok ->
        add_connections!(map, rest)

      {:error, :already_exists} ->
        connection
        |> WandererApp.MapConnectionRepo.destroy!()

        add_connections!(map, rest)
    end
  end

  def add_connection(
        map_id,
        %{solar_system_source: solar_system_source, solar_system_target: solar_system_target} =
          connection
      ) do
    connections = map_id |> get_map!() |> Map.get(:connections, Map.new())

    case not (connections |> is_connection_exist?(connection)) do
      true ->
        map_id
        |> update_map(%{
          connections:
            Map.put_new(connections, "#{solar_system_source}_#{solar_system_target}", connection)
        })

        :ok

      _ ->
        :ok
    end
  end

  def is_connection_exist?(
        connections,
        %{solar_system_source: solar_system_source, solar_system_target: solar_system_target} =
          _connection
      ) do
    connections |> Map.has_key?("#{solar_system_source}_#{solar_system_target}") or
      connections |> Map.has_key?("#{solar_system_target}_#{solar_system_source}")
  end

  def update_connection(
        map_id,
        %{solar_system_source: solar_system_source, solar_system_target: solar_system_target} =
          connection
      ) do
    connections = map_id |> get_map!() |> Map.get(:connections, Map.new())

    map_id
    |> update_map(%{
      connections:
        Map.put(connections, "#{solar_system_source}_#{solar_system_target}", connection)
    })

    :ok
  end

  def remove_connection(
        map_id,
        %{solar_system_source: solar_system_source, solar_system_target: solar_system_target} =
          _connection
      ) do
    connections = map_id |> get_map!() |> Map.get(:connections, Map.new())

    map_id
    |> update_map(%{
      connections: Map.drop(connections, ["#{solar_system_source}_#{solar_system_target}"])
    })

    :ok
  end

  def remove_connections(_map_id, []), do: :ok

  def remove_connections(map_id, [connection | rest]) do
    :ok = remove_connection(map_id, connection)
    remove_connections(map_id, rest)
  end

  def find_connections(map_id, solar_system_id),
    do:
      map_id
      |> list_connections!()
      |> filter(
        %{solar_system_source: solar_system_id, solar_system_target: solar_system_id},
        match: :any
      )

  def find_connection(
        map_id,
        solar_system_source,
        solar_system_target
      ) do
    case map_id
         |> get_map!()
         |> Map.get(:connections, Map.new())
         |> Map.get("#{solar_system_source}_#{solar_system_target}") do
      nil ->
        {:ok,
         map_id
         |> get_map!()
         |> Map.get(:connections, Map.new())
         |> Map.get("#{solar_system_target}_#{solar_system_source}")}

      connection ->
        {:ok, connection}
    end
  end

  def get_by_id(list, id) do
    case find(list, %{id: id}, match: :any) do
      %{} = item -> {:ok, item}
      nil -> {:error, :item_not_found}
    end
  end

  def find(list, %{} = attrs, match: :any) do
    list
    |> Enum.find(fn item ->
      Enum.any?(attrs, &has_equal_attribute?(item, &1))
    end)
  end

  def find(list, %{} = attrs, match: :all) do
    list
    |> Enum.find(fn item ->
      Enum.all?(attrs, &has_equal_attribute?(item, &1))
    end)
  end

  def filter(list, %{} = attrs, match: :any) do
    list
    |> Enum.filter(fn item ->
      Enum.any?(attrs, &has_equal_attribute?(item, &1))
    end)
  end

  defp has_equal_attribute?(%{} = map, {key, {:case_insensitive, value}}) when is_binary(value) do
    String.downcase(Map.get(map, key, "")) == String.downcase(value)
  end

  defp has_equal_attribute?(%{} = map, {key, value}) do
    Map.get(map, key) == value
  end

  defp update_by_solar_system_id(systems, %{solar_system_id: solar_system_id} = item) do
    case systems |> Map.get(solar_system_id) do
      nil ->
        systems

      system ->
        systems |> Map.put(solar_system_id, system |> Map.merge(item))
    end
  end

  defp _maybe_limit_list(list, nil), do: list
  defp _maybe_limit_list(list, limit), do: Enum.take(list, limit)
end
