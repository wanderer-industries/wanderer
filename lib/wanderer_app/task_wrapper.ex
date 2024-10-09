defmodule WandererApp.TaskWrapper do
  def start_link(module, func, args) do
    if Mix.env() == :test do
      apply(module, func, args)
    else
      Task.start_link(module, func, args)
    end
  end
end
