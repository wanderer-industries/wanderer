defmodule WandererApp.Changelog.File do
  @enforce_keys [:id, :title, :body]
  defstruct [:id, :title, :body]

  def build(_filename, attrs, body) do
    struct!(__MODULE__, [id: ~c"changelog", body: body] ++ Map.to_list(attrs))
  end
end
