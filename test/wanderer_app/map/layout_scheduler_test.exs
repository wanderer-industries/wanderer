defmodule WandererApp.Map.LayoutSchedulerTest do
  use ExUnit.Case, async: true

  alias WandererApp.Map.LayoutScheduler

  test "newer additions and selections win without losing passages" do
    older = request(%{1 => :old_addition}, %{10 => 1}, [:first_jump])
    newer = request(%{1 => :new_addition, 2 => :second_addition}, %{10 => 2}, [:second_jump])

    merged = LayoutScheduler.merge_requests(older, newer)

    assert merged.additions == %{1 => :new_addition, 2 => :second_addition}
    assert merged.selections == %{10 => 2}
    assert merged.jumps == [:first_jump, :second_jump]
    assert merged.pending_system_ids == MapSet.new([1, 2])
    assert merged.publish_system_ids == MapSet.new([1, 2])
  end

  defp request(additions, selections, jumps) do
    ids = additions |> Map.keys() |> MapSet.new()

    %{
      pending_system_ids: ids,
      publish_system_ids: ids,
      selections: selections,
      additions: additions,
      jumps: jumps
    }
  end
end
