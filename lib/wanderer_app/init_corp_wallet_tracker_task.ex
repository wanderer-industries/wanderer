defmodule WandererApp.StartCorpWalletTrackerTask do
  use Task

  require Logger

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run(_arg) do
    Logger.info("Starting corp wallet tracker task")

    case WandererApp.Env.corp_wallet() do
      "" ->
        :ok

      user_hash ->
        user_hash
        |> get_user_characters()
        |> maybe_start_corp_wallet_tracker()
    end
  end

  def maybe_start_corp_wallet_tracker({:ok, user_characters}) do
    admin_character =
      user_characters
      |> Enum.find(fn character ->
        character.eve_id == WandererApp.Env.corp_wallet_eve_id() &&
          WandererApp.Character.can_track_corp_wallet?(character)
      end)

    if not is_nil(admin_character) do
      :ok =
        WandererApp.Character.TrackerManager.start_tracking(admin_character.id, keep_alive: true)

      {:ok, _pid} =
        WandererApp.Character.TrackerManager.start_transaction_tracker(admin_character.id)
    end

    :ok
  end

  def maybe_start_corp_wallet_tracker(_), do: :ok

  defp get_user_characters(user_hash) when not is_nil(user_hash) and is_binary(user_hash) do
    case WandererApp.Api.User.by_hash(user_hash, load: :characters) do
      {:ok, user} -> {:ok, user.characters}
      {:error, _} -> {:ok, []}
    end
  end

  defp get_user_characters(_), do: {:ok, []}
end
