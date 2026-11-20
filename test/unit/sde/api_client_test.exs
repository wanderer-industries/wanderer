defmodule WandererApp.Sde.ApiClientTest do
  # Uses the shared WandererApp.Cache and global app env
  use ExUnit.Case, async: false

  alias WandererApp.Sde.ApiClient

  @rifter %{
    "typeID" => 587,
    "groupID" => 25,
    "name" => %{"de" => "Rifter", "en" => "Rifter"},
    "description" => %{"en" => "A very powerful combat frigate."},
    "mass" => 1_067_000,
    "capacity" => 140,
    "volume" => 27_289
  }

  setup do
    previous = Application.get_env(:wanderer_app, :sde_req_options)
    Application.put_env(:wanderer_app, :sde_req_options, plug: {Req.Test, ApiClient})

    on_exit(fn ->
      if previous,
        do: Application.put_env(:wanderer_app, :sde_req_options, previous),
        else: Application.delete_env(:wanderer_app, :sde_req_options)
    end)

    :ok
  end

  defp clear(keys), do: Enum.each(keys, &WandererApp.Cache.delete/1)

  test "reads a type record from the latest release" do
    clear(["sde-type-587"])

    Req.Test.expect(ApiClient, fn conn ->
      assert conn.request_path == "/tranquility/latest/types/587.json"
      Req.Test.json(conn, @rifter)
    end)

    assert {:ok, @rifter} = ApiClient.get_type(587)
    # Cached: no second request
    assert {:ok, @rifter} = ApiClient.get_type(587)
    Req.Test.verify!(ApiClient)
  end

  test "reads a group record" do
    clear(["sde-group-25"])

    Req.Test.expect(ApiClient, fn conn ->
      assert conn.request_path == "/tranquility/latest/groups/25.json"
      Req.Test.json(conn, %{"groupID" => 25, "name" => %{"en" => "Frigate"}})
    end)

    assert {:ok, group} = ApiClient.get_group(25)
    assert ApiClient.localized(group, "name") == "Frigate"
  end

  test "an unknown id is not found, and the miss is cached" do
    clear(["sde-type-99999999"])

    Req.Test.expect(ApiClient, fn conn -> Plug.Conn.send_resp(conn, 404, "") end)

    assert {:error, :not_found} = ApiClient.get_type(99_999_999)
    assert {:error, :not_found} = ApiClient.get_type(99_999_999)
    Req.Test.verify!(ApiClient)
  end

  test "a server error is returned and not cached" do
    clear(["sde-type-34"])

    Req.Test.expect(ApiClient, fn conn -> Plug.Conn.send_resp(conn, 503, "") end)
    assert {:error, {:unexpected_status, 503}} = ApiClient.get_type(34)

    Req.Test.expect(ApiClient, fn conn ->
      Req.Test.json(conn, %{"typeID" => 34, "name" => %{"en" => "Tritanium"}})
    end)

    assert {:ok, %{"typeID" => 34}} = ApiClient.get_type(34)
  end

  test "localized/2 picks English and passes plain values through" do
    assert ApiClient.localized(@rifter, "name") == "Rifter"
    assert ApiClient.localized(@rifter, "mass") == 1_067_000
    assert ApiClient.localized(@rifter, "missing") == nil
  end
end
