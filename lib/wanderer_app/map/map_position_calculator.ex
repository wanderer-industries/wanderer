defmodule WandererApp.Map.PositionCalculator do
  @moduledoc false
  require Logger

  # Node height
  @h 34
  # Node weight
  @w 130
  # Nodes margin
  @m_x 50
  @m_y 41

  @start_x 0
  @start_y 0

  def get_system_bounding_rect(%{position_x: x, position_y: y} = _system) do
    [{x, x + @w}, {y, y + @h}]
  end

  def get_system_bounding_rect(_system), do: [{0, 0}, {0, 0}]

  def get_new_system_position(nil, rtree_name, opts) do
    {:ok, {x, y}} = rtree_name |> check_system_available_positions(@start_x, @start_y, 1, opts)
    %{x: x, y: y}
  end

  def get_new_system_position(
        %{position_x: start_x, position_y: start_y} = _old_system,
        rtree_name,
        opts
      ) do
    {:ok, {x, y}} = rtree_name |> check_system_available_positions(start_x, start_y, 1, opts)

    %{x: x, y: y}
  end

  defp check_system_available_positions(_rtree_name, _start_x, _start_y, 100, _opts),
    do: {:ok, {@start_x, @start_y}}

  defp check_system_available_positions(rtree_name, start_x, start_y, level, opts) do
    possible_positions = get_available_positions(level, start_x, start_y, opts)

    case get_available_position(possible_positions, rtree_name) do
      {:ok, nil} ->
        rtree_name |> check_system_available_positions(start_x, start_y, level + 1, opts)

      {:ok, position} ->
        {:ok, position}
    end
  end

  defp get_available_position([], _rtree_name), do: {:ok, nil}

  defp get_available_position([position | rest], rtree_name) do
    if is_available_position(position, rtree_name) do
      {:ok, position}
    else
      get_available_position(rest, rtree_name)
    end
  end

  defp is_available_position({x, y} = _position, rtree_name) do
    case DDRT.query(get_system_bounding_rect(%{position_x: x, position_y: y}), rtree_name) do
      {:ok, []} ->
        true

      {:ok, _} ->
        false

      _ ->
        true
    end
  end

  def get_available_positions(level, x, y, opts),
    do: adjusted_coordinates(1 + level * 2, x, y, opts)

  defp edge_coordinates(n, _opts) when n > 1 do
    min = -div(n, 2)
    max = div(n, 2)
    # Top edge
    top_edge = for x <- min..max, do: {x, min}
    # Right edge
    right_edge = for y <- min..max, do: {max, y}
    # Bottom edge
    bottom_edge = for x <- max..min, do: {x, max}
    # Left edge
    left_edge = for y <- max..min, do: {min, y}

    # Combine all edges in clockwise order
    (right_edge ++ bottom_edge ++ left_edge ++ top_edge)
    |> Enum.uniq()
  end

  defp sorted_edge_coordinates(n, opts) when n > 1 do
    coordinates = edge_coordinates(n, opts)
    start_index = get_start_index(n, opts[:layout])

    Enum.slice(coordinates, start_index, length(coordinates) - start_index) ++
      Enum.slice(coordinates, 0, start_index)
  end

  defp get_start_index(n, "left_to_right"), do: div(n, 2)

  defp get_start_index(n, "top_to_bottom"), do: div(n, 2) + n - 1

  defp adjusted_coordinates(n, start_x, start_y, opts) when n > 1 do
    sorted_coords = sorted_edge_coordinates(n, opts)

    Enum.map(sorted_coords, fn {x, y} ->
      {
        start_x + x * (@w + @m_x),
        start_y + y * (@h + @m_y)
      }
    end)
  end
end
