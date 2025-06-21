defmodule WandererAppWeb.Plugs.SetUser do
  @moduledoc """
  Plug to set current user and role with session caching.
  
  This plug avoids database lookups on every request by caching user data
  in signed session cookies. The cache has a configurable TTL and automatically
  refreshes when stale.
  """

  import Plug.Conn

  alias WandererApp.Api.User

  # Cache TTL in seconds (15 minutes default)
  @cache_ttl Application.compile_env(:wanderer_app, :user_cache_ttl, 900)
  
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)

    case get_cached_user_or_load(conn, user_id) do
      {nil, updated_conn} ->
        updated_conn
        |> assign(:current_user, nil)
        |> assign(:current_user_role, :none)

      {user, updated_conn} ->
        user_role = determine_user_role(user)

        updated_conn
        |> assign(:current_user, user)
        |> assign(:current_user_role, user_role)
    end
  end

  # Get user from cache or load from database if needed
  defp get_cached_user_or_load(conn, nil), do: {nil, conn}

  defp get_cached_user_or_load(conn, user_id) do
    cached_data = get_session(conn, :cached_user)
    
    case is_cache_valid?(cached_data, user_id) do
      true ->
        # Use cached data
        user = deserialize_user(cached_data.user_data)
        {user, conn}
        
      false ->
        # Load fresh data and cache it
        case load_user_from_db(user_id) do
          nil ->
            {nil, clear_user_cache(conn)}
            
          user ->
            cached_user_data = %{
              user_id: user_id,
              user_data: serialize_user(user),
              cached_at: System.system_time(:second)
            }
            
            updated_conn = put_session(conn, :cached_user, cached_user_data)
            {user, updated_conn}
        end
    end
  end

  # Check if cached data is valid (exists, correct user, not expired)
  defp is_cache_valid?(nil, _user_id), do: false
  defp is_cache_valid?(%{user_id: cached_user_id}, user_id) when cached_user_id != user_id, do: false
  defp is_cache_valid?(%{cached_at: cached_at}, _user_id) do
    current_time = System.system_time(:second)
    (current_time - cached_at) < @cache_ttl
  end
  defp is_cache_valid?(_cached_data, _user_id), do: false

  # Load user from database
  defp load_user_from_db(user_id) do
    case User.by_id(user_id, load: :characters) do
      {:ok, user} -> user
      {:error, _} -> nil
    end
  end

  # Serialize user data for session storage (only essential fields)
  defp serialize_user(user) do
    %{
      id: user.id,
      name: user.name,
      hash: user.hash,
      last_map_id: user.last_map_id,
      # Remove sensitive balance field
      # Only store character IDs, not full character data
      character_ids: Enum.map(user.characters || [], & &1.id)
    }
  end

  # Deserialize user data from session storage
  defp deserialize_user(user_data) do
    # Since we now only store character IDs, we need to handle this differently
    # For now, return a minimal user structure - full data should be loaded from DB when needed
    %{
      id: user_data.id,
      name: user_data.name,
      hash: user_data.hash,
      last_map_id: user_data.last_map_id,
      # Set balance to nil since we don't store it in session
      balance: nil,
      # Set characters to empty list - should be loaded from DB when needed
      characters: []
    }
  end

  # Determine user role based on admin configuration
  defp determine_user_role(user) do
    admins = WandererApp.Env.admins()

    case Enum.empty?(admins) or user.hash in admins do
      true -> :admin
      false -> :user
    end
  end

  # Clear user cache from session
  defp clear_user_cache(conn) do
    delete_session(conn, :cached_user)
  end

  @doc """
  Helper function to invalidate user cache when user data changes.
  Call this after user updates to force cache refresh.
  """
  @spec invalidate_user_cache(Plug.Conn.t()) :: Plug.Conn.t()
  def invalidate_user_cache(conn) do
    clear_user_cache(conn)
  end
end
