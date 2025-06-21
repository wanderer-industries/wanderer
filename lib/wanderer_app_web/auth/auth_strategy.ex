defmodule WandererAppWeb.Auth.AuthStrategy do
  @moduledoc """
  Behaviour defining the contract for authentication strategies.

  Each strategy implements a specific authentication method (JWT, API key, etc.)
  and can be composed in the AuthPipeline for flexible authentication flows.
  """

  @doc """
  Authenticates the connection using the strategy's specific method.

  Returns:
    - `{:ok, conn, auth_data}` - Authentication successful, conn may have assigns added
    - `{:error, reason}` - Authentication failed with reason
    - `:skip` - Strategy doesn't apply to this request, try next strategy
  """
  @callback authenticate(Plug.Conn.t(), keyword()) ::
              {:ok, Plug.Conn.t(), map()} | {:error, atom() | String.t()} | :skip

  @doc """
  Returns the name of the strategy for logging and configuration.
  """
  @callback name() :: atom()

  @doc """
  Validates that the strategy can be used with the given options.
  Called at compile time.
  """
  @callback validate_opts(keyword()) :: :ok | {:error, String.t()}
end
