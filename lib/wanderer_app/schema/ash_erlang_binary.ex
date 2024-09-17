defmodule WandererApp.Schema.AshErlangBinary do
  use Ash.Type

  @impl Ash.Type
  def storage_type, do: :binary

  @impl Ash.Type
  def cast_input(value, _) do
    {:ok, value}
  end

  @impl Ash.Type
  def cast_stored(value, _) when not is_nil(value),
    do: {:ok, :erlang.binary_to_term(value)}

  @impl Ash.Type
  def cast_stored(value, _), do: {:ok, value}

  @impl Ash.Type
  def dump_to_native(value, _) when not is_nil(value), do: {:ok, :erlang.term_to_binary(value)}

  @impl Ash.Type
  def dump_to_native(value, _), do: {:ok, value}
end
