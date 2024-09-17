defmodule DDRT.DynamicRtreeImpl.Utils do
  @moduledoc false

  def format_bbox([{min_x, max_x} = x, {min_y, max_y} = y]) do
    %{
      x: x,
      y: y,
      xm: min_x,
      xM: max_x,
      ym: min_y,
      yM: max_y
    }
  end

  def tuple_value(raw, _atom) when raw == nil do
    nil
  end

  def tuple_value(raw, atom) do
    case atom do
      :childs -> raw |> elem(0)
      :dad -> raw |> elem(1)
      :bbox -> raw |> elem(2)
    end
  end

  # Combine two bounding boxes into one
  def combine(box1, box2) do
    a = box1 |> format_bbox
    b = box2 |> format_bbox
    xm = Kernel.min(a.xm, b.xm)
    xM = Kernel.max(a.xM, b.xM)
    ym = Kernel.min(a.ym, b.ym)
    yM = Kernel.max(a.yM, b.yM)
    result = [{xm, xM}, {ym, yM}]
    result = if area(box1) === 0, do: box2, else: result
    if area(box2) === 0, do: box1, else: result
  end

  # Combine multiple bbox
  def combine_multiple(list) when length(list) > 1 do
    real_list = list |> Enum.filter(fn x -> area(x) > 0 end)

    tl(real_list)
    |> Enum.reduce(hd(real_list), fn [{a, b}, {c, d}] = _e, [{x, y}, {z, w}] = _acc ->
      [{Kernel.min(a, x), Kernel.max(b, y)}, {Kernel.min(c, z), Kernel.max(d, w)}]
    end)
  end

  def combine_multiple(list) do
    hd(list)
  end

  # Returns de percent of the overlap area (of the box1) between box1 and box2
  def overlap_area(box1, box2) do
    a = box1 |> format_bbox
    b = box2 |> format_bbox
    x_overlap = Kernel.max(0, Kernel.min(a.xM, b.xM) - Kernel.max(a.xm, b.xm))
    y_overlap = Kernel.max(0, Kernel.min(a.yM, b.yM) - Kernel.max(a.ym, b.ym))
    x_overlap * y_overlap / area(box1) * 100
  end

  # Return if those 2 boxes are overlapping
  def overlap?(box1, box2) do
    if overlap_area(box1, box2) > 0, do: true, else: false
  end

  # Return if box 1 contains box 2
  def contained?(box1, box2) do
    a = box1 |> format_bbox
    b = box2 |> format_bbox

    a.xm <= b.xm and a.xM >= b.xM and a.ym <= b.ym and a.yM >= b.yM
  end

  # Enlargement area after adding new box
  def enlargement_area(box, new_box) do
    a1 = area(box)
    a2 = combine_multiple([box, new_box]) |> area
    a2 - a1
  end

  # Checks if box is at some border of parent_box
  def in_border?(parent_box, box) do
    p = parent_box |> format_bbox
    b = box |> format_bbox

    p.xm == b.xm or p.xM == b.xM or p.ym == b.ym or p.yM == b.yM
  end

  # Return the area of a bounding box
  def area([{a, b}, {c, d}]) do
    ab = b - a
    cd = d - c

    cond do
      ab == 0 and cd != 0 -> cd
      ab != 0 and cd == 0 -> ab
      ab != 0 and cd != 0 -> ab * cd
      ab == 0 and cd == 0 -> -1
    end
  end

  # Return the middle bounding box value
  def middle_value([{a, b}, {c, d}]) do
    (a + b + c + d) / 2
  end

  def get_posxy([{a, b}, {c, d}]) do
    %{x: (b + a) / 2, y: (c + d) / 2}
  end

  def box_move([{a, b}, {c, d}], move) do
    x = move[:x]
    y = move[:y]
    [{a + x, b + x}, {c + y, d + y}]
  end
end
