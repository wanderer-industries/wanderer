defmodule WandererAppWeb.Maps.MapSettings.ImportExportTab do
  use WandererAppWeb, :html

  attr :form, :any, required: true
  attr :importing, :boolean, required: true
  attr :map_slug, :string, required: true
  attr :export_settings, :map, required: true

  def content(assigns) do
    ~H"""
    <.form for={@form} phx-change="import">
      <%!-- Import is intentionally disabled until the backend workflow is restored. --%>
    </.form>
    <progress :if={@importing} class="progress w-56"></progress>
    <.button
      id="export-settings-btn"
      class="mt-8"
      type="button"
      disabled={@importing}
      phx-hook="DownloadJson"
      data-name={@map_slug}
      data-content={Jason.encode!(@export_settings)}
    >
      <.icon name="hero-document-arrow-down-solid" class="h-4 w-4" /> Export Settings
    </.button>
    """
  end
end
