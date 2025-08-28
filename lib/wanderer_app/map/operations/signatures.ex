defmodule WandererApp.Map.Operations.Signatures do
  @moduledoc """
  CRUD for map signatures.
  """

  require Logger
  alias WandererApp.Map.Operations
  alias WandererApp.Api.{MapSystem, MapSystemSignature}
  alias WandererApp.Map.Server

  @spec list_signatures(String.t()) :: [map()]
  def list_signatures(map_id) do
    systems = Operations.list_systems(map_id)

    if systems != [] do
      systems
      |> Enum.flat_map(fn sys ->
        with {:ok, sigs} <- MapSystemSignature.by_system_id(sys.id) do
          # Add solar_system_id to each signature and remove system_id
          Enum.map(sigs, fn sig ->
            sig
            |> Map.from_struct()
            |> Map.put(:solar_system_id, sys.solar_system_id)
            |> Map.drop([:system_id, :__meta__, :system, :aggregates, :calculations])
          end)
        else
          err ->
            Logger.error("[list_signatures] error: #{inspect(err)}")
            []
        end
      end)
    else
      []
    end
  end

  @spec create_signature(Plug.Conn.t(), map()) :: {:ok, map()} | {:error, atom()}
  def create_signature(
        %{assigns: %{map_id: map_id, owner_character_id: char_id, owner_user_id: user_id}} =
          _conn,
        %{"solar_system_id" => solar_system_id} = params
      )
      when is_integer(solar_system_id) do
    # Convert solar_system_id to system_id for internal use
    with {:ok, system} <- MapSystem.by_map_id_and_solar_system_id(map_id, solar_system_id) do
      attrs =
        params
        |> Map.put("character_eve_id", char_id)
        |> Map.put("system_id", system.id)
        |> Map.delete("solar_system_id")

      case Server.update_signatures(map_id, %{
             added_signatures: [attrs],
             updated_signatures: [],
             removed_signatures: [],
             solar_system_id: solar_system_id,
             character_id: char_id,
             user_id: user_id,
             delete_connection_with_sigs: false
           }) do
        :ok ->
          # Try to fetch the created signature to return with proper fields
          with {:ok, sigs} <-
                 MapSystemSignature.by_system_id_and_eve_ids(system.id, [attrs["eve_id"]]),
               sig when not is_nil(sig) <- List.first(sigs) do
            result =
              sig
              |> Map.from_struct()
              |> Map.put(:solar_system_id, system.solar_system_id)
              |> Map.drop([:system_id, :__meta__, :system, :aggregates, :calculations])

            {:ok, result}
          else
            _ ->
              # Fallback: return attrs with solar_system_id added
              attrs_result =
                attrs
                |> Map.put(:solar_system_id, solar_system_id)
                |> Map.drop(["system_id"])

              {:ok, attrs_result}
          end

        err ->
          Logger.error("[create_signature] Unexpected error: #{inspect(err)}")
          {:error, :unexpected_error}
      end
    else
      _ ->
        Logger.error(
          "[create_signature] System not found for solar_system_id: #{solar_system_id}"
        )

        {:error, :system_not_found}
    end
  end

  def create_signature(
        %{assigns: %{map_id: _map_id, owner_character_id: _char_id, owner_user_id: _user_id}} =
          _conn,
        %{"solar_system_id" => _invalid} = _params
      ),
      do: {:error, :missing_params}

  def create_signature(_conn, _params), do: {:error, :missing_params}

  @spec update_signature(Plug.Conn.t(), String.t(), map()) :: {:ok, map()} | {:error, atom()}
  def update_signature(
        %{assigns: %{map_id: map_id, owner_character_id: char_id, owner_user_id: user_id}} =
          _conn,
        sig_id,
        params
      ) do
    with {:ok, sig} <- MapSystemSignature.by_id(sig_id),
         {:ok, system} <- MapSystem.by_id(sig.system_id) do
      base = %{
        "eve_id" => sig.eve_id,
        "name" => sig.name,
        "kind" => sig.kind,
        "group" => sig.group,
        "type" => sig.type,
        "custom_info" => sig.custom_info,
        "character_eve_id" => char_id,
        "description" => sig.description,
        "linked_system_id" => sig.linked_system_id
      }

      attrs = Map.merge(base, params)

      :ok =
        Server.update_signatures(map_id, %{
          added_signatures: [],
          updated_signatures: [attrs],
          removed_signatures: [],
          solar_system_id: system.solar_system_id,
          character_id: char_id,
          user_id: user_id,
          delete_connection_with_sigs: false
        })

      # Fetch the updated signature to return with proper fields
      with {:ok, updated_sig} <- MapSystemSignature.by_id(sig_id) do
        result =
          updated_sig
          |> Map.from_struct()
          |> Map.put(:solar_system_id, system.solar_system_id)
          |> Map.drop([:system_id, :__meta__, :system, :aggregates, :calculations])

        {:ok, result}
      else
        _ -> {:ok, attrs}
      end
    else
      err ->
        Logger.error("[update_signature] Unexpected error: #{inspect(err)}")
        {:error, :unexpected_error}
    end
  end

  def update_signature(_conn, _sig_id, _params), do: {:error, :missing_params}

  @spec delete_signature(Plug.Conn.t(), String.t()) :: :ok | {:error, atom()}
  def delete_signature(
        %{assigns: %{map_id: map_id, owner_character_id: char_id, owner_user_id: user_id}} =
          _conn,
        sig_id
      ) do
    with {:ok, sig} <- MapSystemSignature.by_id(sig_id),
         {:ok, system} <- MapSystem.by_id(sig.system_id) do
      removed = [
        %{
          "eve_id" => sig.eve_id,
          "name" => sig.name,
          "kind" => sig.kind,
          "group" => sig.group
        }
      ]

      :ok =
        Server.update_signatures(map_id, %{
          added_signatures: [],
          updated_signatures: [],
          removed_signatures: removed,
          solar_system_id: system.solar_system_id,
          character_id: char_id,
          user_id: user_id,
          delete_connection_with_sigs: false
        })

      :ok
    else
      err ->
        Logger.error("[delete_signature] Unexpected error: #{inspect(err)}")
        {:error, :unexpected_error}
    end
  end

  def delete_signature(_conn, _sig_id), do: {:error, :missing_params}
end
