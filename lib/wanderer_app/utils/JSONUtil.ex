defmodule WandererApp.Utils.JSONUtil do
  @moduledoc false

  def read_json(filename) do
    {:ok, body} = File.read(filename)
    Jason.decode(body)
  end

  def read_json!(filename),
    do:
      filename
      |> File.read!()
      |> Jason.decode!()
end
