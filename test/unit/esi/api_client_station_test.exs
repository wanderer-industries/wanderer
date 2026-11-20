defmodule WandererApp.Esi.ApiClientStationTest do
  # Uses the shared WandererApp.Cache and global app env
  use ExUnit.Case, async: false

  alias WandererApp.Esi.ApiClient

  @station_id 60_003_760
  @name "Jita IV - Moon 4 - Caldari Navy Assembly Plant"

  setup do
    previous = Application.get_env(:wanderer_app, :esi_req_options)
    Application.put_env(:wanderer_app, :esi_req_options, plug: {Req.Test, ApiClient})
    WandererApp.Cache.delete("station-info-#{@station_id}")

    on_exit(fn ->
      WandererApp.Cache.delete("station-info-#{@station_id}")

      if previous,
        do: Application.put_env(:wanderer_app, :esi_req_options, previous),
        else: Application.delete_env(:wanderer_app, :esi_req_options)
    end)

    :ok
  end

  test "resolves the station name through /universe/names" do
    Req.Test.expect(ApiClient, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/universe/names/"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == [@station_id]

      Req.Test.json(conn, [%{"category" => "station", "id" => @station_id, "name" => @name}])
    end)

    assert {:ok, %{"station_id" => @station_id, "name" => @name}} =
             ApiClient.get_station_info(@station_id, [])

    # Cached: no second request
    assert {:ok, %{"name" => @name}} = ApiClient.get_station_info(@station_id, [])
    Req.Test.verify!(ApiClient)
  end

  test "an id ESI cannot resolve is an error" do
    Req.Test.expect(ApiClient, fn conn ->
      conn
      |> Plug.Conn.put_status(404)
      |> Req.Test.json(%{"error" => "Ensure all IDs are valid before resolving."})
    end)

    assert {:error, _reason} = ApiClient.get_station_info(@station_id, [])
  end
end
