defmodule WandererApp.MapSystemCommentRepo do
  use WandererApp, :repository

  require Logger

  def get_by_id(comment_id),
    do: WandererApp.Api.MapSystemComment.by_id!(comment_id) |> Ash.load([:system])

  def get_by_system(system_id),
    do: WandererApp.Api.MapSystemComment.by_system_id(system_id)

  def create(comment), do: comment |> WandererApp.Api.MapSystemComment.create()
  def create!(comment), do: comment |> WandererApp.Api.MapSystemComment.create!()

  def destroy(comment) when not is_nil(comment),
    do:
      comment
      |> WandererApp.Api.MapSystemComment.destroy!()

  def destroy(_comment), do: :ok
end
