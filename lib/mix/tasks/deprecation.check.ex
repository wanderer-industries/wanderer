defmodule Mix.Tasks.Deprecation.Check do
  @moduledoc """
  Mix task to check for deprecated API usage and generate reports.

  Usage:
      mix deprecation.check [--strict]
      
  Options:
      --strict  Exit with non-zero code if deprecated code is found
  """

  use Mix.Task
  alias WandererAppWeb.Deprecation

  @shortdoc "Check for deprecated API usage"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [strict: :boolean])
    strict = Keyword.get(opts, :strict, false)

    Mix.Task.run("compile")

    IO.puts("\n🔍 Checking for deprecated API usage...\n")

    # Generate deprecation report
    Deprecation.deprecation_report()

    # Check for deprecated modules
    deprecated_modules = Deprecation.list_deprecated_modules()

    if length(deprecated_modules) > 0 do
      IO.puts("""

      ⚠️  WARNING: #{length(deprecated_modules)} deprecated modules found!

      These modules are scheduled for removal and should not be used in new code.
      """)

      if strict do
        Mix.raise("Deprecated modules found. Fix these issues before proceeding.")
      end
    else
      IO.puts("✅ No deprecated modules found!")
    end

    # Check environment
    check_environment_setup()

    IO.puts("\n✨ Deprecation check complete!\n")
  end

  defp check_environment_setup do
    IO.puts("\n📋 Environment Check:")

    # Check if FEATURE_LEGACY_API is set
    legacy_api = System.get_env("FEATURE_LEGACY_API")

    case legacy_api do
      "false" ->
        IO.puts("  ✅ FEATURE_LEGACY_API=false - Legacy APIs explicitly disabled")

      nil ->
        IO.puts("  ⚠️  FEATURE_LEGACY_API not set - Legacy APIs enabled by default in dev/test")
        IO.puts("     Set to 'false' to test without legacy endpoints")

      "true" ->
        IO.puts("  ⚠️  FEATURE_LEGACY_API=true - Legacy APIs explicitly enabled")

      other ->
        IO.puts("  ⚠️  FEATURE_LEGACY_API=#{other} - Legacy APIs enabled (any value except 'false' enables them)")
    end

    # Check current environment
    env = Application.get_env(:wanderer_app, :env, :dev)
    IO.puts("  ℹ️  Current environment: #{env}")

    case env do
      :prod ->
        IO.puts("     Legacy APIs are allowed in production (until sunset date)")

      env when env in [:dev, :test] ->
        IO.puts("     Legacy APIs are enabled by default (set FEATURE_LEGACY_API=false to disable)")

      _ ->
        IO.puts("     Unknown environment")
    end
  end
end
