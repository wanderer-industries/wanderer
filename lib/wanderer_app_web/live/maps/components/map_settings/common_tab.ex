defmodule WandererAppWeb.Maps.MapSettings.CommonTab do
  use WandererAppWeb, :html

  attr :form, :any, required: true
  attr :uri, :any, required: true
  attr :characters, :list, required: true
  attr :available_scopes, :list, required: true

  def content(assigns) do
    ~H"""
    <.form
      :let={form}
      id="map-settings-common-form"
      for={@form}
      phx-change="validate"
      phx-submit="edit"
      autocomplete="off"
      class="mapSettingsCommonForm"
    >
      <div class="mapSettingsCommonContent custom-scrollbar [&>label.form-control>.inputContainer]:mb-1">
        <div class="grid grid-cols-2 items-start gap-4 [&_.label-text-alt>span]:hidden [&_.label-text-alt]:before:mr-1 [&_.label-text-alt]:before:content-['*'] [&>label.form-control>.inputContainer]:mb-0.5 [&>label.form-control>.label]:h-6 [&>label.form-control>.label]:py-0.5">
          <.input type="text" field={form[:name]} label="Map Name" placeholder="Map Name" />
          <.input
            type="text"
            field={form[:slug]}
            label="Map Slug"
            prefix={@uri}
            placeholder="map-slug"
          />
        </div>
        <.input
          type="textarea"
          field={form[:description]}
          label="Public description"
          placeholder="Public description"
        />
        <WandererAppWeb.Maps.MapSettings.SettingsSelect.select
          field={form[:owner_id]}
          wrapper_class="mt-2"
          label="Map owner"
          options={Enum.map(@characters, fn character -> {character.label, character.id} end)}
        />

        <div class="mt-4 flex items-center gap-3">
          <span class="shrink-0 text-xs font-normal uppercase tracking-wide text-stone-500">
            Automatically tracked space types
          </span>
          <div class="h-px flex-1 border-t border-stone-700" />
        </div>

        <div class="mt-1">
          <.input
            :for={scope_option <- @available_scopes}
            type="checkbox"
            id={"form_scopes_#{scope_option.value}"}
            name={"form[scopes][#{scope_option.value}]"}
            label={scope_option.label}
            value={scope_option.value in current_scopes(form)}
          />
        </div>

        <div class="mt-4 flex items-center gap-3">
          <span class="shrink-0 text-xs font-normal uppercase tracking-wide text-stone-500">
            Access restrictions
          </span>
          <div class="h-px flex-1 border-t border-stone-700" />
        </div>

        <.input
          type="checkbox"
          field={form[:only_tracked_characters]}
          label="Allow only tracked characters"
        />
      </div>
    </.form>
    """
  end

  defp current_scopes(form) do
    form
    |> Phoenix.HTML.Form.input_value(:scopes)
    |> Kernel.||([])
    |> Enum.map(fn
      scope when is_atom(scope) -> Atom.to_string(scope)
      scope when is_binary(scope) -> scope
    end)
  end
end
