defmodule WandererApp.Map do
  @moduledoc """
  Represents the map structure and exposes actions that can be taken to update
  it
  """
  import Ecto.Query

  require Logger

  defstruct map_id: nil,
            name: nil,
            scope: :none,
            owner_id: nil,
            characters: [],
            systems: Map.new(),
            hubs: [],
            connections: Map.new(),
            acls: [],
            options: Map.new(),
            characters_limit: nil,
            hubs_limit: nil

  def new(%{id: map_id, name: name, scope: scope, owner_id: owner_id, acls: acls, hubs: hubs}) do
    map =
      struct!(__MODULE__,
        map_id: map_id,
        scope: scope,
        owner_id: owner_id,
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
    do: {:ok, map_id |> get_map!() |> Map.get(:characters_limit, 50)}

  def get_hubs_limit(map_id),
    do: {:ok, map_id |> get_map!() |> Map.get(:hubs_limit, 20)}

  def is_subscription_active?(map_id),
    do: is_subscription_active?(map_id, WandererApp.Env.map_subscriptions_enabled?())

  def is_subscription_active?(_map_id, false), do: {:ok, true}

  def is_subscription_active?(map_id, _map_subscriptions_enabled) do
    {:ok, %{plan: plan}} = WandererApp.Map.SubscriptionManager.get_active_map_subscription(map_id)
    {:ok, plan != :alpha}
  end

  def get_options(map_id),
    do: {:ok, map_id |> get_map!() |> Map.get(:options, Map.new())}

  @doc """
  Returns a full list of characters in the map
  """
  def list_characters(map_id),
    do:
      map_id
      |> get_map!()
      |> Map.get(:characters, [])
      |> Enum.map(fn character_id ->
        WandererApp.Character.get_map_character!(map_id, character_id)
      end)

  def list_systems(map_id),
    do: {:ok, map_id |> get_map!() |> Map.get(:systems, Map.new()) |> Map.values()}

  def list_systems!(map_id) do
    {:ok, systems} = list_systems(map_id)
    systems
  end

  def list_hubs(map_id) do
    {:ok, map} = map_id |> get_map()

    {:ok, map |> Map.get(:hubs, [])}
  end

  def list_hubs(map_id, hubs) do
    {:ok, map} = map_id |> get_map()

    {:ok, hubs}
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
    add_character(map_id, character)
    add_characters!(map, rest)
  end

  def add_character(
        map_id,
        %{
          id: character_id
        } = _character
      ) do
    characters = map_id |> get_map!() |> Map.get(:characters, [])

    case not (characters |> Enum.member?(character_id)) do
      true ->
        WandererApp.Character.get_map_character(map_id, character_id)
        |> case do
          {:ok,
           %{
             alliance_id: alliance_id,
             corporation_id: corporation_id,
             solar_system_id: solar_system_id,
             structure_id: structure_id,
             station_id: station_id,
             ship: ship_type_id,
             ship_name: ship_name
           }} ->
            map_id
            |> update_map(%{characters: [character_id | characters]})

            # WandererApp.Cache.insert(
            #   "map:#{map_id}:character:#{character_id}:alliance_id",
            #   alliance_id
            # )

            # WandererApp.Cache.insert(
            #   "map:#{map_id}:character:#{character_id}:corporation_id",
            #   corporation_id
            # )

            # WandererApp.Cache.insert(
            #   "map:#{map_id}:character:#{character_id}:solar_system_id",
            #   solar_system_id
            # )

            # WandererApp.Cache.insert(
            #   "map:#{map_id}:character:#{character_id}:structure_id",
            #   structure_id
            # )

            # WandererApp.Cache.insert(
            #   "map:#{map_id}:character:#{character_id}:station_id",
            #   station_id
            # )

            # WandererApp.Cache.insert(
            #   "map:#{map_id}:character:#{character_id}:ship_type_id",
            #   ship_type_id
            # )

            # WandererApp.Cache.insert(
            #   "map:#{map_id}:character:#{character_id}:ship_name",
            #   ship_name
            # )

            :ok

          error ->
            error
        end

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
        |> update_map(%{characters: characters |> Enum.reject(fn id -> id == character_id end)})

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

      _system ->
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

    map_id
    |> get_map!()
  end

  def update_options!(%{map_id: map_id} = map, options) do
    map_id
    |> update_map(%{options: options})

    map_id
    |> get_map!()
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
        |> update_map(%{systems: Map.put(systems, solar_system_id, system)})

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

  @doc """
  Returns the raw activity data that can be processed by WandererApp.Character.Activity.
  Only includes characters that are on the map's ACL.
  If days parameter is provided, filters activity to that time period.
  """
  def get_character_activity(map_id, days \\ nil) do
    with {:ok, map} <- WandererApp.Api.Map.by_id(map_id) do
      _map_with_acls = Ash.load!(map, :acls)

      # Calculate cutoff date if days is provided
      cutoff_date =
        if days, do: DateTime.utc_now() |> DateTime.add(-days * 24 * 3600, :second), else: nil

      # Get activity data
      passages_activity = get_passages_activity(map_id, cutoff_date)
      connections_activity = get_connections_activity(map_id, cutoff_date)
      signatures_activity = get_signatures_activity(map_id, cutoff_date)

      # Return activity data
      result =
        passages_activity
        |> Enum.map(fn passage ->
          %{
            character: passage.character,
            passages: passage.count,
            connections: Map.get(connections_activity, passage.character.id, 0),
            signatures: Map.get(signatures_activity, passage.character.id, 0),
            timestamp: DateTime.utc_now(),
            character_id: passage.character.id,
            user_id: passage.character.user_id
          }
        end)

      {:ok, result}
    end
  end

  defp get_passages_activity(map_id, nil) do
    # Query all map chain passages without time filter
    from(p in WandererApp.Api.MapChainPassages,
      join: c in assoc(p, :character),
      where: p.map_id == ^map_id,
      group_by: [c.id],
      select: {c, count(p.id)}
    )
    |> WandererApp.Repo.all()
    |> Enum.map(fn {character, count} -> %{character: character, count: count} end)
  end

  defp get_passages_activity(map_id, cutoff_date) do
    # Query map chain passages with time filter
    from(p in WandererApp.Api.MapChainPassages,
      join: c in assoc(p, :character),
      where:
        p.map_id == ^map_id and
          p.inserted_at > ^cutoff_date,
      group_by: [c.id],
      select: {c, count(p.id)}
    )
    |> WandererApp.Repo.all()
    |> Enum.map(fn {character, count} -> %{character: character, count: count} end)
  end

  defp get_connections_activity(map_id, nil) do
    # Query all connection activity without time filter
    from(ua in WandererApp.Api.UserActivity,
      join: c in assoc(ua, :character),
      where:
        ua.entity_id == ^map_id and
          ua.entity_type == :map and
          ua.event_type == :map_connection_added,
      group_by: [c.id],
      select: {c.id, count(ua.id)}
    )
    |> WandererApp.Repo.all()
    |> Map.new()
  end

  defp get_connections_activity(map_id, cutoff_date) do
    from(ua in WandererApp.Api.UserActivity,
      join: c in assoc(ua, :character),
      where:
        ua.entity_id == ^map_id and
          ua.entity_type == :map and
          ua.event_type == :map_connection_added and
          ua.inserted_at > ^cutoff_date,
      group_by: [c.id],
      select: {c.id, count(ua.id)}
    )
    |> WandererApp.Repo.all()
    |> Map.new()
  end

  defp get_signatures_activity(map_id, nil) do
    # Query all signature activity without time filter
    from(ua in WandererApp.Api.UserActivity,
      join: c in assoc(ua, :character),
      where:
        ua.entity_id == ^map_id and
          ua.entity_type == :map and
          ua.event_type == :signatures_added,
      select: {ua.character_id, ua.event_data}
    )
    |> WandererApp.Repo.all()
    |> process_signatures_data()
  end

  defp get_signatures_activity(map_id, cutoff_date) do
    from(ua in WandererApp.Api.UserActivity,
      join: c in assoc(ua, :character),
      where:
        ua.entity_id == ^map_id and
          ua.entity_type == :map and
          ua.event_type == :signatures_added and
          ua.inserted_at > ^cutoff_date,
      select: {ua.character_id, ua.event_data}
    )
    |> WandererApp.Repo.all()
    |> process_signatures_data()
  end

  defp process_signatures_data(signatures_data) do
    signatures_data
    |> Enum.group_by(fn {character_id, _} -> character_id end)
    |> Enum.map(&process_character_signatures/1)
    |> Map.new()
  end

  defp process_character_signatures({character_id, activities}) do
    signature_count =
      activities
      |> Enum.map(fn {_, event_data} ->
        case Jason.decode(event_data) do
          {:ok, data} -> length(Map.get(data, "signatures", []))
          _ -> 0
        end
      end)
      |> Enum.sum()

    {character_id, signature_count}
  end
end
