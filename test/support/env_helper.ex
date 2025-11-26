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

  ## Parameters

    - `key` - The environment key to override (atom)
    - `value` - The value to set temporarily
    - `block` - The code block to execute with the overridden value

  ## Examples

      with_env_override(:sse_enabled, true) do
        assert WandererApp.Env.sse_enabled?() == true
      end
  """
  def with_env_override(key, value, do: block) do
    app = :wanderer_app
    original = Application.get_env(app, key)

    try do
      Application.put_env(app, key, value)
      block
    after
      if original != nil do
        Application.put_env(app, key, original)
      else
        Application.delete_env(app, key)
      end
    end
  end
end
