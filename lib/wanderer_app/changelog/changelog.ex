defmodule WandererApp.Changelog do
  use NimblePublisher,
    build: WandererApp.Changelog.File,
    from: Application.app_dir(:wanderer_app, "priv/changelog/CHANGELOG.md"),
    as: :files,
    highlighters: [:makeup_elixir, :makeup_erlang]

  # And finally export them
  def all_files, do: @files
end
