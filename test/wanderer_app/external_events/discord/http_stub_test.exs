defmodule WandererApp.ExternalEvents.Discord.HttpStubTest do
  use ExUnit.Case, async: false

  alias WandererApp.ExternalEvents.Discord.HttpStub

  setup do
    {:ok, _pid} = HttpStub.start()
    :ok
  end

  test "records requests and returns default response when none scripted" do
    assert {:ok, 204, []} = HttpStub.post("http://example.com", %{foo: "bar"})
    assert [{"http://example.com", %{foo: "bar"}}] = HttpStub.requests()
  end

  test "returns queued responses in order" do
    HttpStub.set_responses([{:ok, 429, [{"retry-after", "1"}]}, {:error, :timeout}])

    assert {:ok, 429, [{"retry-after", "1"}]} = HttpStub.post("url1", %{a: 1})
    assert {:error, :timeout} = HttpStub.post("url2", %{b: 2})
    assert {:ok, 204, []} = HttpStub.post("url3", %{c: 3})

    assert [{"url1", %{a: 1}}, {"url2", %{b: 2}}, {"url3", %{c: 3}}] = HttpStub.requests()
  end
end
