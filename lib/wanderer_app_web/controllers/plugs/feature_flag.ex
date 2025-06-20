defmodule WandererAppWeb.Plugs.FeatureFlag do
  @moduledoc """
  A parameterized plug for checking feature flags.

  This plug replaces the specific feature flag plugs (CheckApiDisabled, etc.) 
  with a single configurable plug that can check any feature flag.

  ## Usage

      # In router or controller
      plug WandererAppWeb.Plugs.FeatureFlag, 
        flag: :public_api_disabled, 
        status: 403, 
        message: "Public API is disabled"
        
      # With custom error handling
      plug WandererAppWeb.Plugs.FeatureFlag,
        flag: :character_api_disabled,
        on_error: fn conn -> 
          conn
          |> put_status(503)
          |> Phoenix.Controller.json(%{error: "Service temporarily unavailable"})
          |> halt()
        end
  """

  import Plug.Conn
  require Logger

  @type flag_opt :: atom()
  @type status_opt :: integer()
  @type message_opt :: String.t()
  @type error_handler_opt :: (Plug.Conn.t() -> Plug.Conn.t())

  @type opts :: [
          flag: flag_opt(),
          status: status_opt(),
          message: message_opt(),
          on_error: error_handler_opt()
        ]

  @doc """
  Initialize the plug with options.

  ## Options

  - `:flag` (required) - The feature flag to check (atom)
  - `:status` - HTTP status code to return when flag is enabled (default: 403)
  - `:message` - Error message to return (default: "Feature is disabled")
  - `:on_error` - Custom error handler function (overrides status/message)
  """
  @spec init(opts()) :: opts()
  def init(opts) do
    flag = Keyword.fetch!(opts, :flag)

    unless is_atom(flag) do
      raise ArgumentError, "FeatureFlag plug requires :flag to be an atom, got: #{inspect(flag)}"
    end

    # Convert flag name to function name (add question mark if not present)
    function_name = get_function_name(flag)
    
    # Validate that the flag function exists
    unless function_exported?(WandererApp.Env, function_name, 0) do
      raise ArgumentError,
            "FeatureFlag plug: WandererApp.Env.#{function_name}/0 function not found. " <>
              "Please ensure the feature flag function exists in WandererApp.Env module."
    end

    Keyword.put_new(opts, :status, 403)
    |> Keyword.put_new(:message, "Feature is disabled")
  end

  @doc """
  Check the feature flag and halt the connection if the feature is disabled.
  """
  @spec call(Plug.Conn.t(), opts()) :: Plug.Conn.t()
  def call(conn, opts) do
    flag = Keyword.fetch!(opts, :flag)

    if feature_disabled?(flag) do
      handle_disabled_feature(conn, opts)
    else
      conn
    end
  end

  # Check if the feature flag is enabled (meaning the feature is disabled)
  defp feature_disabled?(flag) do
    function_name = get_function_name(flag)
    
    try do
      apply(WandererApp.Env, function_name, [])
    rescue
      UndefinedFunctionError ->
        Logger.error("FeatureFlag plug: WandererApp.Env.#{function_name}/0 function not found")
        # Default to disabled (true) when feature flag is not found
        true
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

  # Handle when a feature is disabled
  defp handle_disabled_feature(conn, opts) do
    case Keyword.get(opts, :on_error) do
      nil ->
        # Use default status/message handling
        status = Keyword.get(opts, :status, 403)
        message = Keyword.get(opts, :message, "Feature is disabled")

        conn
        |> send_resp(status, message)
        |> halt()

      error_handler when is_function(error_handler, 1) ->
        # Use custom error handler
        error_handler.(conn)
    end
  end

  @doc """
  Helper function to create a feature flag plug configuration.

  ## Examples

      # Simple usage
      feature_flag(:public_api_disabled)
      
      # With custom message
      feature_flag(:character_api_disabled, "Character API is temporarily unavailable")
      
      # With custom status and message
      feature_flag(:zkill_preload_disabled, 503, "Kill feed service is down")
  """
  def feature_flag(flag, message \\ nil, status \\ 403) do
    opts = [flag: flag, status: status]

    if message do
      Keyword.put(opts, :message, message)
    else
      opts
    end
  end

  @doc """
  Helper to create a JSON API error response for feature flags.
  """
  def json_error_handler(message) do
    fn conn ->
      conn
      |> put_status(403)
      |> Phoenix.Controller.json(%{
        error: %{
          code: "FEATURE_DISABLED",
          message: message,
          status: 403
        }
      })
      |> halt()
    end
  end
end
