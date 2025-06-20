defmodule WandererApp.Contexts.MapSignatures do
  @moduledoc """
  Context for managing map signatures.
  
  This module provides a high-level interface for signature operations,
  including CRUD operations for wormhole signatures in map systems.
  """

  require Logger
  alias WandererApp.Contexts.MapSystems
  alias WandererApp.Api.{MapSystem, MapSystemSignature}
  alias WandererApp.Map.Server

  @doc """
  Lists all signatures for a map.
  """
  @spec list_signatures(String.t()) :: [map()]
  def list_signatures(map_id) do
    systems = MapSystems.list_systems(map_id)

    if systems != [] do
      systems
      |> Enum.flat_map(fn sys ->
        with {:ok, sigs} <- MapSystemSignature.by_system_id(sys.id) do
          sigs
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

  @doc """
  Lists signatures for a specific system.
  """
  @spec list_signatures_for_system(String.t()) :: {:ok, [map()]} | {:error, term()}
  def list_signatures_for_system(system_id) do
    MapSystemSignature.by_system_id(system_id)
  end

  @doc """
  Creates a new signature in a system.
  """
  @spec create_signature(Plug.Conn.t(), map()) :: {:ok, map()} | {:error, atom()}
  def create_signature(
        %{assigns: %{map_id: map_id, owner_character_id: char_id, owner_user_id: user_id}} =
          _conn,
        %{"solar_system_id" => _solar_system_id} = params
      ) do
    attrs = Map.put(params, "character_eve_id", char_id)

    case Server.update_signatures(map_id, %{
           added_signatures: [attrs],
           updated_signatures: [],
           removed_signatures: [],
           solar_system_id: params["solar_system_id"],
           character_id: char_id,
           user_id: user_id,
           delete_connection_with_sigs: false
         }) do
      :ok ->
        {:ok, attrs}

      err ->
        Logger.error("[create_signature] Unexpected error: #{inspect(err)}")
        {:error, :unexpected_error}
    end
  end

  def create_signature(_conn, _params), do: {:error, :missing_params}

  @doc """
  Updates an existing signature.
  """
  @spec update_signature(Plug.Conn.t(), String.t(), map()) :: {:ok, map()} | {:error, atom()}
  def update_signature(
        %{assigns: %{map_id: map_id, owner_character_id: char_id, owner_user_id: user_id}} =
          _conn,
        sig_id,
        params
      ) do
    with {:ok, sig} <- MapSystemSignature.by_id(sig_id),
         {:ok, system} <- MapSystem.by_id(sig.system_id) do
      # Only include user-updatable fields in base map to prevent field exposure
      base = %{
        "name" => sig.name,
        "description" => sig.description,
        "custom_info" => sig.custom_info,
        "character_eve_id" => char_id
      }
      
      # System-managed fields that should be preserved but not user-updatable
      system_fields = %{
        "eve_id" => sig.eve_id,
        "kind" => sig.kind,
        "group" => sig.group,
        "type" => sig.type,
        "linked_system_id" => sig.linked_system_id
      }

      # Merge user input with user-updatable fields only
      user_updates = Map.merge(base, params)
      
      # Combine with system-managed fields (user input cannot override these)
      attrs = Map.merge(user_updates, system_fields)

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

      {:ok, attrs}
    else
      err ->
        Logger.error("[update_signature] Unexpected error: #{inspect(err)}")
        {:error, :unexpected_error}
    end
  end

  def update_signature(_conn, _sig_id, _params), do: {:error, :missing_params}

  @doc """
  Deletes a signature.
  """
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

  @doc """
  Batch updates signatures for a system.
  Handles adding, updating, and removing multiple signatures at once.
  """
  @spec batch_update_signatures(Plug.Conn.t(), map()) :: :ok | {:error, atom()}
  def batch_update_signatures(
        %{assigns: %{map_id: map_id, owner_character_id: char_id, owner_user_id: user_id}} = _conn,
        %{
          "solar_system_id" => solar_system_id,
          "added_signatures" => added,
          "updated_signatures" => updated,
          "removed_signatures" => removed
        } = params
      ) do
    case Server.update_signatures(map_id, %{
           added_signatures: added || [],
           updated_signatures: updated || [],
           removed_signatures: removed || [],
           solar_system_id: solar_system_id,
           character_id: char_id,
           user_id: user_id,
           delete_connection_with_sigs: Map.get(params, "delete_connection_with_sigs", false)
         }) do
      :ok -> :ok
      err -> {:error, err}
    end
  end

  def batch_update_signatures(_conn, _params), do: {:error, :missing_params}
end