defmodule WandererApp.GenImpl do
  @moduledoc "Simple utility for avoiding boilerplate in a GenServer implementation."

  @doc """
  If your GenServer is a thin wrapper around a struct, you can make its handle_call/3 and/or
  handle_cast/2 implementations be "just this."

  Use it like this:

      GenImpl.apply_call(&MyGenServer.Impl.update/3, %MyGenServer.Impl{}, [arg2, arg3])

  This will result in a call that looks like:

      MyGenServer.Impl.update(%MyGenServer.Impl{}, arg2, arg3)

  Supports operations that:

  - Update the state struct
  - Return a result tuple, or even just :error
  - Query the state and return a value

  ...but not operations that both modify the state *and* query something.
  """
  def apply_call(impl_function, state, additional_args)
      when is_function(impl_function) and is_struct(state) and is_list(additional_args) do
    result = apply(impl_function, [state | additional_args])
    handle_call_result(state, result)
  end

  def apply_call(impl_function_name, %struct_module{} = state, additional_args)
      when is_atom(impl_function_name) and is_list(additional_args) do
    result = apply(struct_module, impl_function_name, [state | additional_args])
    handle_call_result(state, result)
  end

  defp handle_call_result(%struct_type{}, %struct_type{} = updated_state),
    do: {:reply, :ok, updated_state}

  defp handle_call_result(%struct_type{}, {:ok, %struct_type{} = updated_state}),
    do: {:reply, :ok, updated_state}

  defp handle_call_result(%struct_type{}, {result, %struct_type{} = updated_state}),
    do: {:reply, result, updated_state}

  defp handle_call_result(%_struct_type{} = state, :error), do: {:reply, :error, state}
  defp handle_call_result(%_struct_type{} = state, result), do: {:reply, result, state}
end
