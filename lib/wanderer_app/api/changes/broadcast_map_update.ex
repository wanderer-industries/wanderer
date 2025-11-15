defmodule WandererApp.Api.Changes.BroadcastMapUpdate do
  @moduledoc """
  Ash change that coordinates cache, R-tree, and broadcast updates after map resource changes.

  Uses UpdateCoordinator to ensure proper ordering:
  1. Database write (done by Ash before this hook)
  2. Transaction commit (use after_transaction)
  3. Cache update
  4. R-tree update
  5. Broadcasts

  This eliminates race conditions where clients receive broadcasts before data is queryable.

  ## Usage

  In an Ash resource action:

      update :update do
        accept [:status, :tag]
        change {BroadcastMapUpdate, event: :update_system}
      end

  ## Options

  - `:event` - The event type to broadcast (e.g., :update_system, :delete_system, :add_system)
  """

  use Ash.Resource.Change

  require Logger

  alias WandererApp.Map.UpdateCoordinator

  @log_prefix "[BroadcastMapUpdate]"

  defp log(level, message, metadata \\ []) do
    Logger.log(level, "#{@log_prefix} #{message}", metadata)
  end

  @impl true
  def change(changeset, opts, _context) do
    event = Keyword.fetch!(opts, :event)

    changeset
    |> Ash.Changeset.after_transaction(fn changeset_for_action, result ->
      case result do
        {:ok, record} when is_struct(record) ->
          actual_event = determine_event(changeset_for_action, record, event)
          coordinate_update(record, actual_event)
          {:ok, record}

        {:ok, _other} = success ->
          success

        {:error, _changeset} = error ->
          error

        record when is_struct(record) ->
          actual_event = determine_event(changeset_for_action, record, event)
          coordinate_update(record, actual_event)
          record

        other ->
          log(
            :warning,
            "Unexpected result type",
            event: event,
            result_type: inspect(other)
          )

          other
      end
    end)
  end

  defp determine_event(
         changeset,
         %{__struct__: WandererApp.Api.MapSystem} = _result,
         :update_system
       ) do
    case Ash.Changeset.get_attribute(changeset, :visible) do
      false -> :systems_removed
      _ -> :update_system
    end
  end

  defp determine_event(_changeset, _result, event), do: event

  defp coordinate_update(%{map_id: nil} = record, event) when is_atom(event) do
    log(
      :error,
      "Cannot coordinate #{event} - missing map_id",
      struct: record.__struct__,
      event: event,
      record_id: Map.get(record, :id)
    )

    :telemetry.execute(
      [:wanderer_app, :broadcast_map_update, :missing_map_id],
      %{count: 1},
      %{event: event, struct: record.__struct__}
    )

    :ok
  end

  defp coordinate_update(
         %{__struct__: WandererApp.Api.MapSystem, map_id: map_id} = system,
         :add_system
       ) do
    UpdateCoordinator.add_system(map_id, system)
  end

  defp coordinate_update(
         %{__struct__: WandererApp.Api.MapSystem, map_id: map_id} = system,
         :update_system
       ) do
    UpdateCoordinator.update_system(map_id, system, event: :update_system)
  end

  defp coordinate_update(
         %{
           __struct__: WandererApp.Api.MapSystem,
           map_id: map_id,
           solar_system_id: solar_system_id
         },
         :systems_removed
       ) do
    UpdateCoordinator.remove_system(map_id, solar_system_id)
  end

  defp coordinate_update(
         %{__struct__: WandererApp.Api.MapConnection, map_id: map_id} = connection,
         :add_connection
       ) do
    UpdateCoordinator.add_connection(map_id, connection)
  end

  defp coordinate_update(
         %{__struct__: WandererApp.Api.MapConnection, map_id: map_id} = connection,
         :update_connection
       ) do
    UpdateCoordinator.update_connection(map_id, connection)
  end

  defp coordinate_update(
         %{__struct__: WandererApp.Api.MapConnection, map_id: map_id} = connection,
         :remove_connections
       ) do
    UpdateCoordinator.remove_connection(map_id, connection)
  end

  defp coordinate_update({:error, _changeset}, _event), do: :ok

  defp coordinate_update(record, event) do
    log(
      :warning,
      "No coordinator handler for #{event} on #{inspect(record.__struct__)}"
    )

    :ok
  end
end
