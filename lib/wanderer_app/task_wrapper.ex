defmodule WandererApp.TaskWrapper do
  @environment Application.compile_env(:wanderer_app, :environment)

  def start_link(module, func, args) do
    if @environment == :test do
      apply(module, func, args)
    else
      Task.start_link(module, func, args)
    end
  end
end
