ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(WandererApp.Repo, :manual)
Application.ensure_all_started(:mox)

Mox.defmock(Test.PubSubMock, for: WandererApp.Test.PubSub)
Mox.defmock(Test.LoggerMock, for: WandererApp.Test.Logger)
Mox.defmock(Test.DDRTMock, for: WandererApp.Test.DDRT)
