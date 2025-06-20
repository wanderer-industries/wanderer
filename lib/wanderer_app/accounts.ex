defmodule WandererApp.Accounts do
  @moduledoc """
  Context module for user account operations.
  
  This module provides a higher-level interface for user operations
  and handles cache invalidation automatically.
  """

  alias WandererApp.Api.User
  alias WandererAppWeb.Plugs.SetUser

  @doc """
  Get user by ID with character data loaded.
  """
  @spec get_user(String.t()) :: {:ok, map()} | {:error, term()}
  def get_user(user_id) do
    User.by_id(user_id, load: :characters)
  end

  @doc """
  Get user by hash with character data loaded.
  """
  @spec get_user_by_hash(String.t()) :: {:ok, map()} | {:error, term()}
  def get_user_by_hash(hash) do
    User.by_hash(hash, load: :characters)
  end

  @doc """
  Update user balance and invalidate cache.
  """
  @spec update_balance(map(), map()) :: {:ok, map()} | {:error, term()}
  def update_balance(user, params) do
    # The cache invalidation will happen automatically when the next request
    # comes in since we don't have access to the conn here.
    # Controllers that update users should call invalidate_user_cache/1
    User.update_balance(user, params)
  end

  @doc """
  Update user's last map and invalidate cache.
  """
  @spec update_last_map(map(), map()) :: {:ok, map()} | {:error, term()}
  def update_last_map(user, params) do
    User.update_last_map(user, params)
  end

  @doc """
  Helper to invalidate user cache in controllers after user updates.
  Call this in controllers after any user modification.
  """
  @spec invalidate_user_cache(Plug.Conn.t()) :: Plug.Conn.t()
  def invalidate_user_cache(conn) do
    SetUser.invalidate_user_cache(conn)
  end
end