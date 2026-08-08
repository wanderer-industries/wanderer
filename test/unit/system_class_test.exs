defmodule WandererApp.SystemClassTest do
  # `wormhole_system?/1` resolves static info via `CachedInfo`, which hits the
  # DB-backed cache, so this needs sandbox access rather than plain ExUnit.Case.
  use WandererApp.DataCase, async: true

  alias WandererApp.SystemClass

  describe "wormhole?/1" do
    test "returns true for c1-c6" do
      for class <- 1..6 do
        assert SystemClass.wormhole?(class), "class #{class} should be wormhole"
      end
    end

    test "returns true for thera and c13" do
      assert SystemClass.wormhole?(12)
      assert SystemClass.wormhole?(13)
    end

    test "returns true for drifter holes" do
      for class <- 14..18 do
        assert SystemClass.wormhole?(class), "class #{class} should be wormhole"
      end
    end

    test "returns false for known space" do
      refute SystemClass.wormhole?(7)
      refute SystemClass.wormhole?(8)
      refute SystemClass.wormhole?(9)
    end

    test "returns false for pochven and zarzakh" do
      refute SystemClass.wormhole?(25)
      refute SystemClass.wormhole?(10_100)
    end

    test "returns false for nil and unknown classes" do
      refute SystemClass.wormhole?(nil)
      refute SystemClass.wormhole?(999)
    end
  end

  describe "wormhole_classes/0" do
    test "returns the exact canonical set" do
      assert Enum.sort(SystemClass.wormhole_classes()) == [
               1,
               2,
               3,
               4,
               5,
               6,
               12,
               13,
               14,
               15,
               16,
               17,
               18
             ]
    end
  end

  describe "wormhole_system?/1" do
    test "returns false for non-integer input" do
      refute SystemClass.wormhole_system?("31000005")
      refute SystemClass.wormhole_system?(:not_an_id)
      refute SystemClass.wormhole_system?(nil)
    end

    test "returns false for an unresolvable solar system id" do
      refute SystemClass.wormhole_system?(-1)
    end
  end
end
