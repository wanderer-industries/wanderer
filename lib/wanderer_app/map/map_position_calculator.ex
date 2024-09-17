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

  def get_new_system_position(nil, rtree_name) do
    {:ok, {x, y}} = rtree_name |> _check_system_available_positions(@start_x, @start_y, 1)
    %{x: x, y: y}
  end

  def get_new_system_position(
        %{position_x: start_x, position_y: start_y} = _old_system,
        rtree_name
      ) do
    {:ok, {x, y}} = rtree_name |> _check_system_available_positions(start_x, start_y, 1)
    %{x: x, y: y}
  end

  defp _check_system_available_positions(_rtree_name, _start_x, _start_y, 100) do
    {:ok, {@start_x, @start_y}}
  end

  defp _check_system_available_positions(rtree_name, start_x, start_y, level) do
    possible_positions = _get_available_positions(level, start_x, start_y)

    case _get_available_position(possible_positions, rtree_name) do
      {:ok, nil} ->
        rtree_name |> _check_system_available_positions(start_x, start_y, level + 1)

      {:ok, position} ->
        {:ok, position}
    end
  end

  defp _get_available_position([], _rtree_name), do: {:ok, nil}

  defp _get_available_position([position | rest], rtree_name) do
    if _is_available_position(position, rtree_name) do
      {:ok, position}
    else
      _get_available_position(rest, rtree_name)
    end
  end

  defp _is_available_position({x, y} = _position, rtree_name) do
    case DDRT.query(get_system_bounding_rect(%{position_x: x, position_y: y}), rtree_name) do
      {:ok, []} ->
        true

      {:ok, _} ->
        false

      _ ->
        true
    end
  end

  def _get_available_positions(level, x, y), do: _adjusted_coordinates(1 + level * 2, x, y)

  defp _edge_coordinates(n) when n > 1 do
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

  defp _sorted_edge_coordinates(n) when n > 1 do
    coordinates = _edge_coordinates(n)
    middle_right_index = div(n, 2)

    Enum.slice(coordinates, middle_right_index, length(coordinates) - middle_right_index) ++
      Enum.slice(coordinates, 0, middle_right_index)
  end

  defp _adjusted_coordinates(n, start_x, start_y) when n > 1 do
    sorted_coords = _sorted_edge_coordinates(n)

    Enum.map(sorted_coords, fn {x, y} ->
      {
        start_x + x * (@w + @m_x),
        start_y + y * (@h + @m_y)
      }
    end)
  end
end
