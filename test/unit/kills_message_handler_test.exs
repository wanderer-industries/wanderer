defmodule WandererApp.Kills.MessageHandlerTest do
  use ExUnit.Case, async: false

  alias WandererApp.Esi.ApiClient
  alias WandererApp.Kills.{MessageHandler, Storage}

  @system_id 31_000_005
  @corporation_id 98_123_456

  setup do
    previous = Application.get_env(:wanderer_app, :esi_req_options)
    Application.put_env(:wanderer_app, :esi_req_options, plug: {Req.Test, ApiClient})
    WandererApp.Cache.delete("corporation-info-#{@corporation_id}")
    :ets.new(:kills_system_map_index, [:set, :public, :named_table])

    on_exit(fn ->
      WandererApp.Cache.delete("corporation-info-#{@corporation_id}")

      if previous,
        do: Application.put_env(:wanderer_app, :esi_req_options, previous),
        else: Application.delete_env(:wanderer_app, :esi_req_options)
    end)

    :ok
  end

  test "stores a killmail without waiting for missing affiliation enrichment" do
    killmail_id = System.unique_integer([:positive])
    test_pid = self()

    Req.Test.stub(ApiClient, fn conn ->
      send(test_pid, :unexpected_esi_request)
      Req.Test.json(conn, %{"name" => "Attacker Corporation", "ticker" => "ATK"})
    end)

    payload = %{
      "system_id" => @system_id,
      "killmails" => [
        %{
          "killmail_id" => killmail_id,
          "kill_time" => "2026-11-16T12:00:00Z",
          "solar_system_id" => @system_id,
          "victim" => %{"ship_type_id" => 626},
          "attackers" => [
            %{
              "character_id" => 90_000_002,
              "character_name" => "Final Blow Pilot",
              "corporation_id" => @corporation_id,
              "ship_type_id" => 621,
              "final_blow" => true
            }
          ],
          "zkb" => %{"total_value" => 1_000_000}
        }
      ]
    }

    assert :ok = MessageHandler.process_killmail_update(payload)
    assert {:ok, kill} = Storage.get_killmail(killmail_id)
    assert kill["final_blow_corp_name"] == nil
    assert kill["final_blow_corp_ticker"] == nil
    refute_received :unexpected_esi_request
  end

  test "uses cached affiliation without making an ESI request" do
    killmail_id = System.unique_integer([:positive])
    test_pid = self()

    WandererApp.Cache.put("corporation-info-#{@corporation_id}", {
      :ok,
      %{"name" => "Attacker Corporation", "ticker" => "ATK"}
    })

    Req.Test.stub(ApiClient, fn conn ->
      send(test_pid, :unexpected_esi_request)
      Req.Test.json(conn, %{"name" => "Unexpected Corporation", "ticker" => "BAD"})
    end)

    payload = %{
      "system_id" => @system_id,
      "killmails" => [
        %{
          "killmail_id" => killmail_id,
          "kill_time" => "2026-11-16T12:00:00Z",
          "solar_system_id" => @system_id,
          "victim" => %{"ship_type_id" => 626},
          "attackers" => [
            %{
              "corporation_id" => @corporation_id,
              "final_blow" => true
            }
          ],
          "zkb" => %{}
        }
      ]
    }

    assert :ok = MessageHandler.process_killmail_update(payload)
    assert {:ok, kill} = Storage.get_killmail(killmail_id)
    assert kill["final_blow_corp_name"] == "Attacker Corporation"
    assert kill["final_blow_corp_ticker"] == "ATK"
    refute_received :unexpected_esi_request
  end
end
