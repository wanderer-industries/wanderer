defmodule WandererApp.Api.Preparations.LoadCharacter do
  @moduledoc false

  use Ash.Resource.Preparation
  require Ash.Query

  def prepare(query, _params, _) do
    query
    |> Ash.Query.load([:character])
  end
end
