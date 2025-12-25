defmodule WandererApp.EveDataService do
  @moduledoc """
  Service for loading data from the EVE DB dumps & JSON files.

  ## SDE Data Sources

  This service supports multiple SDE (Static Data Export) sources:

  - `:wanderer_assets` - Primary source from wanderer-industries/wanderer-assets (default)
  - `:fuzzworks` - Legacy source from fuzzwork.co.uk (deprecated)

  Configure via environment variable `SDE_SOURCE` or in config:

      config :wanderer_app, :sde,
        source: :wanderer_assets

  ## Version Tracking

  When using wanderer_assets source, version information is tracked via
  `sde_metadata.json` and stored locally in `.sde_version` file.
  """

  require Logger

  alias WandererApp.SDE.Source
  alias WandererApp.SdeVersionRepo
  alias WandererApp.Utils.JSONUtil

  @dump_file_names [
    "invGroups.csv",
    "invTypes.csv",
    "mapConstellations.csv",
    "mapRegions.csv",
    "mapLocationWormholeClasses.csv",
    "mapSolarSystems.csv",
    "mapSolarSystemJumps.csv"
  ]

  @sde_version_file ".sde_version"

  # Timeout for metadata fetch requests (30 seconds)
  @metadata_receive_timeout :timer.seconds(30)

  # Timeout for file download requests (5 minutes per chunk for large files)
  @file_download_receive_timeout :timer.minutes(5)

  @doc """
  Updates EVE static data from the configured SDE source.

  Downloads all required CSV files, processes them, and populates the database
  with solar system, ship type, and system jump data.

  After a successful update, saves the SDE version (if available from source).
  """
  @spec update_eve_data() :: :ok | {:error, term()}
  def update_eve_data do
    source = Source.get_source()
    start_time = System.monotonic_time(:millisecond)
    Logger.info("Starting EVE data update from #{inspect(source)}")

    result =
      with :ok <- download_files(),
           _ = Logger.info("Downloading files finished!"),
           :ok <- bulk_create_solar_systems(),
           :ok <- bulk_create_ship_types(),
           :ok <- bulk_create_solar_system_jumps() do
        # Save version only after all creates succeed
        save_sde_version_from_source()
        cleanup_files()
        :ok
      end

    duration = System.monotonic_time(:millisecond) - start_time

    case result do
      :ok ->
        :telemetry.execute(
          [:wanderer_app, :sde, :update, :success],
          %{duration: duration},
          %{source: source}
        )

      {:error, reason} ->
        :telemetry.execute(
          [:wanderer_app, :sde, :update, :error],
          %{duration: duration},
          %{source: source, reason: reason}
        )
    end

    result
  end

  defp bulk_create_solar_systems do
    result =
      get_db_data()
      |> Ash.bulk_create(WandererApp.Api.MapSolarSystem, :create)

    case check_bulk_result(result, "MapSolarSystem") do
      :ok ->
        Logger.info("MapSolarSystem updated!")
        :ok

      {:error, _} = error ->
        error
    end
  end

  defp bulk_create_ship_types do
    result =
      get_ship_types_data()
      |> Ash.bulk_create(WandererApp.Api.ShipTypeInfo, :create)

    case check_bulk_result(result, "ShipTypeInfo") do
      :ok ->
        Logger.info("ShipTypeInfo updated!")
        :ok

      {:error, _} = error ->
        error
    end
  end

  defp bulk_create_solar_system_jumps do
    result =
      get_solar_system_jumps_data()
      |> Ash.bulk_create(WandererApp.Api.MapSolarSystemJumps, :create)

    case check_bulk_result(result, "MapSolarSystemJumps") do
      :ok ->
        Logger.info("MapSolarSystemJumps updated!")
        :ok

      {:error, _} = error ->
        error
    end
  end

  defp check_bulk_result(%Ash.BulkResult{status: :success}, _resource_name), do: :ok

  defp check_bulk_result(
         %Ash.BulkResult{status: status, errors: errors, error_count: error_count},
         resource_name
       )
       when status in [:error, :partial_success] do
    Logger.error(
      "Bulk create failed for #{resource_name}: status=#{status}, error_count=#{error_count}, errors=#{inspect(errors, limit: 10)}"
    )

    :telemetry.execute(
      [:wanderer_app, :sde, :bulk_create, :error],
      %{error_count: error_count || length(errors || [])},
      %{resource: resource_name, status: status, errors: summarize_errors(errors)}
    )

    {:error,
     {:bulk_create_failed, resource_name,
      %{status: status, error_count: error_count, errors: summarize_errors(errors)}}}
  end

  defp check_bulk_result(result, resource_name) do
    Logger.error(
      "Unexpected bulk create result for #{resource_name}: #{inspect(result, limit: 5)}"
    )

    {:error, {:unexpected_bulk_result, resource_name, result}}
  end

  defp summarize_errors(nil), do: []
  defp summarize_errors(errors) when is_list(errors), do: Enum.take(errors, 5)
  defp summarize_errors(errors), do: [errors]

  @doc """
  Returns information about the current SDE configuration and version.

  Returns a map with:
  - `:source` - The configured source module name
  - `:source_name` - Human-readable source name
  - `:version` - Current SDE version (if tracked)
  - `:last_updated` - When the SDE was last updated
  - `:base_url` - The base URL for the SDE source
  """
  @spec get_sde_info() :: map()
  def get_sde_info do
    source = Source.get_source()

    source_name =
      case source do
        WandererApp.SDE.WandererAssets -> "Wanderer Assets"
        WandererApp.SDE.Fuzzworks -> "Fuzzworks (Legacy)"
        _ -> "Unknown"
      end

    %{
      source: source,
      source_name: source_name,
      version: get_current_sde_version(),
      last_updated: get_sde_last_updated(),
      base_url: source.base_url()
    }
  end

  @doc """
  Checks if an SDE update is available from the remote source.

  Returns:
  - `{:ok, :up_to_date}` - Current version matches remote
  - `{:ok, :update_available, metadata}` - New version available
  - `{:ok, :update_available}` - Update check not supported (Fuzzworks)
  - `{:error, reason}` - Failed to check for updates
  """
  @spec check_for_updates() ::
          {:ok, :up_to_date}
          | {:ok, :update_available}
          | {:ok, :update_available, map()}
          | {:error, term()}
  def check_for_updates do
    source = Source.get_source()

    result =
      case source.metadata_url() do
        nil ->
          # Fuzzworks doesn't support version tracking
          {:ok, :update_available}

        url ->
          with {:ok, metadata} <- fetch_metadata(url) do
            current_version = get_current_sde_version()

            if metadata["sde_version"] != current_version do
              {:ok, :update_available, metadata}
            else
              {:ok, :up_to_date}
            end
          end
      end

    # Emit telemetry for update check
    status =
      case result do
        {:ok, :up_to_date} -> :up_to_date
        {:ok, :update_available} -> :update_available
        {:ok, :update_available, _} -> :update_available
        {:error, _} -> :error
      end

    :telemetry.execute(
      [:wanderer_app, :sde, :check],
      %{count: 1},
      %{source: source, status: status}
    )

    result
  end

  @doc """
  Fetches SDE metadata from the remote source.

  Only supported for wanderer_assets source.
  """
  @spec fetch_metadata(String.t()) :: {:ok, map()} | {:error, term()}
  def fetch_metadata(url) do
    Logger.debug("Fetching SDE metadata from #{url}")

    case Req.get(url, receive_timeout: @metadata_receive_timeout) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        {:ok, body}

      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        case Jason.decode(body) do
          {:ok, metadata} -> {:ok, metadata}
          {:error, reason} -> {:error, {:json_decode_error, reason}}
        end

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
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

  defp cleanup_files do
    tasks =
      @dump_file_names
      |> Enum.map(fn file_name ->
        Task.async(fn ->
          cleanup_file(file_name)
        end)
      end)

    Task.await_many(tasks, :timer.seconds(30))
  end

  defp cleanup_file(file_name) do
    Logger.info("Cleaning file: #{file_name}")

    download_path = Path.join([:code.priv_dir(:wanderer_app), "repo", "data", file_name])

    :ok = File.rm(download_path)

    Logger.info("File removed successfully to #{download_path}")

    :ok
  end

  defp download_files do
    source = Source.get_source()
    Logger.info("Downloading SDE files from #{source.base_url()}")

    results =
      @dump_file_names
      |> Enum.map(fn file_name ->
        Task.async(fn ->
          download_file(file_name, source)
        end)
      end)
      |> Task.await_many(:timer.minutes(30))

    # Check if all downloads succeeded
    case Enum.find(results, fn result -> result != :ok end) do
      nil -> :ok
      {:error, reason} -> {:error, reason}
      error -> {:error, error}
    end
  end

  defp download_file(file_name, source) do
    url = source.file_url(file_name)
    Logger.info("Downloading file from #{url}")

    download_path = Path.join([:code.priv_dir(:wanderer_app), "repo", "data", file_name])

    case Req.get(url,
           raw: true,
           into: File.stream!(download_path, [:write]),
           receive_timeout: @file_download_receive_timeout
         ) do
      {:ok, %{status: 200} = response} ->
        Stream.run(response.body)
        Logger.info("File downloaded successfully to #{download_path}")
        :ok

      {:ok, %{status: status}} ->
        Logger.error("Failed to download #{file_name}: HTTP #{status}")
        {:error, {:http_error, status, file_name}}

      {:error, reason} ->
        Logger.error("Failed to download #{file_name}: #{inspect(reason)}")
        {:error, {:download_failed, file_name, reason}}
    end
  end

  # Version management functions

  defp save_sde_version_from_source do
    source = Source.get_source()

    case source.metadata_url() do
      nil ->
        # Source doesn't support version tracking (Fuzzworks)
        # Still record the update with source info
        record_sde_update(nil, source, nil)
        Logger.debug("SDE source #{inspect(source)} doesn't support version tracking")
        :ok

      url ->
        case fetch_metadata(url) do
          {:ok, metadata} ->
            version = metadata["sde_version"]
            release_date = parse_release_date(metadata["release_date"])
            record_sde_update(version, source, release_date, metadata: metadata)
            Logger.info("Recorded SDE update: version #{version}")
            :ok

          {:error, reason} ->
            Logger.warning(
              "Failed to fetch SDE metadata for version tracking: #{inspect(reason)}"
            )

            :ok
        end
    end
  end

  defp record_sde_update(version, source, release_date, opts \\ []) do
    case source_to_atom(source) do
      {:ok, source_atom} ->
        case SdeVersionRepo.record_update(version, source_atom, release_date, opts) do
          {:ok, record} ->
            Logger.info("SDE version recorded in database: #{record.sde_version}")

            :telemetry.execute(
              [:wanderer_app, :sde, :version, :recorded],
              %{count: 1},
              %{version: record.sde_version, source: source_atom}
            )

            save_sde_version_to_file(version)
            {:ok, record}

          {:error, error} ->
            Logger.warning("Failed to record SDE version in database: #{inspect(error)}")
            save_sde_version_to_file(version)
            {:error, error}
        end

      :error ->
        Logger.warning("Unknown SDE source #{inspect(source)}, skipping database record")
        save_sde_version_to_file(version)
        {:error, :unknown_source}
    end
  end

  defp source_to_atom(WandererApp.SDE.WandererAssets), do: {:ok, :wanderer_assets}
  defp source_to_atom(WandererApp.SDE.Fuzzworks), do: {:ok, :fuzzworks}
  defp source_to_atom(_), do: :error

  defp parse_release_date(nil), do: nil

  defp parse_release_date(date_string) when is_binary(date_string) do
    case DateTime.from_iso8601(date_string) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp save_sde_version_to_file(nil), do: :ok

  defp save_sde_version_to_file(version) when is_binary(version) do
    path = sde_version_path()
    content = Jason.encode!(%{version: version, updated_at: DateTime.utc_now()})

    case File.write(path, content) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to save SDE version to file: #{inspect(reason)}")
        :ok
    end
  end

  @doc """
  Returns the current SDE version from the database.

  Falls back to file-based tracking if database is unavailable.
  """
  @spec get_current_sde_version() :: String.t() | nil
  def get_current_sde_version do
    case SdeVersionRepo.get_latest() do
      {:ok, %{sde_version: version}} ->
        version

      _ ->
        get_sde_version_from_file()
    end
  end

  defp get_sde_last_updated do
    case SdeVersionRepo.get_latest() do
      {:ok, %{applied_at: applied_at}} ->
        applied_at

      _ ->
        get_sde_updated_from_file()
    end
  end

  @doc """
  Returns the history of SDE updates from the database.
  """
  @spec get_sde_history(keyword()) :: {:ok, list()} | {:error, term()}
  def get_sde_history(opts \\ []) do
    SdeVersionRepo.get_history(opts)
  end

  # File-based fallback functions

  defp get_sde_version_from_file do
    path = sde_version_path()

    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"version" => version}} -> version
          _ -> nil
        end

      {:error, _} ->
        nil
    end
  end

  defp get_sde_updated_from_file do
    path = sde_version_path()

    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"updated_at" => updated_at}} ->
            case DateTime.from_iso8601(updated_at) do
              {:ok, dt, _} -> dt
              _ -> nil
            end

          _ ->
            nil
        end

      {:error, _} ->
        nil
    end
  end

  defp sde_version_path do
    Path.join([:code.priv_dir(:wanderer_app), "repo", "data", @sde_version_file])
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
      nil ->
        {:ok, ""}

      _ ->
        {:ok,
         String.to_float(security) |> get_true_security() |> :erlang.float_to_binary(decimals: 1)}
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
    region =
      Enum.find(systems, fn system ->
        system.location_id |> Integer.parse() |> elem(0) == region_id
      end)

    constellation =
      Enum.find(systems, fn system ->
        system.location_id |> Integer.parse() |> elem(0) == constellation_id
      end)

    solar_system =
      Enum.find(systems, fn system ->
        system.location_id |> Integer.parse() |> elem(0) == solar_system_id
      end)

    wormhole_class_id = get_wormhole_class_id(region, constellation, solar_system)
    {:ok, wormhole_class_id}
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
