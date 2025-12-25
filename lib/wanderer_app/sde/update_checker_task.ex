defmodule WandererApp.SDE.UpdateCheckerTask do
  @moduledoc """
  Checks for and applies SDE updates on application startup.

  This task runs once during application boot, checks for available updates,
  and automatically applies them if found.

  ## Behavior

  - Checks the configured SDE source for available updates
  - Automatically downloads and applies updates when available
  - Logs progress and results
  - Completes without blocking application startup

  ## Configuration

  The check can be disabled by setting:

      config :wanderer_app, :sde,
        check_on_startup: false

  To check but not auto-apply updates:

      config :wanderer_app, :sde,
        auto_update: false

  To customize the startup delay (default 2 seconds):

      config :wanderer_app, :sde,
        startup_delay: 5_000  # 5 seconds
  """

  use Task

  require Logger

  alias WandererApp.EveDataService
  alias WandererApp.SDE.Source

  # Default timeout for the entire startup check operation (60 seconds)
  @startup_check_timeout :timer.seconds(60)

  # Default startup delay in milliseconds
  @default_startup_delay 2_000

  @doc """
  Child spec with explicit :temporary restart strategy.

  Tasks started with `use Task` default to :temporary, but we make it explicit
  for clarity and to prevent extended startup delays.
  """
  def child_spec(arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [arg]},
      restart: :temporary,
      type: :worker
    }
  end

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run(_arg) do
    # Small delay to let other services start first
    delay = Application.get_env(:wanderer_app, :sde)[:startup_delay] || @default_startup_delay
    Process.sleep(delay)

    if check_enabled?() do
      run_with_timeout()
    else
      Logger.debug("SDE update check on startup is disabled")
    end
  end

  defp run_with_timeout do
    task = Task.async(fn -> check_and_update() end)

    case Task.yield(task, @startup_check_timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, _result} ->
        :ok

      nil ->
        Logger.warning("SDE update check timed out after #{@startup_check_timeout}ms")
        :timeout
    end
  end

  defp check_enabled? do
    Application.get_env(:wanderer_app, :sde)[:check_on_startup] != false
  end

  defp auto_update_enabled? do
    Application.get_env(:wanderer_app, :sde)[:auto_update] != false
  end

  defp check_and_update do
    source = Source.get_source()
    Logger.info("Checking for SDE updates from #{inspect(source)}...")

    case EveDataService.check_for_updates() do
      {:ok, :up_to_date} ->
        current_version = EveDataService.get_current_sde_version()
        Logger.info("SDE is up to date (version: #{current_version || "unknown"})")

      {:ok, :update_available, metadata} ->
        current_version = EveDataService.get_current_sde_version()

        Logger.info(
          "SDE update available: #{current_version || "not set"} -> #{metadata["sde_version"]} (released #{metadata["release_date"]})"
        )

        if auto_update_enabled?() do
          apply_update(metadata)
        else
          Logger.info("Auto-update disabled. Visit Admin Panel to update manually.")
        end

      {:ok, :update_available} ->
        # Fuzzworks doesn't support version tracking, apply update to be safe
        Logger.info("SDE source does not support version tracking. Applying update...")

        if auto_update_enabled?() do
          apply_update(nil)
        else
          Logger.info("Auto-update disabled. Visit Admin Panel to update manually.")
        end

      {:error, reason} ->
        Logger.warning("Failed to check for SDE updates: #{inspect(reason)}")
    end
  rescue
    e in [RuntimeError, ArgumentError, KeyError, Req.TransportError, Req.HTTPError] ->
      Logger.warning("Error during SDE update check: #{Exception.message(e)}")
  catch
    :exit, reason ->
      Logger.warning("SDE update check exited: #{inspect(reason)}")
  end

  defp apply_update(metadata) do
    version = if metadata, do: metadata["sde_version"], else: "latest"
    Logger.info("Applying SDE update (version: #{version})...")

    case EveDataService.update_eve_data() do
      :ok ->
        new_version = EveDataService.get_current_sde_version()
        Logger.info("SDE update complete (version: #{new_version || version})")

      {:error, reason} ->
        Logger.error("Failed to apply SDE update: #{inspect(reason)}")
    end
  end
end
