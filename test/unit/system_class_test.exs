defmodule WandererApp.SystemClassTest do
  use ExUnit.Case, async: true

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
end
