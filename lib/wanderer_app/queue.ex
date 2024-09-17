defmodule WandererApp.Queue do
  @moduledoc false

  def new(queue_name, items), do: queue_name |> _update(Qex.new(items))

  def join(queue_name, items),
    do:
      queue_name
      |> _insert_or_update(Qex.new(items), fn queue ->
        Qex.join(queue, Qex.new(items))
      end)

  def push_uniq(queue_name, item) do
    case Enum.member?(queue_name |> to_list!, item) do
      false ->
        queue_name
        |> _insert_or_update(Qex.new([item]), fn queue ->
          Qex.push(queue, item)
        end)

      _ ->
        :ok
    end
  end

  def push(queue_name, item),
    do:
      queue_name
      |> _insert_or_update(Qex.new([item]), fn queue ->
        Qex.push(queue, item)
      end)

  def push_front(queue_name, item),
    do:
      queue_name
      |> _insert_or_update(Qex.new([item]), fn queue ->
        Qex.push_front(queue, item)
      end)

  def next(queue_name) do
    {{:value, item}, _q} =
      queue_name
      |> _lookup!()
      |> Qex.pop()

    {:ok, item}
  end

  def pop(queue_name) do
    {{:value, item}, queue} =
      queue_name
      |> _lookup!()
      |> Qex.pop()

    queue_name
    |> _update(queue)

    {:ok, item}
  end

  def to_list(queue_name),
    do:
      {:ok,
       queue_name
       |> _lookup!()
       |> Enum.to_list()}

  def to_list!(queue_name),
    do:
      queue_name
      |> _lookup!()
      |> Enum.to_list()

  def empty?(queue_name) when is_binary(queue_name) or is_atom(queue_name),
    do:
      queue_name
      |> _lookup!()
      |> Enum.empty?()

  def clear(queue_name),
    do:
      queue_name
      |> _update(Qex.new())

  def _insert_or_update(queue_name, queue, update_fn),
    do: WandererApp.Cache.insert_or_update(queue_name, queue, update_fn)

  def _lookup!(queue_name),
    do: WandererApp.Cache.lookup!(queue_name, Qex.new())

  def _update(queue_name, queue),
    do: WandererApp.Cache.insert(queue_name, queue)
end
