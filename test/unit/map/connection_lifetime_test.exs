defmodule WandererApp.Map.ConnectionLifetimeTest do
  use ExUnit.Case, async: true

  alias WandererApp.Map.ConnectionLifetime

  @now ~U[2026-09-22 12:00:00Z]

  describe "initial_time_status/4" do
    test "assigns a 16-hour status to every drifter entrance" do
      for wormhole_type <- ~w(B735 C414 R259 S877 V928) do
        assert ConnectionLifetime.initial_time_status(7, 14, 2, wormhole_type) == 4
      end
    end

    test "preserves existing class and frigate lifetimes" do
      assert ConnectionLifetime.initial_time_status(7, 1, 2, nil) == 4
      assert ConnectionLifetime.initial_time_status(7, 5, 2, nil) == 5
      assert ConnectionLifetime.initial_time_status(7, 14, 0, "B735") == 3
      assert ConnectionLifetime.initial_time_status(7, 9, 2, nil) == 0
    end
  end

  describe "drifter_wormhole_expired?/3" do
    test "expires a drifter connection at the 16-hour boundary" do
      inserted_at = DateTime.add(@now, -(16 * 60 * 60), :second)

      for wormhole_type <- ~w(B735 C414 R259 S877 V928) do
        assert ConnectionLifetime.drifter_wormhole_expired?(wormhole_type, inserted_at, @now)
      end
    end

    test "does not expire a drifter connection before 16 hours" do
      inserted_at = DateTime.add(@now, -(16 * 60 * 60 - 1), :second)

      refute ConnectionLifetime.drifter_wormhole_expired?("V928", inserted_at, @now)
    end

    test "does not apply the drifter limit to other connections" do
      inserted_at = DateTime.add(@now, -(24 * 60 * 60), :second)

      refute ConnectionLifetime.drifter_wormhole_expired?("N062", inserted_at, @now)
      refute ConnectionLifetime.drifter_wormhole_expired?("R474", inserted_at, @now)
      refute ConnectionLifetime.drifter_wormhole_expired?("B735", nil, @now)
    end
  end
end
