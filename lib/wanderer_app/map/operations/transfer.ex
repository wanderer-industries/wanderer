defmodule WandererApp.Map.Operations.Transfer do
  @moduledoc """
  Export and import of map contents as a portable document.

  Unlike `WandererApp.Map.Operations.Duplication`, which copies a map inside one instance by
  writing records directly, transfer produces a plain data structure that can be stored in a file
  and replayed into any map - including on another deployment. Imports go through the map server
  so that connected clients see the systems appear as they are added.

  Only map contents are transferred: systems, connections and (optionally) signatures. Access
  lists, subscriptions and per user settings are deliberately left out - they reference accounts
  and characters that do not exist on the importing side.
  """

  require Logger

  alias WandererApp.Api.MapSystemSignature
  alias WandererApp.Map.Server

  @export_version 1

  @type stats :: %{systems: non_neg_integer(), connections: non_neg_integer(), signatures: non_neg_integer()}

  @doc """
  Builds the export document for a map.

  Options:
  - `:include_signatures` - include system signatures (default: true)
  """
  @spec export(binary(), keyword()) :: {:ok, map()} | {:error, term()}
  def export(map_id, opts \\ []) do
    include_signatures = Keyword.get(opts, :include_signatures, true)

    with {:ok, map} <- WandererApp.MapRepo.get(map_id),
         {:ok, systems} <- WandererApp.MapSystemRepo.get_visible_by_map(map_id),
         {:ok, connections} <- WandererApp.MapConnectionRepo.get_by_map(map_id) do
      {:ok,
       %{
         "version" => @export_version,
         "exported_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
         "map" => %{
           "name" => map.name,
           "slug" => map.slug,
           "description" => map.description
         },
         "systems" => Enum.map(systems, &export_system/1),
         "connections" => Enum.map(connections, &export_connection/1),
         "signatures" => export_signatures(systems, include_signatures)
       }}
    end
  end

  @doc """
  Replays an export document into an existing map.

  Systems already present on the target map keep their position and attributes - an import adds
  what is missing instead of overwriting the map, so it is safe to run against a live chain.

  Options:
  - `:include_signatures` - import system signatures (default: true)
  """
  @spec import(binary(), map(), binary(), binary() | nil, keyword()) ::
          {:ok, stats()} | {:error, term()}
  def import(map_id, data, user_id, character_id, opts \\ [])

  def import(map_id, %{"version" => @export_version} = data, user_id, character_id, opts) do
    include_signatures = Keyword.get(opts, :include_signatures, true)

    systems = Map.get(data, "systems", [])
    connections = Map.get(data, "connections", [])
    signatures = if include_signatures, do: Map.get(data, "signatures", []), else: []

    existing_ids = existing_solar_system_ids(map_id)

    imported_systems =
      systems
      |> Enum.filter(&is_map/1)
      |> Enum.map(&import_system(map_id, &1, user_id, character_id, existing_ids))
      |> Enum.count(& &1)

    imported_connections = import_connections(map_id, connections, user_id, character_id)
    imported_signatures = import_signatures(map_id, signatures)

    Logger.info(
      "Imported #{imported_systems} systems, #{imported_connections} connections, " <>
        "#{imported_signatures} signatures into map #{map_id}"
    )

    {:ok,
     %{
       systems: imported_systems,
       connections: imported_connections,
       signatures: imported_signatures
     }}
  end

  def import(_map_id, %{"version" => version}, _user_id, _character_id, _opts),
    do: {:error, {:unsupported_version, version}}

  def import(_map_id, _data, _user_id, _character_id, _opts), do: {:error, :invalid_document}

  # -- export helpers ------------------------------------------------------------------------

  defp export_system(system) do
    %{
      "solar_system_id" => system.solar_system_id,
      "position" => %{"x" => system.position_x, "y" => system.position_y},
      "name" => system.name,
      "custom_name" => system.custom_name,
      "description" => system.description,
      "labels" => system.labels,
      "status" => system.status,
      "tag" => system.tag,
      "temporary_name" => system.temporary_name,
      "locked" => system.locked
    }
  end

  defp export_connection(connection) do
    %{
      "source" => connection.solar_system_source,
      "target" => connection.solar_system_target,
      "type" => connection.type,
      "mass_status" => connection.mass_status,
      "time_status" => connection.time_status,
      "ship_size_type" => connection.ship_size_type,
      "wormhole_type" => connection.wormhole_type,
      "locked" => connection.locked
    }
  end

  defp export_signatures(_systems, false), do: []

  defp export_signatures(systems, true) do
    Enum.flat_map(systems, fn system ->
      case MapSystemSignature.by_system_id_all(%{system_id: system.id}) do
        {:ok, signatures} ->
          signatures
          |> Enum.reject(& &1.deleted)
          |> Enum.map(&export_signature(&1, system.solar_system_id))

        {:error, _} ->
          []
      end
    end)
  end

  defp export_signature(signature, solar_system_id) do
    %{
      "solar_system_id" => solar_system_id,
      "eve_id" => signature.eve_id,
      "character_eve_id" => signature.character_eve_id,
      "name" => signature.name,
      "temporary_name" => signature.temporary_name,
      "description" => signature.description,
      "kind" => signature.kind,
      "group" => signature.group,
      "type" => signature.type,
      "custom_info" => signature.custom_info
    }
  end

  # -- import helpers ------------------------------------------------------------------------

  defp existing_solar_system_ids(map_id) do
    case WandererApp.MapSystemRepo.get_all_by_map(map_id) do
      {:ok, systems} -> MapSet.new(systems, & &1.solar_system_id)
      _ -> MapSet.new()
    end
  end

  defp import_system(map_id, system, user_id, character_id, existing_ids) do
    with {:ok, solar_system_id} <- parse_solar_system_id(system["solar_system_id"]),
         :ok <-
           Server.add_system(
             map_id,
             %{solar_system_id: solar_system_id, coordinates: position(system["position"])},
             user_id,
             character_id
           ) do
      # a system that was already on the map keeps whatever the map has for it
      if MapSet.member?(existing_ids, solar_system_id) do
        false
      else
        apply_system_attributes(map_id, solar_system_id, system)
        true
      end
    else
      error ->
        Logger.warning("[Transfer] skipped system #{inspect(system)}: #{inspect(error)}")
        false
    end
  end

  @system_attributes [
    {"custom_name", :custom_name, :update_system_custom_name},
    {"description", :description, :update_system_description},
    {"labels", :labels, :update_system_labels},
    {"status", :status, :update_system_status},
    {"tag", :tag, :update_system_tag},
    {"temporary_name", :temporary_name, :update_system_temporary_name},
    {"locked", :locked, :update_system_locked}
  ]

  defp apply_system_attributes(map_id, solar_system_id, system) do
    Enum.each(@system_attributes, fn {key, attribute, fun} ->
      case Map.get(system, key) do
        value when value in [nil, "", false] ->
          :ok

        value ->
          apply(Server, fun, [map_id, %{:solar_system_id => solar_system_id, attribute => value}])
      end
    end)
  end

  defp import_connections(map_id, connections, user_id, character_id) do
    paste_payload =
      connections
      |> Enum.filter(&is_map/1)
      |> Enum.flat_map(fn connection ->
        with {:ok, source} <- parse_solar_system_id(connection["source"]),
             {:ok, target} <- parse_solar_system_id(connection["target"]) do
          [
            connection
            |> Map.take(["type", "mass_status", "time_status", "ship_size_type", "wormhole_type", "locked"])
            |> Map.merge(%{"source" => to_string(source), "target" => to_string(target)})
          ]
        else
          _ -> []
        end
      end)

    Server.paste_connections(map_id, paste_payload, user_id, character_id)

    length(paste_payload)
  end

  defp import_signatures(map_id, signatures) do
    signatures
    |> Enum.filter(&is_map/1)
    |> Enum.group_by(& &1["solar_system_id"])
    |> Enum.reduce(0, fn {solar_system_id, system_signatures}, acc ->
      with {:ok, parsed_id} <- parse_solar_system_id(solar_system_id),
           {:ok, system} when not is_nil(system) <-
             WandererApp.MapSystemRepo.get_by_map_and_solar_system_id(map_id, parsed_id) do
        acc + create_signatures(system.id, system_signatures)
      else
        _ -> acc
      end
    end)
  end

  defp create_signatures(system_id, signatures) do
    Enum.count(signatures, fn signature ->
      attrs =
        signature
        |> Map.take([
          "eve_id",
          "character_eve_id",
          "name",
          "temporary_name",
          "description",
          "kind",
          "group",
          "type",
          "custom_info"
        ])
        |> Map.new(fn {key, value} -> {String.to_existing_atom(key), value} end)
        |> Map.put(:system_id, system_id)

      case MapSystemSignature.create(attrs) do
        {:ok, _} ->
          true

        {:error, reason} ->
          Logger.warning("[Transfer] skipped signature: #{inspect(reason)}")
          false
      end
    end)
  end

  defp position(%{"x" => x, "y" => y}) when is_number(x) and is_number(y),
    do: %{"x" => round(x), "y" => round(y)}

  defp position(_), do: nil

  defp parse_solar_system_id(id) when is_integer(id), do: {:ok, id}

  defp parse_solar_system_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {parsed, ""} -> {:ok, parsed}
      _ -> {:error, :invalid_solar_system_id}
    end
  end

  defp parse_solar_system_id(_), do: {:error, :invalid_solar_system_id}
end
