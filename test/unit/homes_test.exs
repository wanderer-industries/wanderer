defmodule WandererApp.Map.HomesTest do
  @moduledoc """
  Finding the ways into somebody else's home: which systems are mouths, how deep they sit, and
  what kind of space they are in.
  """

  use ExUnit.Case, async: true

  alias WandererApp.Map.Homes

  @jita 30_000_142
  @amarr 30_002_187
  @home 31_001_269
  @deeper 31_001_270
  @stray 31_009_999

  defp system(id, visible \\ true), do: %{solar_system_id: id, visible: visible}
  defp connection(source, target), do: %{solar_system_source: source, solar_system_target: target}

  describe "mouths/2" do
    test "a k-space system with a hole into the chain is a way in" do
      systems = [system(@jita), system(@home)]

      assert Homes.mouths(systems, [connection(@home, @jita)]) == [@jita]
      assert Homes.mouths(systems, [connection(@jita, @home)]) == [@jita]
    end

    test "gates and holes inside the chain are not ways in" do
      systems = [system(@jita), system(@amarr), system(@home), system(@deeper)]

      assert Homes.mouths(systems, [connection(@jita, @amarr), connection(@home, @deeper)]) == []
    end

    test "a system nobody can see on the map is not offered as a way in" do
      systems = [system(@jita, false), system(@amarr), system(@home)]

      connections = [connection(@home, @jita), connection(@home, @amarr)]

      assert Homes.mouths(systems, connections) == [@amarr]
    end
  end

  describe "hole_depths/2" do
    test "counts the holes between home and what its chain reaches" do
      connections = [connection(@home, @deeper), connection(@deeper, @jita)]

      depths = Homes.hole_depths(connections, @home)

      assert depths[@home] == 0
      assert depths[@deeper] == 1
      assert depths[@jita] == 2
    end

    test "a chain nobody joined to the home is not counted" do
      connections = [connection(@home, @deeper), connection(@stray, @amarr)]

      depths = Homes.hole_depths(connections, @home)

      refute Map.has_key?(depths, @amarr)
    end
  end

  describe "walk_from/2 and paths_in/3" do
    test "a path back to the home keeps what is on the way and nothing else" do
      connections = [
        connection(@home, @deeper),
        connection(@deeper, @jita),
        # a branch of the chain that leads somewhere else
        connection(@home, @stray)
      ]

      {depths, parents} = Homes.walk_from(connections, @home)

      assert depths[@jita] == 2

      {ids, edges} = Homes.paths_in([@jita], parents, @home)

      assert Enum.sort(ids) == Enum.sort([@home, @deeper, @jita])
      refute @stray in ids

      assert Enum.sort_by(edges, & &1.source) ==
               [
                 %{source: min(@home, @deeper), target: max(@home, @deeper)},
                 %{source: min(@deeper, @jita), target: max(@deeper, @jita)}
               ]
               |> Enum.sort_by(& &1.source)
    end

    test "two mouths sharing a stretch of chain share its edges" do
      connections = [
        connection(@home, @deeper),
        connection(@deeper, @jita),
        connection(@deeper, @amarr)
      ]

      {_depths, parents} = Homes.walk_from(connections, @home)

      {ids, edges} = Homes.paths_in([@jita, @amarr], parents, @home)

      assert Enum.sort(ids) == Enum.sort([@home, @deeper, @jita, @amarr])
      assert length(edges) == 3
    end
  end
end
