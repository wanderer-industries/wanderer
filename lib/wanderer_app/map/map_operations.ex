# File: lib/wanderer_app/map/operations.ex
defmodule WandererApp.Map.Operations do
  @moduledoc """
  Central entrypoint for map operations. Delegates responsibilities to specialized submodules:
    - Owner: Fetching and caching owner character info
    - Systems: CRUD and batch upsert for systems
    - Connections: CRUD and batch upsert for connections
    - Structures: CRUD for structures
    - Signatures: CRUD for signatures
  """

  alias WandererApp.Map.Operations.{
    Owner,
    Systems,
    Connections,
    Structures,
    Signatures
  }

  # -- Owner Info -------------------------------------------------------------

  @doc "Fetch cached main character info for a map owner"
  @spec get_owner_character_id(String.t()) ::
          {:ok, %{id: term(), user_id: term()}} | {:error, String.t()}
  defdelegate get_owner_character_id(map_id), to: Owner

  # -- Systems ----------------------------------------------------------------

  @doc "List visible systems"
  @spec list_systems(String.t()) :: [map()]
  defdelegate list_systems(map_id), to: Systems

  @doc "Get a specific system"
  @spec get_system(String.t(), integer()) :: {:ok, map()} | {:error, :not_found}
  defdelegate get_system(map_id, system_id), to: Systems

  @doc "Create a system"
  @spec create_system(String.t(), map()) :: {:ok, map()} | {:error, String.t()}
  defdelegate create_system(map_id, params), to: Systems

  @doc "Update a system"
  @spec update_system(String.t(), integer(), map()) ::
          {:ok, map()} | {:error, String.t()}
  defdelegate update_system(map_id, system_id, attrs), to: Systems

  @doc "Delete a system"
  @spec delete_system(String.t(), integer()) :: {:ok, integer()} | {:error, term()}
  defdelegate delete_system(map_id, system_id), to: Systems

  @doc "Upsert systems and connections in batch"
  @spec upsert_systems_and_connections(String.t(), [map()], [map()]) ::
          {:ok, map()} | {:error, String.t()}
  defdelegate upsert_systems_and_connections(map_id, systems, connections), to: Systems

  # -- Connections -----------------------------------------------------------

  @doc "List all connections"
  @spec list_connections(String.t()) :: [map()]
  defdelegate list_connections(map_id), to: Connections

  @doc "List connections for a specific system"
  @spec list_connections(String.t(), integer()) :: [map()]
  defdelegate list_connections(map_id, system_id), to: Connections

  @doc "Get a connection"
  @spec get_connection(String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  defdelegate get_connection(map_id, connection_id), to: Connections

  @doc "Create a connection"
  @spec create_connection(String.t(), map()) ::
          {:ok, map()} | {:skip, :exists} | {:error, String.t()}
  defdelegate create_connection(map_id, attrs), to: Connections

  @doc "Force-create a connection with explicit character ID"
  @spec create_connection(String.t(), map(), integer()) ::
          {:ok, map()} | {:skip, :exists} | {:error, String.t()}
  defdelegate create_connection(map_id, attrs, char_id), to: Connections

  @doc "Create a connection from a Plug.Conn"
  @spec create_connection(Plug.Conn.t(), map()) ::
          {:ok, :created} | {:skip, :exists} | {:error, atom()}
  defdelegate create_connection(conn, attrs), to: Connections

  @doc "Update a connection"
  @spec update_connection(String.t(), String.t(), map()) ::
          {:ok, map()} | {:error, String.t()}
  defdelegate update_connection(map_id, connection_id, attrs), to: Connections

  @doc "Delete a connection"
  @spec delete_connection(String.t(), integer(), integer()) :: :ok | {:error, term()}
  defdelegate delete_connection(map_id, src_id, tgt_id), to: Connections

  @doc "Get a connection by source and target system IDs"
  @spec get_connection_by_systems(String.t(), integer(), integer()) ::
          {:ok, map()} | {:error, String.t()}
  defdelegate get_connection_by_systems(map_id, source, target), to: Connections

  # -- Structures ------------------------------------------------------------

  @doc "List all structures"
  @spec list_structures(String.t()) :: [map()]
  defdelegate list_structures(map_id), to: Structures

  @doc "Create a structure"
  @spec create_structure(String.t(), map()) :: {:ok, map()} | {:error, String.t()}
  defdelegate create_structure(map_id, params), to: Structures

  @doc "Update a structure"
  @spec update_structure(String.t(), String.t(), map()) :: {:ok, map()} | {:error, String.t()}
  defdelegate update_structure(map_id, struct_id, params), to: Structures

  @doc "Delete a structure"
  @spec delete_structure(String.t(), String.t()) :: :ok | {:error, String.t()}
  defdelegate delete_structure(map_id, struct_id), to: Structures

  # -- Signatures ------------------------------------------------------------

  @doc "List all signatures"
  @spec list_signatures(String.t()) :: [map()]
  defdelegate list_signatures(map_id), to: Signatures

  @doc "Create a signature"
  @spec create_signature(String.t(), map()) :: {:ok, map()} | {:error, String.t()}
  defdelegate create_signature(map_id, params), to: Signatures

  @doc "Update a signature"
  @spec update_signature(String.t(), String.t(), map()) ::
          {:ok, map()} | {:error, String.t()}
  defdelegate update_signature(map_id, sig_id, params), to: Signatures

  @doc "Delete a signature in a map"
  @spec delete_signature(String.t(), String.t()) :: :ok | {:error, String.t()}
  defdelegate delete_signature(map_id, sig_id), to: Signatures
end
