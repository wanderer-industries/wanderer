defmodule WandererApp.PromEx do
  use PromEx, otp_app: :wanderer_app

  alias PromEx.Plugins

  @impl true
  def plugins do
    [
      # PromEx built in plugins
      {Plugins.Application, [otp_app: :wanderer_app]},
      Plugins.Beam,
      {Plugins.Phoenix, router: WandererAppWeb.Router},
      {Plugins.Ecto, otp_app: :wanderer_app},
      Plugins.PhoenixLiveView,
      WandererApp.Metrics.PromExPlugin
    ]
  end

  @impl true
  def dashboard_assigns do
    [
      datasource_id: Application.get_env(:wanderer_app, :grafana_datasource_id),
      default_selected_interval: "30s"
    ]
  end

  @impl true
  def dashboards do
    [
      # PromEx built in Grafana dashboards
      {:prom_ex, "application.json"},
      {:prom_ex, "beam.json"},
      {:prom_ex, "phoenix.json"},
      {:prom_ex, "ecto.json"},
      {:prom_ex, "phoenix_live_view.json"}
    ]
  end
end
