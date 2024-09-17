defmodule DDRT.DynamicRtreeImpl.BoundingBoxGenerator do
  @moduledoc false

  def generate(n, size, result) do
    s = size / 2
    x = Enum.random(-180..180)
    y = Enum.random(-90..90)

    if n > 0,
      do: generate(n - 1, size, [[{x - s, x + s}, {y - s, y + s}]] ++ result),
      else: result
  end
end
