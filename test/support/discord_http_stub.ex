defmodule WandererApp.ExternalEvents.Discord.HttpStub do
  @moduledoc """
  Test double for Discord HTTP delivery.

  State lives in ONE named Agent shared by every test, so any test using this
  stub must be `async: false`. Call `start/0` in setup (it resets the state if
  the Agent is already up), `set_responses/1` to script replies, and
  `requests/0` to assert on what was sent.
  """
  @behaviour WandererApp.ExternalEvents.Discord.HttpClient

  @agent __MODULE__.Agent

  def start do
    case Agent.start_link(fn -> %{responses: [], requests: []} end, name: @agent) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        # The Agent is linked to the test process that started it, so it exits
        # when that test ends — but the registered name is released
        # asynchronously. In that window start/0 sees {:already_started, pid}
        # for a process that is already dying, and updating it exits the
        # *caller* with an opaque :noproc. A Process.alive?/1 guard does not
        # close the race (the pid can die right after the check), so monitor
        # first, attempt the reset, and fall back to waiting for :DOWN.
        ref = Process.monitor(pid)

        try do
          :ok = Agent.update(@agent, fn _ -> %{responses: [], requests: []} end)
          Process.demonitor(ref, [:flush])
          {:ok, pid}
        catch
          :exit, _ ->
            receive do
              {:DOWN, ^ref, :process, ^pid, _} -> start()
            after
              1_000 ->
                raise "Discord HttpStub agent #{inspect(pid)} would not release its name"
            end
        end

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
