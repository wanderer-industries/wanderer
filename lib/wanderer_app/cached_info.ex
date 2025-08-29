defmodule WandererApp.CachedInfo do
  require Logger

  def run(_arg) do
    :ok = cache_trig_systems()
  end

  def get_ship_type(type_id) do
    case Cachex.get(:ship_types_cache, type_id) do
      {:ok, nil} ->
        {:ok, ship_types} = WandererApp.Api.ShipTypeInfo.read()

        ship_types
        |> Enum.each(fn ship_type ->
          Cachex.put(
            :ship_types_cache,
            ship_type.type_id,
            ship_type
            |> Map.take([
              :type_id,
              :group_id,
              :group_name,
              :name,
              :description,
              :mass,
              :capacity,
              :volume
            ])
          )
        end)

        Cachex.get(:ship_types_cache, type_id)

      {:ok, ship_type} ->
        {:ok, ship_type}
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

            case Cachex.get(:system_static_info_cache, solar_system_id) do
              {:ok, nil} -> {:error, :not_found}
              result -> result
            end

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

  def get_solar_system_jumps() do
    case WandererApp.Cache.lookup(:solar_system_jumps) do
      {:ok, nil} ->
        data = WandererApp.EveDataService.get_solar_system_jumps_data()

        cache_items(data, :solar_system_jumps)

        {:ok, data}

      {:ok, data} ->
        {:ok, data}
    end
  end

  def get_solar_system_jump(from_solar_system_id, to_solar_system_id) do
    # Create normalized cache key (smaller ID first for bidirectional lookup)
    {id1, id2} =
      if from_solar_system_id < to_solar_system_id do
        {from_solar_system_id, to_solar_system_id}
      else
        {to_solar_system_id, from_solar_system_id}
      end

    cache_key = "jump_#{id1}_#{id2}"

    case WandererApp.Cache.lookup(cache_key) do
      {:ok, nil} ->
        # Build jump index if not exists
        build_jump_index()
        WandererApp.Cache.lookup(cache_key)

      result ->
        result
    end
  end

  defp build_jump_index() do
    case get_solar_system_jumps() do
      {:ok, jumps} ->
        jumps
        |> Enum.each(fn jump ->
          {id1, id2} =
            if jump.from_solar_system_id < jump.to_solar_system_id do
              {jump.from_solar_system_id, jump.to_solar_system_id}
            else
              {jump.to_solar_system_id, jump.from_solar_system_id}
            end

          cache_key = "jump_#{id1}_#{id2}"
          WandererApp.Cache.put(cache_key, jump)
        end)

      _ ->
        :error
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

        wh_class_a_ids = wh_class_a |> Enum.map(& &1.solar_system_id)

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
    |> Enum.filter(fn s -> s.triglavian_invasion_status == "Final" end)
    |> Enum.map(& &1.solar_system_id)
    |> cache_items(:pochven_solar_systems)

    trig_systems
    |> Enum.filter(fn s -> s.triglavian_invasion_status == "Triglavian" end)
    |> Enum.map(& &1.solar_system_id)
    |> cache_items(:triglavian_solar_systems)

    trig_systems
    |> Enum.filter(fn s -> s.triglavian_invasion_status == "Edencom" end)
    |> Enum.map(& &1.solar_system_id)
    |> cache_items(:edencom_solar_systems)
  end

  defp cache_items([], _list_name), do: :ok

  defp cache_items(items, list_name), do: WandererApp.Cache.put(list_name, items)
end
