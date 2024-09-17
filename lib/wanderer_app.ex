defmodule WandererApp do
  @moduledoc """
  WandererApp keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

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
end
