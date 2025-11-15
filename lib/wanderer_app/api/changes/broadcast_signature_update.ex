defmodule WandererApp.Api.Changes.BroadcastSignatureUpdate do
  @moduledoc """
  Ash change that broadcasts PubSub events after signature updates.

  Signatures require loading the related system to get map_id and solar_system_id
  for the broadcast, since they don't have a direct map_id field.

  ## Usage

  In an Ash resource action:

      update :update do
        accept [:type, :group]
        change BroadcastSignatureUpdate
      end

  ## Broadcast Format

  Signatures broadcast :signatures_updated with the solar_system_id as payload:
  - Topic: map_id (from related system)
  - Message: %{event: :signatures_updated, payload: solar_system_id}
  """

  use Ash.Resource.Change

  require Logger

  alias WandererApp.Map.Server.Impl

  @log_prefix "[BroadcastSignatureUpdate]"

  defp log(level, message, metadata \\ []) do
    Logger.log(level, "#{@log_prefix} #{message}", metadata)
  end

  @impl true
  def change(changeset, _opts, _context) do
    changeset =
      if changeset.action_type == :destroy do
        case changeset.data do
          %{__struct__: _} = record ->
            case Ash.load(record, :system) do
              {:ok, loaded_record} ->
                Ash.Changeset.put_context(changeset, :loaded_for_broadcast, loaded_record)

              {:error, error} ->
                log(
                  :error,
                  "Failed to load system before destroy: #{inspect(error)}"
                )

                changeset
            end

          _ ->
            changeset
        end
      else
        changeset
      end

    changeset
    |> Ash.Changeset.after_transaction(fn changeset_for_action, result ->
      record_to_broadcast =
        case {changeset_for_action.action_type, result} do
          {:destroy, _} ->
            Map.get(changeset_for_action.context, :loaded_for_broadcast)

          {_, {:ok, record}} when is_struct(record) ->
            record

          {_, record} when is_struct(record) ->
            record

          _ ->
            nil
        end

      if is_struct(record_to_broadcast) do
        # Broadcast errors are logged but don't fail the database transaction
        case broadcast_signature_update(record_to_broadcast) do
          :ok -> :ok
          # Already logged in broadcast_signature_update
          {:error, _reason} -> :ok
        end

        {:ok, result}
      else
        {:ok, result}
      end
    end)
  end

  defp broadcast_signature_update(signature) do
    with {:ok, %{system: system}} when not is_nil(system) <- load_system(signature),
         {:ok, map_id} <- validate_present(system.map_id, :missing_map_id, signature),
         {:ok, solar_system_id} <-
           validate_present(system.solar_system_id, :missing_solar_system_id, signature) do
      Impl.broadcast!(map_id, :signatures_updated, solar_system_id)
      telemetry_success(:signatures_updated, map_id)
      :ok
    else
      {:ok, %{system: nil}} ->
        log_and_track_error(%{
          type: :system_not_loaded,
          reason: :system_not_loaded,
          signature_id: signature.id,
          stacktrace: nil
        })

      {:error, :missing_map_id} ->
        {:error, :missing_map_id}

      {:error, :missing_solar_system_id} ->
        {:error, :missing_solar_system_id}

      {:error, :system_load_failed, error} ->
        log_and_track_error(%{
          type: :system_load_failed,
          reason: error,
          signature_id: signature.id,
          stacktrace: nil
        })

      {:error, error} ->
        log_and_track_error(%{
          type: :unexpected_error,
          reason: error,
          signature_id: signature.id,
          stacktrace: nil
        })
    end
  rescue
    error ->
      log_and_track_error(%{
        type: :exception,
        reason: error,
        signature_id: signature.id,
        stacktrace: __STACKTRACE__
      })
  end

  defp load_system(signature) do
    case Ash.load(signature, :system) do
      {:ok, _} = success -> success
      {:error, error} -> {:error, :system_load_failed, error}
    end
  end

  defp validate_present(nil, error_reason, signature) do
    log_and_track_error(%{
      type: error_reason,
      reason: error_reason,
      signature_id: signature.id,
      stacktrace: nil
    })
  end

  defp validate_present(value, _error_reason, _signature) do
    {:ok, value}
  end

  @typep error_context :: %{
           type: atom(),
           reason: term(),
           signature_id: String.t(),
           stacktrace: list() | nil
         }

  @spec log_and_track_error(error_context()) :: {:error, term()}
  defp log_and_track_error(%{
         type: type,
         reason: reason,
         signature_id: sig_id,
         stacktrace: stacktrace
       }) do
    message = format_error_message(type, reason)

    log(
      :error,
      message,
      event: :signatures_updated,
      signature_id: sig_id,
      error: inspect(reason),
      error_type: type,
      stacktrace: format_stacktrace(stacktrace)
    )

    telemetry_error(:signatures_updated, type)
    {:error, reason}
  end

  defp format_error_message(:system_not_loaded, _reason),
    do: "Cannot broadcast - system_not_loaded"

  defp format_error_message(:system_load_failed, _reason),
    do: "Failed to load system"

  defp format_error_message(:exception, reason),
    do: "Failed to broadcast signatures_updated: #{inspect(reason)}"

  defp format_error_message(:unexpected_error, reason),
    do: "Cannot broadcast - #{inspect({:unexpected_error, reason})}"

  defp format_error_message(type, reason),
    do: "Cannot broadcast - #{inspect(reason)} (type: #{type})"

  defp format_stacktrace(nil), do: nil
  defp format_stacktrace(stacktrace), do: Exception.format_stacktrace(stacktrace)

  defp telemetry_success(event, map_id) do
    :telemetry.execute(
      [:wanderer_app, :broadcast, :success],
      %{count: 1},
      %{event: event, map_id: map_id}
    )
  end

  defp telemetry_error(event, reason) do
    :telemetry.execute(
      [:wanderer_app, :broadcast, :error],
      %{count: 1},
      %{reason: reason, event: event}
    )
  end
end
