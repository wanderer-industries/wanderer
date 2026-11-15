defmodule WandererApp.Map.Homes do
  @moduledoc """
  The home systems other maps have declared, and the ways into them.

  Chains meet. A system somebody scans into is, now and then, where another group lives - and the
  useful thing to know about it is how one gets in: which k-space systems have a hole into that
  chain, what kind of space they sit in, and how many holes lie behind them.

  Only maps the person may already see are considered, so this says nothing they could not have
  found by opening those maps themselves.
  """

  require Logger

  # EVE gives every J-space system an id in this range, Thera and the shattered ones included
  @j_space_id 31_000_000

  # what the game calls high sec once it has rounded the number
  @high_sec 0.45

  @type home :: %{
          map_id: String.t(),
          map_name: String.t(),
          map_slug: String.t(),
          solar_system_id: integer()
        }

  @type node_info :: %{
          solar_system_id: integer(),
          name: String.t(),
          class: :high | :low | :null | :wormhole,
          security: number() | nil,
          holes: non_neg_integer(),
          home?: boolean(),
          mouth?: boolean()
        }

  @type chain :: %{
          nodes: [node_info()],
          edges: [%{source: integer(), target: integer()}]
        }

  @doc """
  The homes declared on the maps this person may see, other than the map they are looking at.
  """
  @spec known(map(), String.t() | nil) :: [home()]
  def known(current_user, except_map_id \\ nil)

  def known(nil, _except_map_id), do: []

  def known(current_user, except_map_id) do
    case WandererApp.Maps.get_available_maps(current_user) do
      {:ok, maps} ->
        maps
        |> Enum.reject(&(&1.id == except_map_id))
        |> Enum.filter(&is_integer(&1.home_solar_system_id))
        |> Enum.map(
          &%{
            map_id: &1.id,
            map_name: &1.name,
            map_slug: &1.slug,
            solar_system_id: &1.home_solar_system_id
          }
        )

      _ ->
        []
    end
  end

  @doc """
  The way in, drawn: every system on a shortest path from a mouth of the chain to the home, and
  the connections between them.

  It is the chain as their map has it, cut down to what leads in - so the reader sees the route
  rather than a list of names.
  """
  @spec ways_in(String.t(), integer()) :: chain()
  def ways_in(map_id, home_solar_system_id)
      when is_binary(map_id) and is_integer(home_solar_system_id) do
    with {:ok, systems} <- WandererApp.MapSystemRepo.get_visible_by_map(map_id),
         {:ok, connections} <- WandererApp.MapConnectionRepo.get_by_map(map_id) do
      {depths, parents} = walk_from(connections, home_solar_system_id)

      mouth_ids =
        systems
        |> mouths(connections)
        |> Enum.filter(&Map.has_key?(depths, &1))

      {ids, edges} = paths_in(mouth_ids, parents, home_solar_system_id)

      on_the_way = MapSet.new(ids)

      %{
        systems:
          systems
          |> Enum.filter(&MapSet.member?(on_the_way, &1.solar_system_id))
          |> Enum.sort_by(&{Map.get(depths, &1.solar_system_id, 0), &1.name}),
        connections: Enum.filter(connections, &edge?(&1, edges)),
        markers:
          Map.new(ids, fn solar_system_id ->
            {solar_system_id,
             %{
               holes: Map.get(depths, solar_system_id, 0),
               home?: solar_system_id == home_solar_system_id,
               mouth?: solar_system_id in mouth_ids
             }}
          end)
      }
    else
      _ -> empty()
    end
  end

  @doc """
  Turns what `ways_in/2` selected into what goes over the wire.

  The map already knows how to draw a system, so what a shared home hands over is the same shape
  the map itself is given - the systems and the connections between them - with only the part
  this feature adds on top: how many holes deep each system sits, and whether it is the home or a
  way into it. Anything reading this draws it with the map's own renderer rather than one of its
  own.
  """
  @spec to_wire(map()) :: map()
  def to_wire(%{systems: systems, connections: connections, markers: markers}) do
    %{
      "systems" => Enum.map(systems, &WandererAppWeb.MapEventHandler.map_ui_system/1),
      "connections" => Enum.map(connections, &WandererAppWeb.MapEventHandler.map_ui_connection/1),
      "markers" =>
        Map.new(markers, fn {solar_system_id, marker} ->
          {to_string(solar_system_id),
           %{
             "holes" => marker.holes,
             "home" => marker[:home?],
             "mouth" => marker[:mouth?]
           }}
        end)
    }
  end

  def to_wire(_other), do: %{"systems" => [], "connections" => [], "markers" => %{}}

  def ways_in(_map_id, _home), do: empty()

  defp empty, do: %{systems: [], connections: [], markers: %{}}

  defp edge?(%{solar_system_source: source, solar_system_target: target}, edges),
    do:
      Enum.any?(
        edges,
        &((&1.source == source and &1.target == target) or
            (&1.source == target and &1.target == source))
      )

  @doc """
  Walks back from every mouth to the home, collecting what is on the way.
  """
  @spec paths_in([integer()], %{integer() => integer()}, integer()) ::
          {[integer()], [%{source: integer(), target: integer()}]}
  def paths_in(mouth_ids, parents, home_solar_system_id) do
    Enum.reduce(mouth_ids, {MapSet.new([home_solar_system_id]), MapSet.new()}, fn mouth,
                                                                                  {ids, edges} ->
      walk_back(mouth, parents, home_solar_system_id, MapSet.put(ids, mouth), edges)
    end)
    |> then(fn {ids, edges} ->
      {MapSet.to_list(ids),
       edges |> MapSet.to_list() |> Enum.map(fn {a, b} -> %{source: a, target: b} end)}
    end)
  end

  @doc """
  The k-space systems on a map that have a hole into J-space - the places a chain can be entered
  from. Whether a given one leads to the home is a separate question, answered by the depths.
  """
  @spec mouths([map()], [map()]) :: [integer()]
  def mouths(systems, connections) do
    on_map =
      systems
      |> Enum.filter(&Map.get(&1, :visible, true))
      |> MapSet.new(& &1.solar_system_id)

    connections
    |> Enum.flat_map(fn %{solar_system_source: source, solar_system_target: target} ->
      cond do
        j_space?(source) and k_space?(target) -> [target]
        k_space?(source) and j_space?(target) -> [source]
        true -> []
      end
    end)
    |> Enum.filter(&MapSet.member?(on_map, &1))
    |> Enum.uniq()
  end

  @doc """
  How many holes lie between the home and every system its chain reaches, home itself being none.
  """
  @spec hole_depths([map()], integer()) :: %{integer() => non_neg_integer()}
  def hole_depths(connections, home_solar_system_id) do
    {depths, _parents} = walk_from(connections, home_solar_system_id)
    depths
  end

  @doc """
  The same walk, keeping the step each system was first reached from - which is what turns a
  depth into a path back to the home.
  """
  @spec walk_from([map()], integer()) ::
          {%{integer() => non_neg_integer()}, %{integer() => integer()}}
  def walk_from(connections, home_solar_system_id) do
    neighbours =
      Enum.reduce(connections, %{}, fn %{
                                         solar_system_source: source,
                                         solar_system_target: target
                                       },
                                       acc ->
        acc
        |> Map.update(source, [target], &[target | &1])
        |> Map.update(target, [source], &[source | &1])
      end)

    walk(neighbours, [home_solar_system_id], %{home_solar_system_id => 0}, %{}, 1)
  end

  defp walk(_neighbours, [], depths, parents, _depth), do: {depths, parents}

  defp walk(neighbours, frontier, depths, parents, depth) do
    {next, depths, parents} =
      Enum.reduce(frontier, {[], depths, parents}, fn system, acc ->
        neighbours
        |> Map.get(system, [])
        |> Enum.reduce(acc, fn neighbour, {next, depths, parents} ->
          if Map.has_key?(depths, neighbour) do
            {next, depths, parents}
          else
            {[neighbour | next], Map.put(depths, neighbour, depth),
             Map.put(parents, neighbour, system)}
          end
        end)
      end)

    walk(neighbours, Enum.reverse(next), depths, parents, depth + 1)
  end

  defp walk_back(system, parents, home_solar_system_id, ids, edges) do
    case Map.get(parents, system) do
      nil ->
        {ids, edges}

      parent ->
        edges = MapSet.put(edges, {min(system, parent), max(system, parent)})
        ids = MapSet.put(ids, parent)

        if parent == home_solar_system_id do
          {ids, edges}
        else
          walk_back(parent, parents, home_solar_system_id, ids, edges)
        end
    end
  end

  defp j_space?(solar_system_id), do: solar_system_id >= @j_space_id

  defp k_space?(solar_system_id), do: solar_system_id < @j_space_id
end
