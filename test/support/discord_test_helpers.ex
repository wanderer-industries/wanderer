defmodule WandererApp.ExternalEvents.Discord.TestHelpers do
  @moduledoc """
  Polling helpers shared by the Discord worker and dispatcher tests.

  Both suites wait on the same two things: requests landing in `HttpStub`, and
  a per-map worker draining its mailbox. Kept here rather than in `HttpStub`,
  which implements the `HttpClient` behaviour and should stay focused on that.
  """
  import ExUnit.Assertions

  alias WandererApp.ExternalEvents.Discord.{HttpStub, WorkerSupervisor}

  @doc """
  Blocks until `HttpStub` has recorded at least `count` requests, then returns
  them. Flunks on timeout rather than returning a short list, so a delivery
  regression fails loudly instead of silently satisfying a length assertion.
  """
  def wait_for_requests(count, timeout \\ 2_000) do
    do_wait(count, System.monotonic_time(:millisecond) + timeout)
  end

  defp do_wait(count, deadline) do
    cond do
      length(HttpStub.requests()) >= count ->
        HttpStub.requests()

      System.monotonic_time(:millisecond) > deadline ->
        flunk("expected #{count} requests, got #{length(HttpStub.requests())}")

      true ->
        Process.sleep(25)
        do_wait(count, deadline)
    end
  end

  @doc """
  Blocks until the map's worker has drained its mailbox up to this point.
  Cheaper and far less flaky than sleeping, now that every attempt is
  scheduled. Returns `:no_worker` when no worker is registered.
  """
  def sync(map_id) do
    case Registry.lookup(WorkerSupervisor.registry(), map_id) do
      [{pid, _}] -> :sys.get_state(pid)
      [] -> :no_worker
    end
  end
end
