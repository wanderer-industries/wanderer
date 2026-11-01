defmodule WandererAppWeb.Maps.MapSettings.SettingsSelect do
  use WandererAppWeb, :html

  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :options, :list, required: true
  attr :prompt, :string, default: nil
  attr :wrapper_class, :string, default: nil

  def select(assigns) do
    ~H"""
    <.input
      type="select"
      field={@field}
      label={@label}
      options={@options}
      prompt={@prompt}
      wrapper_class={@wrapper_class}
      class="mapSettingsSelect h-8 min-h-0 rounded-sm border border-neutral-700 bg-neutral-950/60 py-1 pl-2.5 pr-8 text-sm text-neutral-100 shadow-none outline-none transition-colors hover:border-neutral-600 focus:border-sky-500 focus:outline-none focus:ring-1 focus:ring-sky-500/25"
    />
    """
  end
end
