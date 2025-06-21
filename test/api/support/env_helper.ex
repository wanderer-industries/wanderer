defmodule WandererApp.EnvHelper do
  @moduledoc """
  Helper module for loading environment variables from .env file for API tests.
  """

  @env_file Path.join([File.cwd!(), "test", "api", ".env"])

  def load_env_file do
    if File.exists?(@env_file) do
      @env_file
      |> File.read!()
      |> String.split("\n")
      |> Enum.each(&parse_line/1)

      :ok
    else
      {:error, ".env file not found at #{@env_file}"}
    end
  end

  defp parse_line(line) do
    line = String.trim(line)

    # Skip empty lines and comments
    if line == "" or String.starts_with?(line, "#") do
      :ok
    else
      case String.split(line, "=", parts: 2) do
        [key, value] ->
          key = String.trim(key)
          value = String.trim(value)
          System.put_env(key, value)

        _ ->
          :ok
      end
    end
  end

  @doc """
  Get required environment variable or raise error.
  """
  def get_env!(key) do
    case System.get_env(key) do
      nil ->
        raise """
        Missing required environment variable: #{key}

        Please create test/api/.env file with the following variables:
        - API_TOKEN: Bearer token from your map's API settings
        - MAP_SLUG: The slug of your test map

        See test/api/.env.example for a template.
        """

      value ->
        value
    end
  end

  @doc """
  Get optional environment variable with default.
  """
  def get_env(key, default \\ nil) do
    System.get_env(key, default)
  end

  @doc """
  Check if all required environment variables are set.
  """
  def check_required_env_vars do
    required = ["API_TOKEN", "MAP_SLUG"]
    missing = Enum.filter(required, fn key -> System.get_env(key) == nil end)

    if missing == [] do
      :ok
    else
      {:error, "Missing required environment variables: #{Enum.join(missing, ", ")}"}
    end
  end
end
