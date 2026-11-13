defmodule WandererAppWeb.BlogHTML do
  use WandererAppWeb, :html

  @welcome_links [
    {"Changelog", "/changelog"},
    {"News", "/news"},
    {"License", "/license"},
    {"Contact Us", "/contacts"}
  ]

  def welcome_navigation(assigns) do
    assigns = assign(assigns, :links, @welcome_links)

    ~H"""
    <nav class="ml-auto flex w-fit items-center whitespace-nowrap border-y border-white/25 bg-black/60 px-2 font-mono text-[10px] uppercase tracking-[0.16em] text-stone-200 shadow-[0_12px_35px_rgba(0,0,0,0.22)] backdrop-blur-[1px]">
      <.link
        :for={{label, path} <- @links}
        navigate={path}
        class="border-r border-white/20 px-3 py-2 transition last:border-r-0 hover:bg-black/35 hover:text-orange-100"
      >
        {label}
      </.link>
    </nav>
    """
  end

  embed_templates "blog_html/*"
end
