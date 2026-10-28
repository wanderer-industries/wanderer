defmodule WandererAppWeb.Maps.MapSettings.ImportExportTab do
  use WandererAppWeb, :html

  attr :form, :any, required: true
  attr :importing, :boolean, required: true
  attr :map_slug, :string, required: true
  attr :export_settings, :map, required: true

  def content(assigns) do
    ~H"""
    <div class="space-y-4">
      <div
        role="status"
        class="flex items-start gap-3 rounded-sm border border-amber-700/40 bg-amber-950/20 px-4 py-3 text-amber-100/85"
      >
        <.icon
          name="hero-exclamation-triangle-solid"
          class="mt-0.5 h-5 w-5 shrink-0 text-amber-400/80"
        />
        <div class="min-w-0">
          <p class="text-sm font-medium text-amber-200/90">Import is temporarily unavailable</p>
          <p class="mt-1 text-sm leading-5 text-neutral-400">
            We're reviewing the import workflow and evaluating the safest way to restore it.
          </p>
        </div>
      </div>

      <section class="rounded-sm border border-neutral-700/80 bg-neutral-900/30 p-4">
        <div class="flex items-center justify-between gap-6">
          <div class="min-w-0">
            <h3 class="text-sm font-medium text-neutral-200">Export map settings</h3>
            <p class="mt-1 text-sm leading-5 text-neutral-500">
              Download the current map settings as a JSON backup.
            </p>
          </div>

          <.button
            id="export-settings-btn"
            class="inline-flex shrink-0 items-center justify-center gap-2 !rounded-sm !px-4 !py-2"
            type="button"
            disabled={@importing}
            phx-hook="DownloadJson"
            data-name={@map_slug}
            data-content={Jason.encode!(@export_settings)}
          >
            <.icon name="hero-arrow-down-tray-solid" class="h-4 w-4 shrink-0" />
            <span>Export settings</span>
          </.button>
        </div>
      </section>

      <.form for={@form} phx-change="import">
        <%!-- Import is intentionally disabled until the backend workflow is restored. --%>
      </.form>
      <progress :if={@importing} class="progress w-56"></progress>
    </div>
    """
  end
end
