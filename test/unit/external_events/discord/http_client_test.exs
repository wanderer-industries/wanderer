defmodule WandererApp.ExternalEvents.Discord.HttpClientTest do
  use ExUnit.Case, async: false

  alias WandererApp.ExternalEvents.Discord.{HttpClient, HttpStub, WorkerSupervisor}

  setup do
    HttpStub.start()
    start_supervised!(WorkerSupervisor)
    :ok
  end

  @tag :review_batch
  test "gates direct post calls after a global response using the existing typed 429 tuple" do
    response =
      {:ok, 429, [{"retry-after", "20"}, {"x-ratelimit-global", "true"}],
       ~s({"retry_after":20.0,"global":true})}

    HttpStub.set_responses([response])
    assert HttpClient.post("first", %{}) == response
    assert {:ok, 429, headers} = HttpClient.post("second", %{})
    assert {"x-ratelimit-global", "true"} in headers
    assert {"x-ratelimit-scope", "global"} in headers
    assert [{"first", %{}}] = HttpStub.requests()
  end

  @tag :review_batch
  test "never shortens a cooldown when concurrent responses arrive out of order" do
    parent = self()

    delayed = fn _, _ ->
      send(parent, {:started, self()})

      receive do
        {:release, seconds} ->
          {:ok, 429, [{"retry-after", seconds}], ~s({"global":true})}
      end
    end

    HttpStub.set_responses([delayed, delayed])
    first = Task.async(fn -> HttpClient.post("first", %{}) end)
    assert_receive {:started, first_pid}
    second = Task.async(fn -> HttpClient.post("second", %{}) end)
    assert_receive {:started, second_pid}
    send(first_pid, {:release, "0.6"})
    assert {:ok, 429, _, _} = Task.await(first)
    send(second_pid, {:release, "0.05"})
    assert {:ok, 429, _, _} = Task.await(second)

    Process.sleep(100)
    assert {:ok, 429, _} = HttpClient.post("blocked", %{})
    assert length(HttpStub.requests()) == 2

    # Expiry must eventually permit a direct call, not leave a sticky gate.
    Process.sleep(550)
    assert {:ok, 204, []} = HttpClient.post("after-expiry", %{})
    assert length(HttpStub.requests()) == 3
  end

  @tag :review_batch
  test "does not globally gate a webhook-only 429" do
    response =
      {:ok, 429, [{"retry-after", "20"}, {"x-ratelimit-scope", "shared"}],
       ~s({"retry_after":20.0,"global":false})}

    HttpStub.set_responses([response])
    assert HttpClient.post("first", %{}) == response
    assert {:ok, 204, []} = HttpClient.post("second", %{})
    assert length(HttpStub.requests()) == 2
  end
end
