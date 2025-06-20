defmodule WandererAppWeb.Auth.AuthPipeline do
  @moduledoc """
  Unified authentication pipeline that supports multiple authentication strategies.

  This plug replaces the various auth plugs with a configurable, behavior-driven
  approach. Strategies are tried in order until one succeeds or all fail.

  ## Usage

      # In your router pipeline
      plug WandererAppWeb.Auth.AuthPipeline,
        strategies: [:map_api_key, :jwt],
        required: true,
        assign_as: :current_user
        
      # Optional authentication
      plug WandererAppWeb.Auth.AuthPipeline,
        strategies: [:map_api_key],
        required: false
  """

  import Plug.Conn
  require Logger

  @behaviour Plug

  @default_opts [
    strategies: [],
    required: true,
    assign_as: nil,
    error_status: 401,
    error_message: "Authentication required",
    feature_flag: nil
  ]

  @impl Plug
  def init(opts) do
    opts = Keyword.merge(@default_opts, opts)

    # Validate strategies exist
    Enum.each(opts[:strategies], fn strategy ->
      unless strategy_module(strategy) do
        raise ArgumentError, "Unknown authentication strategy: #{inspect(strategy)}"
      end
    end)

    opts
  end

  @impl Plug
  def call(conn, opts) do
    # Check feature flag first if specified
    if feature_flag = opts[:feature_flag] do
      if feature_disabled?(feature_flag) do
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(403, Jason.encode!(%{error: "This feature is disabled"}))
        |> halt()
      else
        authenticate_with_strategies(conn, opts)
      end
    else
      authenticate_with_strategies(conn, opts)
    end
  end

  defp authenticate_with_strategies(conn, opts) do
    strategies = opts[:strategies]

    case try_strategies(conn, strategies, opts) do
      {:ok, conn, auth_data} ->
        if opts[:assign_as] do
          assign(conn, opts[:assign_as], auth_data)
        else
          conn
        end

      {:error, _reason} ->
        if opts[:required] do
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(opts[:error_status], Jason.encode!(%{error: opts[:error_message]}))
          |> halt()
        else
          conn
        end
    end
  end

  defp try_strategies(_conn, [], _opts), do: {:error, :no_strategies}

  defp try_strategies(conn, [strategy | rest], opts) do
    strategy_mod = strategy_module(strategy)
    strategy_opts = opts[strategy] || []

    case strategy_mod.authenticate(conn, strategy_opts) do
      {:ok, conn, auth_data} ->
        Logger.debug("Authentication successful with strategy: #{strategy}")
        {:ok, conn, auth_data}

      :skip ->
        # Strategy doesn't apply, try next
        try_strategies(conn, rest, opts)

      {:error, reason} ->
        Logger.debug("Authentication failed with strategy #{strategy}: #{inspect(reason)}")
        # Try next strategy
        try_strategies(conn, rest, opts)
    end
  end

  defp strategy_module(strategy) do
    case strategy do
      :jwt -> WandererAppWeb.Auth.Strategies.JwtStrategy
      :map_api_key -> WandererAppWeb.Auth.Strategies.MapApiKeyStrategy
      :acl_key -> WandererAppWeb.Auth.Strategies.AclKeyStrategy
      :character_jwt -> WandererAppWeb.Auth.Strategies.CharacterJwtStrategy
      _ -> nil
    end
  end

  # Check if a feature flag is enabled (meaning the feature is disabled)
  defp feature_disabled?(flag) do
    function_name = get_function_name(flag)
    
    try do
      apply(WandererApp.Env, function_name, [])
    rescue
      UndefinedFunctionError ->
        Logger.error("AuthPipeline: WandererApp.Env.#{function_name}/0 function not found")
        false
    end
  end

  # Convert flag name to function name by appending '?' if not already present
  defp get_function_name(flag) when is_atom(flag) do
    flag_str = Atom.to_string(flag)
    
    if String.ends_with?(flag_str, "?") do
      flag
    else
      String.to_atom(flag_str <> "?")
    end
  end

end
