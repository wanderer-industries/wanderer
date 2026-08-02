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
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> reset() && {:ok, pid}
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
