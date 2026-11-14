defmodule WandererApp.Map.IntelSync do
  @moduledoc """
  Copies intel from a source map to a subscriber map for a given solar system.

  Called when a system becomes visible on a subscriber map (sync-on-visibility),
  or when a user manually triggers a re-sync via the sync icon.

  Intel fields: custom_name, description, tag, temporary_name, labels, status.
  Also syncs comments and structures (marked with inherited_from_map_id).
  """

  require Logger

  alias WandererApp.Map.Server.Impl
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
            {{:ok, comments}, {:ok, structures}} ->
              broadcast_sync(subscriber_map_id, solar_system_id, comments, structures)
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
    with {:ok, removed_ids} <- delete_inherited(subscriber_system_id, source_map_id, api_module) do
      case copy_from_source(
             subscriber_system_id,
             source_system_id,
             source_map_id,
             api_module,
             attrs_fn
           ) do
        {:ok, added} -> {:ok, %{removed: removed_ids, added: added}}
        error -> error
      end
    end
  end

  defp delete_inherited(subscriber_system_id, source_map_id, api_module) do
    case api_module.inherited_by_system(subscriber_system_id, source_map_id) do
      {:ok, inherited_records} ->
        {removed_ids, errors} =
          inherited_records
          |> Enum.reduce({[], []}, fn record, {ids, errs} ->
            case api_module.destroy(record) do
              :ok -> {[record.id | ids], errs}
              {:ok, _} -> {[record.id | ids], errs}
              {:error, reason} -> {ids, [reason | errs]}
            end
          end)

        case errors do
          [] -> {:ok, Enum.reverse(removed_ids)}
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
        {added, errors} =
          source_records
          |> Enum.reject(& &1.inherited_from_map_id)
          |> Enum.reduce({[], []}, fn record, {acc, errs} ->
            case api_module.create(attrs_fn.(record, subscriber_system_id, source_map_id)) do
              {:ok, created} -> {[created | acc], errs}
              {:error, reason} -> {acc, [reason | errs]}
            end
          end)

        case errors do
          [] -> {:ok, Enum.reverse(added)}
          details -> {:error, {:create_failed, Enum.reverse(details)}}
        end

      {:error, reason} ->
        {:error, {:create_failed, [reason]}}
    end
  end

  @doc """
  Returns the solar system ids on `subscriber_map_id` whose intel is owned by
  `source_map_id` — i.e. the systems visible on both maps.

  This is the set `sync_system/3` actually copies into; for anything else it
  returns `{:ok, :no_source_data}` and leaves the subscriber's own intel alone.
  Read-only gating (client and server) keys off this rather than off "the map
  has a source", so systems the source knows nothing about stay editable.
  """
  def inherited_solar_system_ids(_subscriber_map_id, nil), do: []

  def inherited_solar_system_ids(subscriber_map_id, source_map_id) do
    with true <- WandererApp.Env.intel_sharing_enabled?(),
         {:ok, subscriber_systems} <- MapSystemRepo.get_visible_by_map(subscriber_map_id),
         {:ok, source_systems} <- MapSystemRepo.get_visible_by_map(source_map_id) do
      source_ids = MapSet.new(source_systems, & &1.solar_system_id)

      subscriber_systems
      |> Enum.map(& &1.solar_system_id)
      |> Enum.filter(&MapSet.member?(source_ids, &1))
    else
      _ -> []
    end
  end

  @doc """
  True when `solar_system_id` on `subscriber_map_id` is intel-inherited.

  Server-side counterpart of the client's read-only gate — the client is not
  trusted, so the event handlers call this before accepting a write.
  """
  def inherited_system?(subscriber_map_id, solar_system_id) do
    case WandererApp.Map.get_map_state(subscriber_map_id, false) do
      {:ok, %{map: %{intel_source_map_id: source_map_id}}} when not is_nil(source_map_id) ->
        WandererApp.Env.intel_sharing_enabled?() and
          match?(
            {:ok, _},
            MapSystemRepo.get_by_map_and_solar_system_id(source_map_id, solar_system_id)
          )

      _ ->
        false
    end
  end

  @doc """
  Removes every record this map inherited from `source_map_id`.

  Called when the intel source changes or is cleared. `delete_inherited/3`
  scopes to the map's *current* source, so without this the previous source's
  comments and structures would be unreachable by any later sync and would stay
  on the subscriber map permanently.

  Returns `{:ok, cleared_system_count}`.
  """
  def clear_inherited_from(subscriber_map_id, source_map_id)
      when not is_nil(source_map_id) do
    case MapSystemRepo.get_visible_by_map(subscriber_map_id) do
      {:ok, systems} ->
        cleared =
          Enum.reduce(systems, 0, fn system, acc ->
            comments =
              delete_inherited(system.id, source_map_id, WandererApp.Api.MapSystemComment)

            structures =
              delete_inherited(system.id, source_map_id, WandererApp.Api.MapSystemStructure)

            case {comments, structures} do
              {{:ok, []}, {:ok, []}} ->
                acc

              {{:ok, comment_ids}, {:ok, structure_ids}} ->
                broadcast_sync(
                  subscriber_map_id,
                  system.solar_system_id,
                  %{removed: comment_ids, added: []},
                  %{removed: structure_ids, added: []}
                )

                acc + 1

              {c, s} ->
                Logger.error(fn ->
                  "Failed to clear inherited intel for solar_system #{system.solar_system_id} " <>
                    "on map #{subscriber_map_id}: #{inspect({c, s})}"
                end)

                acc
            end
          end)

        {:ok, cleared}

      error ->
        Logger.error(fn ->
          "Failed to list visible systems while clearing inherited intel: #{inspect(error)}"
        end)

        {:error, :list_systems_failed}
    end
  end

  def clear_inherited_from(_subscriber_map_id, nil), do: {:ok, 0}

  # CLAUDE.md requires every map state change to broadcast. The existing comment
  # paths in map_server_systems_impl.ex publish per-record events, so a sync
  # replays the same events rather than inventing a bulk one; structures follow
  # their own convention of a coarse :structures_updated that the client
  # re-fetches on.
  defp broadcast_sync(map_id, solar_system_id, comments, structures) do
    Enum.each(comments.removed, fn comment_id ->
      Impl.broadcast!(map_id, :system_comment_removed, %{
        solar_system_id: solar_system_id,
        comment_id: comment_id
      })
    end)

    Enum.each(comments.added, fn comment ->
      Impl.broadcast!(map_id, :system_comment_added, %{
        solar_system_id: solar_system_id,
        comment: Ash.load!(comment, [:character])
      })
    end)

    if structures.removed != [] or structures.added != [] do
      Impl.broadcast!(map_id, :structures_updated, solar_system_id)
    end

    :ok
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
