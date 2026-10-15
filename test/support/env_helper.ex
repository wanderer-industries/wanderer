defmodule WandererApp.EnvHelper do
  @moduledoc """
  Test helpers for temporarily overriding application environment configuration.

  ## Usage

      import WandererApp.EnvHelper

      test "something with custom config" do
        with_env_override(:map_subscriptions_enabled, true) do
          # Your test code here
          # Environment will be restored after block
        end
      end
  """

  @doc """
  Temporarily overrides an application environment variable for the duration of the block.

  The original value is automatically restored after the block executes, even if an
  exception is raised.

  This is a macro on purpose: as a plain function the `do` block would be
  evaluated as an argument, before the override is applied.

  ## Parameters

    - `key` - The environment key to override (atom)
    - `value` - The value to set temporarily
    - `block` - The code block to execute with the overridden value

  ## Examples

      with_env_override(:sse_enabled, true) do
        assert WandererApp.Env.sse_enabled?() == true
      end
  """
  defmacro with_env_override(key, value, do: block) do
    quote do
      app = :wanderer_app
      key = unquote(key)
      original = Application.get_env(app, key)

      try do
        Application.put_env(app, key, unquote(value))
        unquote(block)
      after
        if original != nil do
          Application.put_env(app, key, original)
        else
          Application.delete_env(app, key)
        end
      end
    end
  end
end
