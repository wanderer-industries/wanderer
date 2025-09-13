defmodule WandererApp.Cache do
  @moduledoc false
  use Nebulex.Cache,
    otp_app: :wanderer_app,
    adapter: Nebulex.Adapters.Local

  require Logger

  def lookup(key, default \\ nil)

  def lookup({id, key}, default) when is_binary(id) and (is_binary(key) or is_atom(key)),
    do: lookup("#{id}:#{key}", default)

  def lookup(key, default) when is_binary(key) or is_atom(key) do
    case get(key) do
      nil -> {:ok, default}
      value -> {:ok, value}
    end
  end

  def lookup!(key, default \\ nil)

  def lookup!({id, key}, default) when is_binary(id) and (is_binary(key) or is_atom(key)),
    do: lookup!("#{id}:#{key}", default)

  def lookup!(key, default) when is_binary(key) or is_atom(key) do
    {:ok, result} = lookup(key, default)
    result
  end

  def get_and_remove(key, default) when is_binary(key) or is_atom(key) do
    case take(key) do
      nil -> {:ok, default}
      value -> {:ok, value}
    end
  end

  def get_and_remove!(key, default) when is_binary(key) or is_atom(key) do
    {:ok, result} = get_and_remove(key, default)
    result
  end

  def insert(key, value, opts \\ [])

  def insert({id, key}, value, opts) when is_binary(id) and (is_binary(key) or is_atom(key)),
    do: insert("#{id}:#{key}", value, opts)

  def insert(key, nil, opts) when is_binary(key) or is_atom(key), do: delete(key)
  def insert(key, value, opts) when is_binary(key) or is_atom(key), do: put(key, value, opts)

  def insert_or_update(key, value, update_fn, opts \\ [])

  def insert_or_update({id, key}, value, update_fn, opts)
      when is_binary(id) and (is_binary(key) or is_atom(key)),
      do: insert_or_update("#{id}:#{key}", value, update_fn, opts)

  def insert_or_update(key, value, update_fn, opts) when is_binary(key) or is_atom(key) do
    case lookup(key) do
      {:ok, nil} ->
        insert(key, value, opts)

      {:ok, data} ->
        insert(key, update_fn.(data), opts)
    end
  end

  def find_by_attrs(type, attrs, match \\ :any) do
    case type |> get() |> find(attrs, match: match) do
      %{} = item -> {:ok, item}
      nil -> {:error, :item_not_found}
    end
  end

  def filter_by_attr_in(type, attr, includes), do: type |> get() |> filter_in(attr, includes)

  defp find(list, %{} = attrs, match: match) do
    list
    |> Enum.find(fn item ->
      case match do
        :any -> Enum.any?(attrs, &has_equal_attribute?(item, &1))
        :all -> Enum.all?(attrs, &has_equal_attribute?(item, &1))
      end
    end)
  end

  defp filter_in(nil, _attr, _includes), do: []

  defp filter_in(list, attr, includes),
    do:
      list
      |> Enum.filter(&(&1[attr] in includes))

  defp has_equal_attribute?(%{} = map, {key, {:case_insensitive, value}}) when is_binary(value) do
    String.downcase(Map.get(map, key, "")) == String.downcase(value)
  end

  defp has_equal_attribute?(%{} = map, {key, value}), do: Map.get(map, key) == value
end
