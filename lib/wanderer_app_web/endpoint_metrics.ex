defmodule WandererAppWeb.EndpointMetrics do
  use Phoenix.Endpoint, otp_app: :wanderer_app

  plug PromEx.Plug, prom_ex_module: WandererApp.PromEx
end
