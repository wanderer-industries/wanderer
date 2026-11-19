defmodule WandererAppWeb.Maps.MapSettings.GeneralTab do
  use WandererAppWeb, :html

  @layout_options [
    {"Left To Right", "left_to_right"},
    {"Top To Bottom", "top_to_bottom"}
  ]

  @allowed_copy_for_options [
    {"Administrators", "admin_map"},
    {"Managers", "manage_map"},
    {"Members", "add_system"}
  ]

  @allowed_paste_for_options [
    {"Members", "add_system"},
    {"Administrators", "admin_map"},
    {"Managers", "manage_map"}
  ]

  attr :form, :any, required: true

  def content(assigns) do
    assigns =
      assign(assigns,
        layout_options: @layout_options,
        allowed_copy_for_options: @allowed_copy_for_options,
        allowed_paste_for_options: @allowed_paste_for_options
      )

    ~H"""
    <.form
      :let={form}
      for={@form}
      phx-change="update_options"
      class="flex flex-col gap-2 [&>.form-control]:!mt-0"
    >
      <WandererAppWeb.Maps.MapSettings.SettingsSelect.select
        field={form[:layout]}
        label="Map systems layout"
        options={@layout_options}
      />
      <.input type="checkbox" field={form[:store_custom_labels]} label="Store system custom labels" />
      <.input
        type="checkbox"
        field={form[:show_temp_system_name]}
        label="Allow temporary system names"
      />
      <.input
        type="checkbox"
        field={form[:show_linked_signature_id]}
        label="Show linked signature ID as custom label part"
      />
      <.input
        type="checkbox"
        field={form[:show_linked_signature_id_temp_name]}
        label="Show linked signature ID as temporary name part"
      />
      <.input
        type="checkbox"
        field={form[:restrict_offline_showing]}
        label="Show offline characters to admins & managers only"
      />
      <WandererAppWeb.Maps.MapSettings.SettingsSelect.select
        field={form[:allowed_copy_for]}
        label="Copy map data allowed for"
        options={@allowed_copy_for_options}
      />
      <WandererAppWeb.Maps.MapSettings.SettingsSelect.select
        field={form[:allowed_paste_for]}
        label="Paste map data allowed for"
        options={@allowed_paste_for_options}
      />
    </.form>
    """
  end
end
