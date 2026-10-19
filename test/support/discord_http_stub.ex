defmodule WandererApp.ExternalEvents.Discord.HttpStub do
  @moduledoc """
  Test double for Discord HTTP delivery.

  State lives in ONE named Agent shared by every test, so any test using this
  stub must be `async: false`. The Agent is unlinked and outlives the test that
  first started it. Call `start/0` in setup (it resets the state if the Agent is
  already up), `set_responses/1` to script replies, and `requests/0` to assert
  on what was sent.
  """
  @behaviour WandererApp.ExternalEvents.Discord.HttpClient

  @agent __MODULE__.Agent

  def start do
    # Deliberately unlinked. Under Agent.start_link the Agent belongs to
    # whichever test process called start/0 first and dies when that test ends.
    # Because the registered name is released asynchronously, the next test's
    # start/0 can be handed a pid that is already on its way out: the reset
    # succeeds, start/0 returns, and the Agent then dies mid-test, exiting the
    # caller with an opaque :noproc from whatever it queried next. Monitoring
    # around the reset does not close that window, because the failure mode is
    # a reset that *succeeds* against a doomed process. Unlinked, the Agent
    # outlives every test and setup only has to reset it.
    case Agent.start(fn -> %{responses: [], requests: []} end, name: @agent) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        :ok = Agent.update(@agent, fn _ -> %{responses: [], requests: []} end)
        {:ok, pid}

      # Without this the case raises CaseClauseError, which says nothing about
      # what actually went wrong.
      {:error, reason} ->
        raise "Discord HttpStub agent failed to start: #{inspect(reason)}"
    end
  end

  def reset, do: Agent.update(@agent, fn _ -> %{responses: [], requests: []} end) == :ok

  @doc "Queues responses, consumed in order. Each is {:ok, status, headers} or {:error, term}."
  def set_responses(responses), do: Agent.update(@agent, &%{&1 | responses: responses})

  @doc "Returns {url, body} tuples in the order they were sent."
  def requests, do: Agent.get(@agent, & &1.requests) |> Enum.reverse()

  @impl true
  def post(url, body) do
    Agent.get_and_update(@agent, fn state ->
      state = %{state | requests: [{url, body} | state.requests]}

      case state.responses do
        [] -> {{:ok, 204, []}, state}
        [resp | rest] -> {resp, %{state | responses: rest}}
      end
    end)
  end
end
