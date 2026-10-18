defmodule WandererApp.Esi.ApiClientConditionalTest do
  # Uses the shared :api_cache Cachex instance and global app env
  use ExUnit.Case, async: false

  alias WandererApp.Esi.ApiClient

  @path "/status"
  @validators_key {:esi_validators, @path}

  setup do
    previous = Application.get_env(:wanderer_app, :esi_req_options)
    Application.put_env(:wanderer_app, :esi_req_options, plug: {Req.Test, ApiClient})

    clear_cache()

    on_exit(fn ->
      clear_cache()

      if previous,
        do: Application.put_env(:wanderer_app, :esi_req_options, previous),
        else: Application.delete_env(:wanderer_app, :esi_req_options)
    end)

    :ok
  end

  test "caches 200 response until expires" do
    stub(fn conn -> ok_response(conn, %{"players" => 1}, "\"v1\"", future(30)) end)

    assert {:ok, %{"players" => 1}} = ApiClient.get_server_status()
    assert {:ok, %{"players" => 1}} = ApiClient.get_server_status()

    assert_received {:request, _}
    refute_received {:request, _}
  end

  test "304 reuses stored body and extends cache with headers from the 304 response" do
    stub(fn conn -> ok_response(conn, %{"players" => 1}, "\"v1\"", future(30)) end)
    assert {:ok, %{"players" => 1}} = ApiClient.get_server_status()
    assert_received {:request, _}

    # Simulate the fresh cache window passing
    Cachex.del(:api_cache, @path)

    stub(fn conn ->
      conn
      |> Plug.Conn.put_resp_header("etag", "\"v1\"")
      |> Plug.Conn.put_resp_header("expires", future(60))
      |> Plug.Conn.send_resp(304, "")
    end)

    assert {:ok, %{"players" => 1}} = ApiClient.get_server_status()
    assert_received {:request, headers}
    assert {"if-none-match", "\"v1\""} in headers

    assert {:ok, ttl} = Cachex.ttl(:api_cache, @path)
    assert is_integer(ttl) and ttl > 30_000

    # Served from the extended cache, no new request
    assert {:ok, %{"players" => 1}} = ApiClient.get_server_status()
    refute_received {:request, _}
  end

  test "304 without stored body retries unconditionally" do
    stub(fn conn ->
      if Plug.Conn.get_req_header(conn, "if-none-match") == [] do
        ok_response(conn, %{"players" => 2}, "\"v2\"", future(30))
      else
        Plug.Conn.send_resp(conn, 304, "")
      end
    end)

    Cachex.put(:api_cache, @validators_key, %{etag: "\"v1\"", last_modified: nil})

    assert {:ok, %{"players" => 2}} = ApiClient.get_server_status()
  end

  test "does not cache responses with expires in the past" do
    stub(fn conn -> ok_response(conn, %{"players" => 1}, "\"v1\"", past(10)) end)

    assert {:ok, %{"players" => 1}} = ApiClient.get_server_status()
    assert {:ok, nil} = Cachex.get(:api_cache, @path)
  end

  defp stub(fun) do
    test_pid = self()

    Req.Test.stub(ApiClient, fn conn ->
      send(test_pid, {:request, conn.req_headers})
      fun.(conn)
    end)
  end

  defp ok_response(conn, body, etag, expires) do
    conn
    |> Plug.Conn.put_resp_header("etag", etag)
    |> Plug.Conn.put_resp_header("expires", expires)
    |> Req.Test.json(body)
  end

  defp future(seconds), do: http_date(DateTime.add(DateTime.utc_now(), seconds, :second))
  defp past(seconds), do: http_date(DateTime.add(DateTime.utc_now(), -seconds, :second))

  defp http_date(datetime), do: Calendar.strftime(datetime, "%a, %d %b %Y %H:%M:%S GMT")

  defp clear_cache do
    Cachex.del(:api_cache, @path)
    Cachex.del(:api_cache, @validators_key)
  end
end
