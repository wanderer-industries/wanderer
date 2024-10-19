defmodule WandererAppWeb.MapLoader do
  use WandererAppWeb, :live_component

  def render(assigns) do
    ~H"""
    <div
      id="map-loader"
      data-loading={show_loader("map-loader")}
      data-loaded={hide_loader("map-loader")}
      class="!z-100 w-screen h-screen hidden relative"
    >
      <div class="hs-overlay-backdrop transition duration absolute inset-0 blur" />
      <div class="flex !z-[150] w-full h-full items-center justify-center">
        <div class="Loader" data-text="Wanderer">
          <span class="Loader__Circle"></span>
          <span class="Loader__Circle"></span>
          <span class="Loader__Circle"></span>
          <span class="Loader__Circle"></span>
        </div>
      </div>
    </div>
    """
  end

  defp show_loader(js \\ %JS{}, id),
    do:
      JS.show(js,
        to: "##{id}",
        transition: {"transition-opacity ease-out duration-500", "opacity-0", "opacity-100"}
      )

  defp hide_loader(js \\ %JS{}, id),
    do:
      JS.hide(js,
        to: "##{id}",
        transition: {"transition-opacity ease-in duration-500", "opacity-100", "opacity-0"}
      )
end
