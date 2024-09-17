defmodule WandererApp.Utils.Cache do
  @moduledoc false

  defmacro __using__(ops) do
    name =
      case Keyword.fetch(ops, :name) do
        {:ok, n} -> n
        _ -> raise "name parameter is mandatory"
      end

    quote location: :keep do
      # quote do
      require Logger

      def name(), do: unquote(name)

      def lookup(key, default \\ nil)

      def lookup({id, key}, default) when is_binary(id) and is_binary(key),
        do: lookup("#{id}:#{key}", default)

      def lookup(key, default) when is_binary(key) do
        case Cachex.get(name(), key) do
          {:ok, nil} -> {:ok, default}
          {:ok, value} -> {:ok, value}
        end
      end

      def lookup!(key, default \\ nil)

      def lookup!({id, key}, default) when is_binary(id) and is_binary(key),
        do: lookup!("#{id}:#{key}", default)

      def lookup!(key, default) when is_binary(key) do
        {:ok, result} = lookup(key, default)
        result
      end

      def insert(key, value, options \\ [])

      def insert({id, key}, value, options) when is_binary(id) and is_binary(key),
        do: insert("#{id}:#{key}", value, options)

      def insert(key, value, options) when is_binary(key) do
        Cachex.put(name(), key, value, options)
        :ok
      end

      def insert_or_update(key, value, update_fn, options \\ [])

      def insert_or_update({id, key}, value, update_fn, options)
          when is_binary(id) and is_binary(key),
          do: insert_or_update("#{id}:#{key}", value, update_fn, options)

      def insert_or_update(key, value, update_fn, options) when is_binary(key) do
        case lookup(key) do
          {:ok, nil} ->
            insert(key, value, options)

          {:ok, data} ->
            insert(key, update_fn.(data), options)
        end
      end

      def exists?({id, key}) when is_binary(id) and is_binary(key), do: exists?("#{id}:#{key}")

      def exists?(key) when is_binary(key), do: Cachex.exists?(name(), key)

      def delete(key, options \\ [])

      def delete({id, key}, options) when is_binary(id) and is_binary(key),
        do: delete("#{id}:#{key}", options)

      def delete(key, options) when is_binary(key), do: Cachex.del(name(), key, options)
    end
  end
end
