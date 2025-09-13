defmodule WandererAppWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as modals, tables, and
  forms. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The default components use Tailwind CSS, a utility-first CSS framework.
  See the [Tailwind CSS documentation](https://tailwindcss.com) to learn
  how to customize them or feel free to swap in another framework altogether.

  Icons are provided by [heroicons](https://heroicons.com). See `icon/1` for usage.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  import WandererAppWeb.Gettext

  @image_base_url "https://images.evetech.net"

  attr(:url, :string, required: true)
  attr(:label, :string, required: false)

  def avatar(assigns) do
    ~H"""
    <div class="avatar">
      <div class="rounded-md w-8 h-8">
        <img src={@url} alt={@label} />
      </div>
    </div>
    """
  end

  @doc """
  Renders a modal.

  ## Examples

      <.modal id="confirm-modal">
        This is a modal.
      </.modal>

  JS commands may be passed to the `:on_cancel` to configure
  the closing/cancel event, for example:

      <.modal id="confirm" on_cancel={JS.navigate(~p"/posts")}>
        This is another modal.
      </.modal>

  """
  attr(:id, :string, required: true)
  attr(:title, :string, default: nil)
  attr(:show, :boolean, default: false)
  attr(:on_cancel, JS, default: %JS{})
  slot(:inner_block, required: true)
  attr(:class, :string, default: nil)

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-[1000] hidden overflow-visible"
    >
      <div id={"#{@id}-bg"} class="overflow-visible p-dialog-resizable" aria-hidden="true" />
      <div
        class="fixed inset-0 overflow-visible"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex items-center justify-center w-full h-full p-4 sm:p-6 lg:py-8 p-dialog-mask p-dialog-center p-component-overlay p-component-overlay-enter p-dialog-resizable">
          <.focus_wrap
            id={"#{@id}-container"}
            phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
            phx-key="escape"
            class={[
              "relative hidden transition p-dialog p-component p-dialog-default p-ripple-disabled p-dialog-enter-done !overflow-visible max-w-full",
              @class
            ]}
          >
            <h3 class="p-dialog-header font-bold text-base">
              <div>{@title}</div>
              <div class="absolute right-4">
                <button
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  type="button"
                  class="p-link opacity-70 hover:opacity-100"
                  aria-label={gettext("close")}
                >
                  <.icon name="hero-x-mark-solid" class="h-5 w-5" />
                </button>
              </div>
            </h3>
            <div id={"#{@id}-content"} class="p-dialog-content !overflow-visible">
              {render_slot(@inner_block)}
            </div>
          </.focus_wrap>
        </div>
      </div>
    </div>
    """
  end

  slot :inner_block

  def connection_status(assigns) do
    ~H"""
    <div
      id="connection-status"
      class="hidden fixed z-50"
      js-show={show("#connection-status")}
      js-hide={hide("#connection-status")}
    >
      <div class="hs-overlay-backdrop transition duration fixed inset-0 bg-gray-900 bg-opacity-50 dark:bg-opacity-80 dark:bg-neutral-900 z-50">
      </div>
      <div class="alert fixed top-20 right-4 shadow-lg w-72 fade-in-scale z-50">
        <div class="flex">
          <div class="flex-shrink-0 flex items-center">
            <span class="loading loading-ring loading-md"></span>
          </div>
          <div class="ml-3 flex items-center">
            <p class="text-sm font-medium text-red-800" role="alert">
              {render_slot(@inner_block)}
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr(:online, :boolean, default: false)

  def server_status(assigns) do
    ~H"""
    <div
      class="flex flex-col p-4 items-center absolute bottom-16 left-2 gap-2 tooltip tooltip-right"
      data-tip="server: Tranquility"
    >
      <div class={"block w-2 h-2 rounded-full shadow-inner  #{if @online, do: " bg-green-500", else: "bg-red-500"}"}>
      </div>
    </div>
    """
  end

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr(:id, :string, doc: "the optional id of flash container")
  attr(:flash, :map, default: %{}, doc: "the map of flash messages to display")
  attr(:title, :string, default: nil)

  attr(:kind, :atom,
    values: [:info, :warning, :error, :loading],
    doc: "used for styling and flash lookup"
  )

  attr(:rest, :global, doc: "the arbitrary HTML attributes to add to the flash container")

  slot(:inner_block, doc: "the optional inner block that renders the flash message")

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={
        JS.push("lv:clear-flash", value: %{key: @kind})
        |> JS.remove_class("fade-in-scale")
        |> hide("##{@id}")
      }
      role="alert"
      class={[
        "alert shadow-lg flex items-center justify-between fixed top-12 right-2 w-80 z-50 fade-in-scale !rounded text-white !bg-black !bg-opacity-70  ",
        @kind == :info && "alert-info ",
        @kind == :warning && "alert-warning ",
        @kind == :error && "alert-error",
        @kind == :loading && "alert-success"
      ]}
      {@rest}
    >
      <div>
        <div class="flex gap-2 text-xs items-center">
          <.icon
            :if={@kind == :info}
            name="hero-information-circle"
            class="h-5 !w-[50px] text-blue-500"
          />
          <.icon
            :if={@kind == :warning}
            name="hero-exclamation-triangle"
            class="h-5 !w-[50px] text-orange-500"
          />
          <.icon :if={@kind == :error} name="hero-x-circle" class="h-5 !w-[50px] text-red-500" />
          <span :if={@kind == :loading} class="loading loading-ring loading-md"></span> {msg}
        </div>
      </div>
      <button type="button" class="flex items-center" aria-label={gettext("close")}>
        <.icon name="hero-x-mark-solid" class="h-5 !w-[50px] opacity-40 group-hover:opacity-70" />
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr(:flash, :map, required: true, doc: "the map of flash messages")
  attr(:id, :string, default: "flash-group", doc: "the optional id of flash container")

  def flash_group(assigns) do
    ~H"""
    <div id={@id}>
      <.flash id="client-info" kind={:info} title="Success!" flash={@flash} />
      <.flash id="client-error" kind={:error} title="Error!" flash={@flash} />
      <.flash id="client-loading" kind={:loading} title="Loading..." flash={@flash} />
    </div>
    """
  end

  @doc """
  Renders a simple form.

  ## Examples

      <.simple_form for={@form} phx-change="validate" phx-submit="save">
        <.input field={@form[:email]} label="Email"/>
        <.input field={@form[:username]} label="Username" />
        <:actions>
          <.button>Save</.button>
        </:actions>
      </.simple_form>
  """
  attr(:for, :any, required: true, doc: "the datastructure for the form")
  attr(:as, :any, default: nil, doc: "the server side parameter to collect all input under")

  attr(:rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target multipart),
    doc: "the arbitrary HTML attributes to apply to the form tag"
  )

  slot(:inner_block, required: true)
  slot(:actions, doc: "the slot for form actions, such as a submit button")

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <div class="w-full space-y-8">
        {render_slot(@inner_block, f)}
        <div :for={action <- @actions} class="mt-2 flex items-center justify-between gap-6">
          {render_slot(action, f)}
        </div>
      </div>
    </.form>
    """
  end

  @doc """
  Renders a button.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" class="ml-2">Send!</.button>
  """
  attr(:type, :string, default: nil)
  attr(:class, :string, default: nil)
  attr(:rest, :global, include: ~w(disabled form name value))

  slot(:inner_block, required: true)

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "phx-submit-loading:opacity-75 p-button p-component p-button-outlined p-button-sm",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr(:id, :any, default: nil)
  attr(:class, :string, default: nil)
  attr(:wrapper_class, :string, default: nil)
  attr(:name, :any)
  attr(:label, :string, default: nil)
  attr(:prefix, :string, default: nil)
  attr(:value, :any)

  attr(:type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file hidden month number password
               range radio search select tel text textarea time url week)
  )

  attr(:field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"
  )

  attr(:errors, :list, default: [])
  attr(:checked, :boolean, doc: "the checked flag for checkbox inputs")
  attr(:show_value, :boolean, doc: "show current value")
  attr(:prompt, :string, default: nil, doc: "the prompt for select inputs")
  attr(:options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2")
  attr(:multiple, :boolean, default: false, doc: "the multiple flag for select inputs")

  attr(:rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)
  )

  slot(:inner_block)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(field.errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div phx-feedback-for={@name} class="form-control mt-2">
      <label class="inputContainer" for={@name}>
        <span>{@label}</span>
        <div></div>
        <div class="smallInputSwitch">
          <div class="flex items-center">
            <div
              class={[
                "checkboxRoot sizeM p-checkbox p-component",
                classes("p-highlight": @checked)
              ]}
              data-p-highlight={@checked}
              data-p-disabled="false"
              data-pc-name="checkbox"
              data-pc-section="root"
            >
              <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
              <input
                id={@id}
                name={@name}
                type="checkbox"
                class="p-checkbox-input"
                aria-invalid="false"
                data-pc-section="input"
                value="true"
                checked={@checked}
                {@rest}
              />
              <div
                class="p-checkbox-box"
                data-p-highlight={@checked}
                data-p-disabled="false"
                data-pc-section="box"
              >
                <svg
                  :if={@checked}
                  width="14"
                  height="14"
                  viewBox="0 0 14 14"
                  fill="none"
                  xmlns="http://www.w3.org/2000/svg"
                  class="p-icon p-checkbox-icon"
                  aria-hidden="true"
                  data-pc-section="icon"
                >
                  <path
                    d="M4.86199 11.5948C4.78717 11.5923 4.71366 11.5745 4.64596 11.5426C4.57826 11.5107 4.51779 11.4652 4.46827 11.4091L0.753985 7.69483C0.683167 7.64891 0.623706 7.58751 0.580092 7.51525C0.536478 7.44299 0.509851 7.36177 0.502221 7.27771C0.49459 7.19366 0.506156 7.10897 0.536046 7.03004C0.565935 6.95111 0.613367 6.88 0.674759 6.82208C0.736151 6.76416 0.8099 6.72095 0.890436 6.69571C0.970973 6.67046 1.05619 6.66385 1.13966 6.67635C1.22313 6.68886 1.30266 6.72017 1.37226 6.76792C1.44186 6.81567 1.4997 6.8786 1.54141 6.95197L4.86199 10.2503L12.6397 2.49483C12.7444 2.42694 12.8689 2.39617 12.9932 2.40745C13.1174 2.41873 13.2343 2.47141 13.3251 2.55705C13.4159 2.64268 13.4753 2.75632 13.4938 2.87973C13.5123 3.00315 13.4888 3.1292 13.4271 3.23768L5.2557 11.4091C5.20618 11.4652 5.14571 11.5107 5.07801 11.5426C5.01031 11.5745 4.9368 11.5923 4.86199 11.5948Z"
                    fill="currentColor"
                  >
                  </path>
                </svg>
              </div>
            </div>
            <label for={@name} class="select-none ml-1.5"></label>
          </div>
        </div>
      </label>
    </div>
    """
  end

  def input(%{type: "range"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <div class="form-control w-full">
        <.label for={@id}>
          <span>{@label}</span>
          <div></div>
          {@value}
        </.label>

        <div>
          <input
            type="range"
            id={@id}
            name={@name}
            value={@value}
            class={[
              "p-component w-full",
              @class,
              @errors != [] && "border-rose-400 focus:border-rose-400"
            ]}
            {@rest}
          />
        </div>
      </div>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div
      phx-feedback-for={@name}
      class={[
        "inputContainer",
        @wrapper_class
      ]}
    >
      <.label :if={@label} for={@id}>{@label}</.label>
      <div :if={@label}></div>
      <select
        id={@id}
        name={@name}
        class={[
          "p-component",
          @class
        ]}
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <label phx-feedback-for={@name} class="form-control">
      <.label for={@id}><span class="label-text">{@label}</span></.label>
      <textarea
        id={@id}
        name={@name}
        class={[
          "p-inputtextarea p-inputtext p-component w-full h-24",
          @class,
          @errors != [] && "p-invalid"
        ]}
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
      <.error :for={msg <- @errors}>{msg}</.error>
    </label>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <label class="form-control w-full" phx-feedback-for={@name}>
      <.label for={@id}><span class="label-text">{@label}</span></.label>
      <div class="join">
        <input :if={@prefix} class="p-inputtext bg-neutral-700 join-item" disabled value={@prefix} />
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            "p-inputtext p-component w-full",
            @class,
            @errors != [] && "p-invalid"
          ]}
          {@rest}
        />
      </div>

      <div class="label">
        <.error :for={msg <- @errors}>{msg}</.error>
      </div>
    </label>
    """
  end

  @doc """
  Renders a label.
  """
  attr(:for, :string, default: nil)
  slot(:inner_block, required: true)

  def label(assigns) do
    ~H"""
    <label for={@for} class="inputContainer">
      {render_slot(@inner_block)}
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot(:inner_block, required: true)

  def error(assigns) do
    ~H"""
    <p class="label-text-alt text-rose-600 phx-no-feedback:hidden">
      <.icon name="hero-exclamation-circle-mini" class="mt-0.5 h-5 w-5 flex-none" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  attr(:class, :string, default: nil)

  slot(:inner_block, required: true)
  slot(:subtitle)
  slot(:actions)

  def header(assigns) do
    ~H"""
    <header class={[
      "flex flex-col justify-between gap-2 p-2 bg-gray-400 bg-opacity-5 border border-gray-500 ",
      @class
    ]}>
      <div>
        <h1 class="text-lg font-semibold leading-8">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="mt-2 text-sm leading-6">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc ~S"""
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id"><%= user.id %></:col>
        <:col :let={user} label="username"><%= user.username %></:col>
      </.table>
  """
  attr(:id, :string, required: true)
  attr(:class, :string, default: nil)
  attr(:empty_label, :string, default: nil)
  attr(:rows, :list, required: true)
  attr(:row_id, :any, default: nil, doc: "the function for generating the row id")
  attr(:row_selected, :boolean, default: false, doc: "the function for generating the row id")
  attr(:row_click, :any, default: nil, doc: "the function for handling phx-click on each row")

  attr(:row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"
  )

  slot :col, required: true do
    attr(:label, :string)
  end

  slot(:action, doc: "the slot for showing user actions in the last table column")

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
        assign(assigns, row_selected: assigns.row_selected || fn {_id, _item} -> false end)
      end

    ~H"""
    <div class={["overflow-y-auto px-4 sm:overflow-visible sm:px-0", @class]}>
      <table class="table overflow-y-auto">
        <thead>
          <tr>
            <th :for={col <- @col}>{col[:label]}</th>
            <th :if={@action != []} class="relative p-0 pb-4">
              <span class="sr-only">{gettext("Actions")}</span>
            </th>
          </tr>
        </thead>
        <tbody id={@id} phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}>
          <tr :if={@rows |> Enum.empty?()}>
            <td colspan={@col |> Enum.count()}>
              {@empty_label}
            </td>
          </tr>
          <tr
            :for={row <- @rows}
            id={@row_id && @row_id.(row)}
            phx-click={@row_click && @row_click.(row)}
            class={"hover #{if @row_selected && @row_selected.(row), do: "!bg-slate-600", else: ""} #{if @row_click, do: "cursor-pointer", else: ""}"}
          >
            <td :for={{col, _index} <- Enum.with_index(@col)}>
              {render_slot(col, @row_item.(row))}
            </td>
            <td :if={@action != []}>
              <div class="relative whitespace-nowrap text-right text-sm font-medium">
                <span class="absolute -inset-y-px -right-4 left-0 group-hover:bg-zinc-50 sm:rounded-r-xl" />
                <span :for={action <- @action} class="relative pl-4 font-semibold leading-6">
                  {render_slot(action, @row_item.(row))}
                </span>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title"><%= @post.title %></:item>
        <:item title="Views"><%= @post.views %></:item>
      </.list>
  """
  slot :item, required: true do
    attr(:title, :string, required: true)
  end

  def list(assigns) do
    ~H"""
    <div class="mt-14">
      <dl class="-my-4 divide-y divide-zinc-100">
        <div :for={item <- @item} class="flex gap-4 py-4 text-sm leading-6 sm:gap-8">
          <dt class="w-1/4 flex-none text-zinc-500">{item.title}</dt>
          <dd class="text-zinc-700">{render_slot(item)}</dd>
        </div>
      </dl>
    </div>
    """
  end

  attr(:placeholder, :string, default: nil)
  attr(:label, :string, default: nil)
  attr(:label_class, :string, default: nil)
  attr(:input_class, :string, default: nil)
  attr(:dropdown_extra_class, :string, default: nil)
  attr(:option_extra_class, :string, default: nil)
  slot(:inner_block)

  def live_select(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns =
      assigns
      |> assign(:errors, Enum.map(field.errors, &translate_error(&1)))
      |> assign(
        :live_select_opts,
        assigns_to_attributes(assigns, [
          :errors,
          :label,
          :value_mapper,
          :label_class,
          :input_class,
          :dropdown_extra_class,
          :option_extra_class
        ])
      )

    ~H"""
    <div
      phx-feedback-for={@field.name}
      class={[
        "form-control",
        @label_class
      ]}
    >
      <div for="form_description" class="label">
        <span class="label-text"></span>
      </div>
      <LiveSelect.live_select
        field={@field}
        dropdown_class={[
          "absolute shadow z-50 w-full max-h-64 bg-neutral-900 text-neutral-50 overflow-y-auto",
          @dropdown_extra_class
        ]}
        available_option_class="w-full"
        option_class="p-2 hover:bg-neutral-800 hover:text-neutral-50"
        tag_extra_class="rounded-none"
        text_input_class={[
          "p-autocomplete-input p-component p-inputtext  w-full",
          @errors != [] && "p-invalid",
          @input_class
        ]}
        text_input_selected_class="p-inputtext"
        {@live_select_opts}
      >
        {render_slot(@inner_block)}
      </LiveSelect.live_select>
      <div for="form_description" class="label">
        <.error :for={msg <- @errors}>{msg}</.error>
      </div>
    </div>
    """
  end

  @doc """
  Renders a back navigation link.

  ## Examples

      <.back navigate={~p"/posts"}>Back to posts</.back>
  """
  attr(:navigate, :any, required: true)
  slot(:inner_block, required: true)
  attr(:class, :string, default: nil)

  def back(assigns) do
    ~H"""
    <div class="pt-16">
      <.link
        navigate={@navigate}
        class={[
          "text-sm font-semibold leading-6",
          @class
        ]}
      >
        <.icon name="hero-arrow-left-solid" class="h-3 w-3" />
        {render_slot(@inner_block)}
      </.link>
    </div>
    """
  end

  @doc """
  Add conditional class names to a component.

  ## Examples

  <span class={["text-green-600 ", classes("text-red-600": @value < 0)]} />
  """
  def classes(classes) do
    ([" ": true] ++ classes)
    |> Enum.filter(&elem(&1, 1))
    |> Enum.map_join(" ", &elem(&1, 0))
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from your `assets/vendor/heroicons` directory and bundled
  within your compiled app.css by the plugin in your `assets/tailwind.config.js`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
  """
  attr(:name, :string, required: true)
  attr(:class, :string, default: nil)

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  def local_time(assigns) do
    ~H"""
    <time phx-hook="LocalTime" id={"time-#{@id}"} class="invisible">{@at}</time>
    """
  end

  attr(:at, :any, required: true)
  attr(:id, :any, required: true)

  def client_time(assigns) do
    ~H"""
    <time phx-hook="ClientTime" id={"client-time-#{@id}"} class="invisible">{@at}</time>
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(WandererAppWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(WandererAppWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  def less(a, b) do
    a < b
  end

  def more_or_equal(a, b) do
    a >= b
  end

  def member_icon_url(eve_character_id)
      when is_binary(eve_character_id) or is_integer(eve_character_id) do
    "#{@image_base_url}/characters/#{eve_character_id}/portrait"
  end

  def member_icon_url(%{eve_character_id: eve_character_id} = _member)
      when is_binary(eve_character_id) or is_integer(eve_character_id) do
    "#{@image_base_url}/characters/#{eve_character_id}/portrait"
  end

  def member_icon_url(%{eve_corporation_id: eve_corporation_id} = _member)
      when is_binary(eve_corporation_id) or is_integer(eve_corporation_id) do
    "#{@image_base_url}/corporations/#{eve_corporation_id}/logo?size=32"
  end

  def member_icon_url(%{eve_alliance_id: eve_alliance_id} = _member)
      when is_binary(eve_alliance_id) or is_integer(eve_alliance_id) do
    "#{@image_base_url}/alliances/#{eve_alliance_id}/logo?size=32"
  end

  def pagination_opts do
    [
      ellipsis_attrs: [class: "ellipsis"],
      ellipsis_content: "‥",
      next_link_content: next_icon(),
      page_links: {:ellipsis, 7},
      previous_link_content: previous_icon(),
      current_link_attrs: [
        class:
          "relative z-10 inline-flex items-center bg-indigo-600 px-4 py-2 text-sm font-semibold text-white focus:z-20 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600",
        aria: [current: "page"]
      ],
      next_link_attrs: [
        aria: [label: "Go to next page"],
        class: ""
      ],
      pagination_link_attrs: [
        class:
          "relative z-10 inline-flex items-center px-4 py-2 text-sm font-semibold text-white focus:z-20 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
      ],
      previous_link_attrs: [
        aria: [label: "Go to previous page"],
        class: ""
      ]
    ]
  end

  defp next_icon do
    assigns = %{}

    ~H"""
    <.icon name="hero-chevron-right" class="h-5 w-5" />
    """
  end

  defp previous_icon do
    assigns = %{}

    ~H"""
    <.icon name="hero-chevron-left" class="h-5 w-5" />
    """
  end

  def table_opts do
    [
      container: true,
      container_attrs: [class: "table-container"],
      no_results_content: no_results_content(),
      table_attrs: [class: "table"]
    ]
  end

  defp no_results_content do
    assigns = %{}

    ~H"""
    <p>Nothing found.</p>
    """
  end
end
