defmodule WandererApp.Zkb.Supervisor do
  use Supervisor

  @name __MODULE__

  def start_link(opts \\ []) do
    Supervisor.start_link(@name, opts, name: @name)
  end

  def init(_init_args) do
    children = [
      {WandererApp.Zkb.KillsProvider,
       uri: "wss://zkillboard.com/websocket/",
       state: %WandererApp.Zkb.KillsProvider{},
       opts: [
         name: {:local, :zkb_kills_provider},
         mint_upgrade_opts: [Mint.WebSocket.PerMessageDeflate]
       ]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
