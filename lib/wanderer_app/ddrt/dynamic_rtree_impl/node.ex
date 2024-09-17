defmodule DDRT.DynamicRtreeImpl.Node do
  @moduledoc false

  def new(gen, seed) do
    gen[:next].(seed)
  end
end
