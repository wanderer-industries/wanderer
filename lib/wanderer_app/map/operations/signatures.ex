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

      {:ok, attrs}
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
