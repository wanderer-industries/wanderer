defmodule WandererApp.CachedInfo do
  require Logger

  @ship_cache  :ship_types_cache
  @ship_fields [
    :type_id,
    :group_id,
    :group_name,
    :name,
    :description,
    :mass,
    :capacity,
    :volume
  ]

  def run(_arg) do
    :ok = cache_trig_systems()
  end

  @doc """
  Fetch a ship type by ID, backed by Cachex.

  On cache miss we:
    1. Load *all* types from the primary API,
    2. Cache them all,
    3. Return the requested one (if found),
    4. Otherwise fall back to ESI for that single type.
  """
  @spec get_ship_type(integer()) :: {:ok, map() | nil} | {:error, term()}
  def get_ship_type(type_id) when is_integer(type_id) do
    with {:ok, nil} <- Cachex.get(@ship_cache, type_id),
         {:ok, ship_types} <- WandererApp.Api.ShipTypeInfo.read(),
         :ok <- cache_all_ship_types(ship_types) do
      case Enum.find(ship_types, &(&1.type_id == type_id)) do
        nil -> fetch_and_cache_single_ship_type(type_id)
        ship -> {:ok, ship}
      end
    else
      # Cache hit
      {:ok, ship} when not is_nil(ship) ->
        {:ok, ship}

      # Missed both primary cache & primary API list
      {:ok, nil} ->
        fetch_and_cache_single_ship_type(type_id)

      # Propagate errors
      {:error, reason} ->
        {:error, reason}
    end
  end

  # -- Private helpers for get_ship_type/1 -------------------------

  # Cache the full list of ship_types in one go
  defp cache_all_ship_types(ship_types) do
    ship_types
    |> Enum.reduce_while(:ok, fn ship, :ok ->
      entry = Map.take(ship, @ship_fields)

      case Cachex.put(@ship_cache, ship.type_id, entry) do
        {:ok, _}       -> {:cont, :ok}
        {:error, err}  -> {:halt, {:error, err}}
      end
    end)
  end

  # On lookup failure, fetch one type from ESI + cache it
  defp fetch_and_cache_single_ship_type(type_id) do
    with {:ok, info} <- WandererApp.Esi.ApiClient.get_type_info(type_id),
         group_id = info["group_id"],
         {:ok, group_name} <- WandererApp.Esi.ApiClient.get_group_name(group_id) do
      ship = %{
        type_id:     type_id,
        group_id:    group_id,
        group_name:  group_name,
        name:        info["name"],
        description: info["description"],
        mass:        info["mass"],
        capacity:    info["capacity"],
        volume:      info["volume"]
      }

      Cachex.put(@ship_cache, type_id, ship, ttl: :timer.seconds(300))
      {:ok, ship}
    else
      {:error, :not_found} ->
        Logger.debug("[CachedInfo] Ship type #{type_id} not found in ESI")
        {:ok, nil}  # This is expected for invalid/missing ship types

      {:error, reason} = error ->
        Logger.warning("[CachedInfo] API error fetching ship type #{type_id}: #{inspect(reason)}")
        error  # Propagate the actual error instead of masking it

      other ->
        Logger.warning("[CachedInfo] Unexpected error fetching ship type #{type_id}: #{inspect(other)}")
        {:error, {:unexpected_error, other}}
    end
  end

  def get_system_static_info(solar_system_id) do
    case Cachex.get(:system_static_info_cache, solar_system_id) do
      {:ok, nil} ->
        case WandererApp.Api.MapSolarSystem.read() do
          {:ok, systems} ->
            systems
            |> Enum.each(fn system ->
              Cachex.put(
                :system_static_info_cache,
                system.solar_system_id,
                Map.take(system, [
                  :solar_system_id,
                  :region_id,
                  :constellation_id,
                  :solar_system_name,
                  :solar_system_name_lc,
                  :constellation_name,
                  :region_name,
                  :system_class,
                  :security,
                  :type_description,
                  :class_title,
                  :is_shattered,
                  :effect_name,
                  :effect_power,
                  :statics,
                  :wandering,
                  :triglavian_invasion_status,
                  :sun_type_id
                ])
              )
            end)

            Cachex.get(:system_static_info_cache, solar_system_id)

          {:error, reason} ->
            Logger.error("Failed to read solar systems from API: #{inspect(reason)}")
            {:error, :api_error}
        end

      {:ok, system_static_info} ->
        {:ok, system_static_info}

      {:error, reason} ->
        Logger.error("Failed to get system static info from cache: #{inspect(reason)}")
        {:error, :cache_error}
    end
  end

  def get_system_static_info!(solar_system_id) do
    case get_system_static_info(solar_system_id) do
      {:ok, system_static_info} ->
        system_static_info

      error ->
        Logger.error("Error loading system static info: #{inspect(error)}")
        nil
    end
  end

  def get_wormhole_types() do
    case WandererApp.Cache.lookup(:wormhole_types) do
      {:ok, nil} ->
        wormhole_types = WandererApp.EveDataService.load_wormhole_types()
        cache_items(wormhole_types, :wormhole_types)
        {:ok, wormhole_types}

      {:ok, wormhole_types} ->
        {:ok, wormhole_types}
    end
  end

  def get_wormhole_types!() do
    case get_wormhole_types() do
      {:ok, wormhole_types} ->
        wormhole_types

      error ->
        Logger.error("Error loading wormhole types: #{inspect(error)}")
        error
    end
  end

  def get_wormhole_classes() do
    case WandererApp.Cache.lookup(:wormhole_classes) do
      {:ok, nil} ->
        wormhole_classes = WandererApp.EveDataService.load_wormhole_classes()
        cache_items(wormhole_classes, :wormhole_classes)
        {:ok, wormhole_classes}

      {:ok, wormhole_classes} ->
        {:ok, wormhole_classes}
    end
  end

  def get_wormhole_classes!() do
    case get_wormhole_classes() do
      {:ok, wormhole_classes} ->
        wormhole_classes

      error ->
        Logger.error("Error loading wormhole classes: #{inspect(error)}")
        error
    end
  end

  def get_effects() do
    case WandererApp.Cache.lookup(:effects) do
      {:ok, nil} ->
        effects = WandererApp.EveDataService.load_effects()
        cache_items(effects, :effects)
        {:ok, effects}

      {:ok, effects} ->
        {:ok, effects}
    end
  end

  def get_effects!() do
    case get_effects() do
      {:ok, effects} ->
        effects

      error ->
        Logger.error("Error loading effects: #{inspect(error)}")
        error
    end
  end

  def get_wh_class_a_systems() do
    case WandererApp.Cache.lookup(:wh_class_a_systems) do
      {:ok, nil} ->
        {:ok, wh_class_a} = WandererApp.Api.MapSolarSystem.get_wh_class_a()
        wh_class_a_ids = Enum.map(wh_class_a, & &1.solar_system_id)
        cache_items(wh_class_a_ids, :wh_class_a_systems)
        {:ok, wh_class_a_ids}

      {:ok, wh_class_a_ids} ->
        {:ok, wh_class_a_ids}
    end
  end

  def get_trig_systems() do
    case WandererApp.Cache.lookup(:trig_systems) do
      {:ok, nil} ->
        {:ok, trig_systems} = WandererApp.Api.MapSolarSystem.get_trig_systems()
        cache_items(trig_systems, :trig_systems)
        {:ok, trig_systems}

      {:ok, trig_systems} ->
        {:ok, trig_systems}
    end
  end

  defp cache_trig_systems() do
    trig_systems = WandererApp.Api.MapSolarSystem.get_trig_systems!()

    trig_systems
    |> Enum.filter(&(&1.triglavian_invasion_status == "Final"))
    |> Enum.map(& &1.solar_system_id)
    |> cache_items(:pochven_solar_systems)

    trig_systems
    |> Enum.filter(&(&1.triglavian_invasion_status == "Triglavian"))
    |> Enum.map(& &1.solar_system_id)
    |> cache_items(:triglavian_solar_systems)

    trig_systems
    |> Enum.filter(&(&1.triglavian_invasion_status == "Edencom"))
    |> Enum.map(& &1.solar_system_id)
    |> cache_items(:edencom_solar_systems)
  end

  defp cache_items([], _list_name), do: :ok
  defp cache_items(items, list_name),    do: WandererApp.Cache.put(list_name, items)
end
