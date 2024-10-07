defmodule WandererApp.Utils.JSONUtil do
  @moduledoc false

  def read_json(filename) do
    {:ok, body} = File.read(filename)
    Jason.decode(body)
  end

  def map_json({:ok, json}, mapper) do
    Enum.map(json, mapper)
  end
end
