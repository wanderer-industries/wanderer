defmodule WandererAppWeb.Deprecation do
  @moduledoc """
  Macros and utilities for marking code as deprecated.

  Provides compile-time warnings and runtime tracking for deprecated code.
  """

  @doc """
  Mark a controller or module as deprecated.

  Usage:
      defmodule MyController do
        use WandererAppWeb.Deprecation, 
          message: "Use V1 API instead",
          removal_date: ~D[2025-12-31]
      end
  """
  defmacro __using__(opts) do
    message = Keyword.get(opts, :message, "This module is deprecated")
    removal_date = Keyword.get(opts, :removal_date, ~D[2025-12-31])

    quote do
      @deprecated message: unquote(message), removal_date: unquote(removal_date)

      # Add module attribute for runtime inspection
      @deprecation_info %{
        deprecated: true,
        message: unquote(message),
        removal_date: unquote(removal_date),
        module: __MODULE__
      }

      def __deprecation_info__, do: @deprecation_info

      # Register the after_compile callback
      @after_compile {__MODULE__, :__after_compile__}

      # Log deprecation warning on first use
      def __after_compile__(env, _bytecode) do
        # Safely check config with fallback to avoid compilation order issues
        log_deprecations = 
          try do
            Application.get_env(:wanderer_app, :log_deprecations, true)
          rescue
            _ -> true
          end

        if log_deprecations do
          IO.warn(
            """
            DEPRECATED: #{unquote(message)}
            Module: #{env.module}
            Removal date: #{unquote(removal_date)}
            """,
            []
          )
        end
      end
    end
  end

  @doc """
  Mark a function as deprecated.

  Usage:
      @deprecated "Use new_function/1 instead"
      def old_function(arg) do
        # ...
      end
  """
  defmacro deprecated_function(name, arity, opts \\ []) do
    message = Keyword.get(opts, :message, "Function #{name}/#{arity} is deprecated")
    alternative = Keyword.get(opts, :use_instead)

    quote do
      @deprecated "#{unquote(message)}#{if unquote(alternative), do: " Use #{unquote(alternative)} instead.", else: ""}"
    end
  end

  @doc """
  Check if a module is deprecated at runtime.
  """
  def deprecated?(module) when is_atom(module) do
    if function_exported?(module, :__deprecation_info__, 0) do
      module.__deprecation_info__()
    else
      nil
    end
  end

  @doc """
  Get all deprecated modules in the application.
  """
  def list_deprecated_modules do
    # Get all loaded modules that start with WandererAppWeb
    :code.all_loaded()
    |> Enum.map(&elem(&1, 0))
    |> Enum.filter(fn module ->
      module_str = to_string(module)
      String.starts_with?(module_str, "Elixir.WandererAppWeb")
    end)
    |> Enum.map(fn module ->
      {module, deprecated?(module)}
    end)
    |> Enum.filter(fn {_, info} -> info != nil end)
  end

  @doc """
  Generate a deprecation report.
  """
  def deprecation_report do
    deprecated_modules = list_deprecated_modules()

    if length(deprecated_modules) > 0 do
      IO.puts("""

      ===== DEPRECATION REPORT =====

      The following modules are deprecated and scheduled for removal:

      #{format_deprecated_modules(deprecated_modules)}

      Total deprecated modules: #{length(deprecated_modules)}

      To migrate:
      1. Update all references to use /api/v1 endpoints
      2. Review the migration guide at https://docs.wanderer.app/api/migration
      3. Test with FEATURE_LEGACY_API=false to ensure compatibility

      ==============================
      """)
    else
      IO.puts("No deprecated modules found.")
    end
  end

  defp format_deprecated_modules(modules) do
    modules
    |> Enum.map(fn {module, info} ->
      """
      - #{inspect(module)}
        Message: #{info.message}
        Removal date: #{info.removal_date}
      """
    end)
    |> Enum.join("\n")
  end
end
