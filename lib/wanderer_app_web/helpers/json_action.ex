defmodule WandererAppWeb.JsonAction do
  @moduledoc """
  Helper module to standardize controller action patterns with result tuple handling.

  This module provides macros and functions to reduce boilerplate in controllers
  by automatically handling {:ok, result} and {:error, reason} patterns.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [action_fallback: 1]
  alias WandererAppWeb.Helpers.APIUtils

  @doc """
  Use this module in controllers to enable JSON action helpers.

  ## Example

      use WandererAppWeb.JsonAction
  """
  defmacro __using__(_opts) do
    quote do
      import WandererAppWeb.JsonAction
      action_fallback WandererAppWeb.JsonFallbackController
    end
  end

  @doc """
  Wraps a function that returns {:ok, result} or {:error, reason} and 
  automatically converts to JSON response.

  ## Examples

      json_action conn do
        MyContext.get_resource(id)
      end
      
      json_action conn, :created do
        MyContext.create_resource(attrs)
      end
  """
  defmacro json_action(conn, status \\ :ok, do: block) do
    quote do
      case unquote(block) do
        {:ok, result} ->
          APIUtils.respond_data(unquote(conn), result, unquote(status))

        {:error, _reason} = error ->
          # Let FallbackController handle the error
          error

        other ->
          # Unexpected return value
          {:error, "Unexpected return value: #{inspect(other)}"}
      end
    end
  end

  @doc """
  Similar to json_action but allows transformation of the successful result
  before responding.

  ## Example

      json_action_with conn do
        MyContext.get_resource(id)
      with
        fn resource -> %{id: resource.id, name: resource.name} end
      end
  """
  defmacro json_action_with(conn, opts) when is_list(opts) do
    action_block = Keyword.get(opts, :do)
    transform_fn = Keyword.get(opts, :with)
    status = Keyword.get(opts, :status, :ok)

    quote do
      case unquote(action_block) do
        {:ok, result} ->
          transformed =
            case unquote(transform_fn) do
              nil -> result
              fun -> fun.(result)
            end

          APIUtils.respond_data(unquote(conn), transformed, unquote(status))

        {:error, _reason} = error ->
          error

        other ->
          {:error, "Unexpected return value: #{inspect(other)}"}
      end
    end
  end

  defmacro json_action_with(conn, status, opts) when is_atom(status) and is_list(opts) do
    opts = Keyword.put(opts, :status, status)

    quote do
      json_action_with(unquote(conn), unquote(opts))
    end
  end

  @doc """
  Handles paginated results with metadata.

  ## Example

      json_paginated conn do
        MyContext.list_resources(params)
      end
  """
  defmacro json_paginated(conn, do: block) do
    quote do
      case unquote(block) do
        {:ok, %{entries: entries, metadata: metadata}} ->
          APIUtils.respond_data(unquote(conn), entries, :ok, metadata)

        {:ok, entries} when is_list(entries) ->
          # No metadata provided, just return the list
          APIUtils.respond_data(unquote(conn), entries)

        {:error, _reason} = error ->
          error

        other ->
          {:error, "Unexpected return value for pagination: #{inspect(other)}"}
      end
    end
  end

  @doc """
  Handles delete operations that may return :ok or {:ok, result}.

  ## Example

      json_delete conn do
        MyContext.delete_resource(id)
      end
  """
  defmacro json_delete(conn, do: block) do
    quote do
      case unquote(block) do
        :ok ->
          unquote(conn) |> put_status(204) |> send_resp(204, "")

        {:ok, result} ->
          APIUtils.respond_data(unquote(conn), result)

        {:error, _reason} = error ->
          error

        other ->
          {:error, "Unexpected return value: #{inspect(other)}"}
      end
    end
  end

  @doc """
  Handles batch operations that return multiple results.

  ## Example

      json_batch conn do
        MyContext.batch_create(items)
      end
  """
  defmacro json_batch(conn, do: block) do
    quote do
      case unquote(block) do
        {:ok, results} when is_list(results) ->
          # Separate successes and failures
          {successes, failures} =
            Enum.split_with(results, fn
              {:ok, _} -> true
              _ -> false
            end)

          success_data = Enum.map(successes, fn {:ok, data} -> data end)

          failure_data =
            Enum.map(failures, fn
              {:error, reason} when is_binary(reason) -> %{error: reason}
              {:error, reason} -> %{error: inspect(reason)}
              other -> %{error: "Unknown error", details: inspect(other)}
            end)

          response = %{
            succeeded: success_data,
            failed: failure_data,
            total: length(results),
            success_count: length(successes),
            failure_count: length(failures)
          }

          status = if length(failures) > 0, do: :multi_status, else: :ok
          APIUtils.respond_data(unquote(conn), response, status)

        {:ok, result} ->
          APIUtils.respond_data(unquote(conn), result)

        {:error, _reason} = error ->
          error

        other ->
          {:error, "Unexpected return value: #{inspect(other)}"}
      end
    end
  end
end
