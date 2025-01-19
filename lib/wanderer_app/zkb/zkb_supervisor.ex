defmodule WandererApp.Zkb.Supervisor do
  use Supervisor

  @name __MODULE__

  def start_link(opts \\ []) do
    Supervisor.start_link(@name, opts, name: @name)
  end

  def init(_init_args) do
    # only create the preloader child
    # if zkill_preload_disabled? is *false*.
    preloader_child =
      unless WandererApp.Env.zkill_preload_disabled?() do
        {WandererApp.Zkb.KillsPreloader, []}
      end

    children =
      [
        {
          WandererApp.Zkb.KillsProvider,
          uri: "wss://zkillboard.com/websocket/",
          state: %WandererApp.Zkb.KillsProvider{
            connected: false
          },
          opts: [
            name: {:local, :zkb_kills_provider},
            mint_upgrade_opts: [Mint.WebSocket.PerMessageDeflate]
          ]
        },
        preloader_child
      ]
      |> Enum.reject(&is_nil/1)

    Supervisor.init(children, strategy: :one_for_one)
  end
end
