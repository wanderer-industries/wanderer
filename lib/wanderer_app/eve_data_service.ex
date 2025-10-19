defmodule WandererApp.EveDataService do
  @moduledoc """
  Service for loading data from the EVE DB dumps & JSON files
  """

  require Logger

  alias WandererApp.Utils.JSONUtil

  @eve_db_dump_url "https://www.fuzzwork.co.uk/dump/latest"

  @dump_file_names [
    "invGroups.csv",
    "invTypes.csv",
    "mapConstellations.csv",
    "mapRegions.csv",
    "mapLocationWormholeClasses.csv",
    "mapSolarSystems.csv",
    "mapSolarSystemJumps.csv"
  ]

  def update_eve_data() do
    download_files()

    Logger.info("Downloading files finished!")

    get_db_data()
    |> Ash.bulk_create(WandererApp.Api.MapSolarSystem, :create)

    Logger.info("MapSolarSystem updated!")

    get_ship_types_data()
    |> Ash.bulk_create(WandererApp.Api.ShipTypeInfo, :create)

    Logger.info("ShipTypeInfo updated!")

    get_solar_system_jumps_data()
    |> Ash.bulk_create(WandererApp.Api.MapSolarSystemJumps, :create)

    Logger.info("MapSolarSystemJumps updated!")

    cleanup_files()
  end

  def load_wormhole_types() do
    JSONUtil.read_json!("#{:code.priv_dir(:wanderer_app)}/repo/data/wormholes.json")
    |> Enum.map(fn row ->
      %{
        id: row["typeID"],
        name: row["name"],
        src: row["src"],
        dest: row["dest"],
        total_mass: row["total_mass"],
        lifetime: row["lifetime"],
        max_mass_per_jump: row["max_mass_per_jump"],
        static: row["static"],
        mass_regen: row["mass_regen"],
        sibling_groups: row["sibling_groups"],
        respawn: row["respawn"]
      }
    end)
  end

  def load_wormhole_classes() do
    JSONUtil.read_json!("#{:code.priv_dir(:wanderer_app)}/repo/data/wormholeClasses.json")
    |> Enum.map(fn row ->
      %{
        id: row["id"],
        short_name: row["shortName"],
        short_title: row["shortTitle"],
        title: row["title"],
        effect_power: row |> Map.get("effectPower", 0),
        wormhole_class_id: row["wormholeClassID"]
      }
    end)
  end

  def load_wormhole_systems() do
    JSONUtil.read_json!("#{:code.priv_dir(:wanderer_app)}/repo/data/wormholeSystems.json")
    |> Enum.map(fn row ->
      %{
        solar_system_id: row["solarSystemID"],
        wanderers: row["wanderers"],
        statics: row["statics"],
        system_name: row["systemName"],
        effect_name: row["effectName"]
      }
    end)
  end

  def load_effects() do
    JSONUtil.read_json!("#{:code.priv_dir(:wanderer_app)}/repo/data/effects.json")
    |> Enum.map(fn row ->
      %{
        id: row["name"] |> Slug.slugify(),
        name: row["name"],
        modifiers:
          row["modifiers"]
          |> Enum.map(fn m ->
            %{
              name: m["name"],
              positive: m["positive"],
              power: m["power"]
            }
          end)
      }
    end)
  end

  def load_triglavian_systems() do
    JSONUtil.read_json!("#{:code.priv_dir(:wanderer_app)}/repo/data/triglavianSystems.json")
    |> Enum.map(fn row ->
      %{
        solar_system_id: row["solarSystemID"],
        solar_system_name: row["solarSystemName"],
        effect_name: row["effectName"],
        effect_power: row["effectPower"],
        invasion_status: row["invasionStatus"]
      }
    end)
  end

  def load_wormhole_classes_info() do
    {:ok, data} =
      JSONUtil.read_json("#{:code.priv_dir(:wanderer_app)}/repo/data/wormholeClassesInfo.json")

    %{
      names: data["names"],
      classes: data["classes"]
    }
  end

  def load_shattered_constellations() do
    {:ok, data} =
      JSONUtil.read_json(
        "#{:code.priv_dir(:wanderer_app)}/repo/data/shatteredConstellations.json"
      )

    data
  end

  defp cleanup_files() do
    tasks =
      @dump_file_names
      |> Enum.map(fn file_name ->
        Task.async(fn ->
          cleanup_file(file_name)
        end)
      end)

    Task.await_many(tasks, :timer.minutes(30))
  end

  defp cleanup_file(file_name) do
    Logger.info("Cleaning file: #{file_name}")

    download_path = Path.join([:code.priv_dir(:wanderer_app), "repo", "data", file_name])

    :ok = File.rm(download_path)

    Logger.info("File removed successfully to #{download_path}")

    :ok
  end

  defp download_files() do
    tasks =
      @dump_file_names
      |> Enum.map(fn file_name ->
        Task.async(fn ->
          download_file(file_name)
        end)
      end)

    Task.await_many(tasks, :timer.minutes(30))
  end

  defp download_file(file_name) do
    url = "#{@eve_db_dump_url}/#{file_name}"
    Logger.info("Downloading file from #{url}")

    download_path = Path.join([:code.priv_dir(:wanderer_app), "repo", "data", file_name])

    Req.get!(url, raw: true, into: File.stream!(download_path, [:write])).body
    |> Stream.run()

    Logger.info("File downloaded successfully to #{download_path}")

    :ok
  end

  defp load_map_constellations() do
    WandererApp.Utils.CSVUtil.csv_row_to_table_record(
      "#{:code.priv_dir(:wanderer_app)}/repo/data/mapConstellations.csv",
      fn row ->
        %{
          constellation_id: row["constellationID"] |> Integer.parse() |> elem(0),
          constellation_name: row["constellationName"]
        }
      end
    )
  end

  defp load_map_regions() do
    WandererApp.Utils.CSVUtil.csv_row_to_table_record(
      "#{:code.priv_dir(:wanderer_app)}/repo/data/mapRegions.csv",
      fn row ->
        %{
          region_id: row["regionID"] |> Integer.parse() |> elem(0),
          region_name: row["regionName"]
        }
      end
    )
  end

  defp load_map_location_wormhole_classes() do
    WandererApp.Utils.CSVUtil.csv_row_to_table_record(
      "#{:code.priv_dir(:wanderer_app)}/repo/data/mapLocationWormholeClasses.csv",
      fn row ->
        %{
          location_id: row["locationID"],
          wormhole_class_id: row["wormholeClassID"]
        }
      end
    )
  end

  defp load_inv_groups() do
    WandererApp.Utils.CSVUtil.csv_row_to_table_record(
      "#{:code.priv_dir(:wanderer_app)}/repo/data/invGroups.csv",
      fn row ->
        %{
          group_id: row["groupID"] |> Integer.parse() |> elem(0),
          group_name: row["groupName"],
          category_id: row["categoryID"] |> Integer.parse() |> elem(0)
        }
      end
    )
  end

  defp get_db_data() do
    map_constellations = load_map_constellations()
    map_regions = load_map_regions()
    map_location_wormhole_classes = load_map_location_wormhole_classes()
    wormhole_classes = load_wormhole_classes()
    wormhole_systems = load_wormhole_systems()

    triglavian_systems = load_triglavian_systems()
    wormhole_classes_info = load_wormhole_classes_info()
    shattered_constellations = load_shattered_constellations()

    WandererApp.Utils.CSVUtil.csv_row_to_table_record(
      "#{:code.priv_dir(:wanderer_app)}/repo/data/mapSolarSystems.csv",
      fn row ->
        solar_system_id = row["solarSystemID"] |> Integer.parse() |> elem(0)
        region_id = row["regionID"] |> Integer.parse() |> elem(0)
        constellation_id = row["constellationID"] |> Integer.parse() |> elem(0)
        solar_system_name = row["solarSystemName"]

        {:ok, wormhole_class_id} =
          get_wormhole_class_id(
            map_location_wormhole_classes,
            region_id,
            constellation_id,
            solar_system_id
          )

        {:ok, constellation_name} =
          get_constellation_name(map_constellations, constellation_id)

        {:ok, region_name} = get_region_name(map_regions, region_id)

        {:ok, wormhole_class} = get_wormhole_class(wormhole_classes, wormhole_class_id)

        {:ok, security} = get_security(row["security"])

        {:ok, class_title} =
          get_class_title(
            wormhole_classes_info,
            wormhole_class_id,
            security,
            wormhole_class
          )

        {:ok, solar_system_name} =
          get_system_name(
            wormhole_classes_info,
            wormhole_class_id,
            solar_system_name,
            wormhole_class
          )

        is_shattered =
          case Map.get(shattered_constellations, constellation_id |> Integer.to_string()) do
            nil -> false
            _ -> true
          end

        %{
          effect_power: 0,
          effect_name: "",
          statics: [],
          wandering: [],
          triglavian_invasion_status: "Normal",
          constellation_id: constellation_id,
          region_id: region_id,
          solar_system_id: solar_system_id,
          solar_system_name: solar_system_name,
          solar_system_name_lc: solar_system_name |> String.downcase(),
          sun_type_id: get_sun_type_id(row["sunTypeID"]),
          constellation_name: constellation_name,
          region_name: region_name,
          security: security,
          system_class: wormhole_class_id,
          class_title: class_title,
          type_description: wormhole_class.title,
          is_shattered: is_shattered
        }
        |> get_wormhole_data(wormhole_systems, solar_system_id, wormhole_class)
        |> get_triglavian_data(triglavian_systems, solar_system_id)
      end
    )
  end

  defp get_ship_types_data() do
    inv_groups = load_inv_groups()

    ship_type_groups =
      inv_groups
      |> Enum.filter(fn g -> g.category_id == 6 end)
      |> Enum.map(fn g -> g.group_id end)

    WandererApp.Utils.CSVUtil.csv_row_to_table_record(
      "#{:code.priv_dir(:wanderer_app)}/repo/data/invTypes.csv",
      fn row ->
        group_id = row["groupID"] |> Integer.parse() |> elem(0)

        inv_group =
          case Enum.find(inv_groups, fn group ->
                 group.group_id == group_id
               end) do
            nil -> %{}
            group -> group
          end

        %{
          type_id: row["typeID"] |> Integer.parse() |> elem(0),
          group_id: group_id,
          name: row["typeName"],
          mass: row["mass"],
          volume: row["volume"],
          capacity: row["capacity"],
          group_name: inv_group.group_name
        }
      end
    )
    |> Enum.filter(fn t -> t.group_id in ship_type_groups end)
  end

  defp get_solar_system_jumps_data() do
    WandererApp.Utils.CSVUtil.csv_row_to_table_record(
      "#{:code.priv_dir(:wanderer_app)}/repo/data/mapSolarSystemJumps.csv",
      fn row ->
        %{
          from_solar_system_id: row["fromSolarSystemID"] |> Integer.parse() |> elem(0),
          to_solar_system_id: row["toSolarSystemID"] |> Integer.parse() |> elem(0)
        }
      end
    )
  end

  defp get_sun_type_id(sun_type_id) do
    case sun_type_id do
      nil -> 0
      "None" -> 0
      _ -> sun_type_id |> Integer.parse() |> elem(0)
    end
  end

  defp get_wormhole_data(default_data, wormhole_systems, solar_system_id, wormhole_class) do
    case Enum.find(wormhole_systems, fn system -> system.solar_system_id == solar_system_id end) do
      nil ->
        default_data

      wormhole_data ->
        %{
          default_data
          | effect_power: wormhole_class.effect_power,
            effect_name: wormhole_data.effect_name,
            statics: wormhole_data.statics,
            wandering: wormhole_data.wanderers
        }
    end
  end

  defp get_solar_system_name(solar_system_name, wormhole_class) do
  end

  defp get_triglavian_data(default_data, triglavian_systems, solar_system_id) do
    case Enum.find(triglavian_systems, fn system -> system.solar_system_id == solar_system_id end) do
      nil ->
        default_data

      triglavian_data ->
        %{
          default_data
          | triglavian_invasion_status: triglavian_data.invasion_status,
            effect_name: triglavian_data.effect_name,
            effect_power: triglavian_data.effect_power
        }
    end
  end

  defp get_security(security) do
    case security do
      nil -> {:ok, ""}
      _ -> {:ok, String.to_float(security) |> get_true_security() |> Float.to_string(decimals: 1)}
    end
  end

  defp truncate_to_two_digits(value) when is_float(value), do: Float.floor(value * 100) / 100

  defp get_true_security(security) when is_float(security) and security > 0.0 and security < 0.05,
    do: security |> Float.ceil(1)

  defp get_true_security(security) when is_float(security) do
    truncated_value = security |> truncate_to_two_digits()
    floor_value = truncated_value |> Float.floor(1)

    if Float.round(truncated_value - floor_value, 2) < 0.05 do
      floor_value
    else
      Float.ceil(truncated_value, 1)
    end
  end

  defp get_system_name(
         wormhole_classes_info,
         wormhole_class_id,
         solar_system_name,
         wormhole_class
       ) do
    case wormhole_class_id in [
           wormhole_classes_info.names["sentinel"],
           wormhole_classes_info.names["barbican"],
           wormhole_classes_info.names["vidette"],
           wormhole_classes_info.names["conflux"],
           wormhole_classes_info.names["redoubt"]
         ] do
      true ->
        {:ok, wormhole_class.short_title}

      _ ->
        {:ok, solar_system_name}
    end
  end

  defp get_class_title(wormhole_classes_info, wormhole_class_id, security, wormhole_class) do
    case wormhole_class_id in [
           wormhole_classes_info.names["hs"],
           wormhole_classes_info.names["ls"],
           wormhole_classes_info.names["ns"]
         ] do
      true ->
        {:ok, security}

      _ ->
        {:ok, wormhole_class.short_name}
    end
  end

  defp get_constellation_name(constellations, constellation_id) do
    case Enum.find(constellations, fn constellation ->
           constellation.constellation_id == constellation_id
         end) do
      nil -> {:ok, ""}
      constellation -> {:ok, constellation.constellation_name}
    end
  end

  defp get_region_name(regions, region_id) do
    case Enum.find(regions, fn region -> region.region_id == region_id end) do
      nil -> {:ok, ""}
      region -> {:ok, region.region_name}
    end
  end

  defp get_wormhole_class(wormhole_classes, wormhole_class_id) do
    {:ok,
     Enum.find(wormhole_classes, fn wormhole_class ->
       wormhole_class.wormhole_class_id == wormhole_class_id
     end)}
  end

  defp get_wormhole_class_id(_systems, _region_id, _constellation_id, 30_100_000),
    do: {:ok, 10_100}

  defp get_wormhole_class_id(systems, region_id, constellation_id, solar_system_id) do
    with region <-
           Enum.find(systems, fn system ->
             system.location_id |> Integer.parse() |> elem(0) == region_id
           end),
         constellation <-
           Enum.find(systems, fn system ->
             system.location_id |> Integer.parse() |> elem(0) == constellation_id
           end),
         solar_system <-
           Enum.find(systems, fn system ->
             system.location_id |> Integer.parse() |> elem(0) == solar_system_id
           end),
         wormhole_class_id <- get_wormhole_class_id(region, constellation, solar_system) do
      {:ok, wormhole_class_id}
    else
      _ -> {:ok, -1}
    end
  end

  defp get_wormhole_class_id(_region, _constellation, solar_system)
       when not is_nil(solar_system),
       do: solar_system.wormhole_class_id |> Integer.parse() |> elem(0)

  defp get_wormhole_class_id(_region, constellation, _solar_system)
       when not is_nil(constellation),
       do: constellation.wormhole_class_id |> Integer.parse() |> elem(0)

  defp get_wormhole_class_id(region, _constellation, _solar_system) when not is_nil(region),
    do: region.wormhole_class_id |> Integer.parse() |> elem(0)

  defp get_wormhole_class_id(_region, _constellation, _solar_system), do: -1
end
