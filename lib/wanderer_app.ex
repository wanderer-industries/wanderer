defmodule WandererApp do
  @moduledoc """
  WandererApp keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  require Logger

  @doc """
  When used, dispatch to the appropriate domain service
  """
  def domain_service do
    quote do
    end
  end

  def application_service do
    quote do
    end
  end

  def repository do
    quote do
    end
  end

  def check(), do: {:ok, :ok}

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end

  def log_exception(kind, reason, stacktrace) do
    reason = Exception.normalize(kind, reason, stacktrace)

    crash_reason =
      case kind do
        :throw -> {{:nocatch, reason}, stacktrace}
        _ -> {reason, stacktrace}
      end

    Logger.error(
      Exception.format(kind, reason, stacktrace),
      crash_reason: crash_reason
    )
  end
end
