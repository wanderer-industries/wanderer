defmodule WandererApp.Map.IntelSync do
  @moduledoc """
  Copies intel from a source map to a subscriber map for a given solar system.

  Called when a system becomes visible on a subscriber map (sync-on-visibility),
  or when a user manually triggers a re-sync via the sync icon.

  Intel fields: custom_name, description, tag, temporary_name, labels, status.
  Also syncs comments and structures (marked with inherited_from_map_id).
  """

  require Logger

  alias WandererApp.MapSystemRepo

  @intel_fields [:custom_name, :description, :tag, :temporary_name, :labels, :status]

  @doc "Returns the list of system fields considered intel for syncing."
  def intel_fields, do: @intel_fields

  @doc """
  Syncs intel for a single system from source map to subscriber map.
  Copies system metadata fields, comments, and structures.

  Returns:
    - {:ok, updated_system} on successful sync
    - {:ok, :disabled} if intel sharing is disabled
    - {:ok, :no_source_data} if source map has no data for this system
    - {:ok, :subscriber_not_found} if subscriber map has no matching system
    - {:error, reason} on failure
  """
  def sync_system(subscriber_map_id, source_map_id, solar_system_id) do
    if WandererApp.Env.intel_sharing_enabled?() do
      do_sync_system(subscriber_map_id, source_map_id, solar_system_id)
    else
      {:ok, :disabled}
    end
  end

  @doc """
  Syncs intel for all visible systems on a subscriber map from its source.
  Used when intel_source_map_id is first configured (backfill).

  Returns:
    - `{:ok, synced_count}` when all systems synced successfully (or were skipped).
      `synced_count` is the number of systems whose intel was actually copied.
    - `{:ok, synced_count, errors}` on partial failure. `synced_count` is the number
      of systems successfully synced, and `errors` is a list of
      `{solar_system_id, reason}` tuples for each system that failed to sync.
    - `{:ok, :disabled}` if intel sharing is disabled.
    - `{:error, :list_systems_failed}` if the visible systems could not be loaded.
  """
  def sync_all_visible_systems(subscriber_map_id, source_map_id) do
    if WandererApp.Env.intel_sharing_enabled?() do
      case MapSystemRepo.get_visible_by_map(subscriber_map_id) do
        {:ok, systems} ->
          results =
            Enum.map(systems, fn system ->
              {system.solar_system_id,
               do_sync_system(subscriber_map_id, source_map_id, system.solar_system_id)}
            end)

          {synced_count, skipped_count, errors} =
            Enum.reduce(results, {0, 0, []}, fn
              {_sid, {:ok, %{} = _system}}, {ok, skip, errs} ->
                {ok + 1, skip, errs}

              {_sid, {:ok, reason}}, {ok, skip, errs} when is_atom(reason) ->
                {ok, skip + 1, errs}

              {sid, {:error, reason}}, {ok, skip, errs} ->
                {ok, skip, [{sid, reason} | errs]}
            end)

          errors = Enum.reverse(errors)

          if errors == [] do
            Logger.debug(fn ->
              "Intel sync backfill for map #{subscriber_map_id}: #{synced_count} synced, #{skipped_count} skipped"
            end)

            {:ok, synced_count}
          else
            Logger.error(fn ->
              "Intel sync backfill for map #{subscriber_map_id}: #{synced_count} synced, " <>
                "#{skipped_count} skipped, #{length(errors)} errors: #{inspect(errors)}"
            end)

            {:ok, synced_count, errors}
          end

        error ->
          Logger.error(fn ->
            "Failed to list visible systems for backfill: #{inspect(error)}"
          end)

          {:error, :list_systems_failed}
      end
    else
      {:ok, :disabled}
    end
  end

  defp do_sync_system(subscriber_map_id, source_map_id, solar_system_id) do
    with {:source, {:ok, source_system}} <-
           {:source, MapSystemRepo.get_by_map_and_solar_system_id(source_map_id, solar_system_id)},
         {:subscriber, {:ok, subscriber_system}} <-
           {:subscriber,
            MapSystemRepo.get_by_map_and_solar_system_id(subscriber_map_id, solar_system_id)} do
      intel_attrs = Map.take(source_system, @intel_fields)

      case WandererApp.Api.MapSystem.update_intel(subscriber_system, intel_attrs) do
        {:ok, updated_system} ->
          comments_result =
            sync_inherited_records(
              subscriber_system.id,
              source_system.id,
              source_map_id,
              WandererApp.Api.MapSystemComment,
              &comment_attrs/3
            )

          structures_result =
            sync_inherited_records(
              subscriber_system.id,
              source_system.id,
              source_map_id,
              WandererApp.Api.MapSystemStructure,
              &structure_attrs/3
            )

          case {comments_result, structures_result} do
            {:ok, :ok} ->
              {:ok, updated_system}

            {{:error, reason}, _} ->
              Logger.error(fn ->
                "Failed to sync comments for solar_system #{solar_system_id} " <>
                  "from map #{source_map_id} to #{subscriber_map_id}: #{inspect(reason)}"
              end)

              {:error, reason}

            {_, {:error, reason}} ->
              Logger.error(fn ->
                "Failed to sync structures for solar_system #{solar_system_id} " <>
                  "from map #{source_map_id} to #{subscriber_map_id}: #{inspect(reason)}"
              end)

              {:error, reason}
          end

        {:error, reason} ->
          Logger.error(fn ->
            "Failed to sync intel for system #{solar_system_id}: #{inspect(reason)}"
          end)

          {:error, reason}
      end
    else
      {:source, {:error, :not_found}} ->
        {:ok, :no_source_data}

      {:subscriber, {:error, :not_found}} ->
        Logger.debug(fn ->
          "Intel sync skipped for solar_system #{solar_system_id}: subscriber system not found on map #{subscriber_map_id}"
        end)

        {:ok, :subscriber_not_found}

      {step, error} ->
        Logger.debug(fn ->
          "Intel sync skipped for solar_system #{solar_system_id} at #{step}: #{inspect(error)}"
        end)

        {:error, error}
    end
  end

  defp sync_inherited_records(
         subscriber_system_id,
         source_system_id,
         source_map_id,
         api_module,
         attrs_fn
       ) do
    with :ok <- delete_inherited(subscriber_system_id, source_map_id, api_module) do
      copy_from_source(
        subscriber_system_id,
        source_system_id,
        source_map_id,
        api_module,
        attrs_fn
      )
    end
  end

  defp delete_inherited(subscriber_system_id, source_map_id, api_module) do
    case api_module.inherited_by_system(subscriber_system_id, source_map_id) do
      {:ok, inherited_records} ->
        errors =
          inherited_records
          |> Enum.reduce([], fn record, acc ->
            case api_module.destroy(record) do
              :ok -> acc
              {:ok, _} -> acc
              {:error, reason} -> [reason | acc]
            end
          end)

        case errors do
          [] -> :ok
          details -> {:error, {:delete_failed, Enum.reverse(details)}}
        end

      {:error, reason} ->
        {:error, {:delete_failed, [reason]}}
    end
  end

  defp copy_from_source(
         subscriber_system_id,
         source_system_id,
         source_map_id,
         api_module,
         attrs_fn
       ) do
    case api_module.by_system_id(source_system_id) do
      {:ok, source_records} ->
        errors =
          source_records
          |> Enum.reject(& &1.inherited_from_map_id)
          |> Enum.reduce([], fn record, acc ->
            case api_module.create(attrs_fn.(record, subscriber_system_id, source_map_id)) do
              {:ok, _} -> acc
              {:error, reason} -> [reason | acc]
            end
          end)

        case errors do
          [] -> :ok
          details -> {:error, {:create_failed, Enum.reverse(details)}}
        end

      {:error, reason} ->
        {:error, {:create_failed, [reason]}}
    end
  end

  defp comment_attrs(comment, subscriber_system_id, source_map_id) do
    %{
      system_id: subscriber_system_id,
      character_id: comment.character_id,
      text: comment.text,
      inherited_from_map_id: source_map_id
    }
  end

  defp structure_attrs(structure, subscriber_system_id, source_map_id) do
    %{
      system_id: subscriber_system_id,
      solar_system_name: structure.solar_system_name,
      solar_system_id: structure.solar_system_id,
      structure_type_id: structure.structure_type_id,
      structure_type: structure.structure_type,
      character_eve_id: structure.character_eve_id,
      name: structure.name,
      notes: structure.notes,
      owner_name: structure.owner_name,
      owner_ticker: structure.owner_ticker,
      owner_id: structure.owner_id,
      status: structure.status,
      end_time: structure.end_time,
      inherited_from_map_id: source_map_id
    }
  end
end
