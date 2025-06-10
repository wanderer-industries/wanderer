defmodule WandererApp.Kills.RetryBehavior do
  @moduledoc """
  A behavior for implementing retry logic with exponential backoff and cycling.

  This module provides a reusable pattern for retry logic that was previously
  duplicated in the Client module.
  """

  require Logger

  @logger Application.compile_env(:wanderer_app, :logger)

  @type retry_state :: %{
          retry_count: non_neg_integer(),
          cycle_count: non_neg_integer()
        }

  @type retry_config :: %{
          max_retries: non_neg_integer(),
          retry_delays: [non_neg_integer()],
          cycle_delay: non_neg_integer()
        }

  @doc """
  Increments the retry state, cycling after max retries.
  """
  @spec increment_retry(retry_state(), retry_config()) :: retry_state()
  def increment_retry(%{retry_count: count, cycle_count: cycles} = state, %{
        max_retries: max_retries
      }) do
    if count < max_retries do
      %{state | retry_count: count + 1}
    else
      %{retry_count: 0, cycle_count: cycles + 1}
    end
  end

  @doc """
  Gets the delay for the current retry state.
  """
  @spec get_retry_delay(retry_state(), retry_config()) :: non_neg_integer()
  def get_retry_delay(%{retry_count: count}, %{
        max_retries: max_retries,
        retry_delays: delays,
        cycle_delay: cycle_delay
      }) do
    cond do
      count >= max_retries ->
        cycle_delay

      count < length(delays) ->
        Enum.at(delays, count)

      true ->
        # If count is within max_retries but beyond delays list, use cycle_delay
        cycle_delay
    end
  end

  @doc """
  Schedules a retry with the appropriate delay.

  Returns a timer reference that can be cancelled.
  """
  @spec schedule_retry(retry_state(), retry_config(), atom(), pid() | atom()) :: reference()
  def schedule_retry(retry_state, retry_config, message, target \\ self()) do
    delay = get_retry_delay(retry_state, retry_config)
    @logger.info("[RetryBehavior] Scheduling retry in #{delay}ms")
    Process.send_after(target, message, delay)
  end

  @doc """
  Cancels a retry timer if it exists.
  """
  @spec cancel_retry_timer(reference() | nil) :: :ok
  def cancel_retry_timer(nil), do: :ok

  def cancel_retry_timer(timer_ref) do
    case Process.cancel_timer(timer_ref) do
      # Timer already fired
      false -> :ok
      # Timer cancelled
      _ -> :ok
    end
  end

  @doc """
  Creates a new retry state.
  """
  @spec new_retry_state() :: retry_state()
  def new_retry_state do
    %{retry_count: 0, cycle_count: 0}
  end

  @doc """
  Resets the retry state to initial values.
  """
  @spec reset_retry_state(retry_state()) :: retry_state()
  def reset_retry_state(_state) do
    new_retry_state()
  end
end
