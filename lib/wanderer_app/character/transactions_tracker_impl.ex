defmodule WandererApp.Character.TransactionsTracker.Impl do
  @moduledoc false
  require Logger

  alias WandererApp.Api.Character

  defstruct [
    :character_id,
    :character,
    :max_retries,
    :wallets,
    total_balance: 0,
    transactions: [],
    retries: 5,
    server_online: true,
    status: :started
  ]

  @update_interval :timer.minutes(1)

  def update(%__MODULE__{character: _character} = state) do
    state
  end

  def get_total_balance(%__MODULE__{total_balance: total_balance} = _state) do
    {:ok, total_balance}
  end

  def get_transactions(%__MODULE__{transactions: transactions} = _state) do
    {:ok, transactions}
  end

  def init(args) do
    character = load_character(args[:character_id])

    %__MODULE__{
      character_id: args[:character_id],
      character: character,
      wallets: [],
      max_retries: 5
    }
  end

  def start(%{character: character} = state) do
    Phoenix.PubSub.subscribe(
      WandererApp.PubSub,
      "server_status"
    )

    Phoenix.PubSub.subscribe(
      WandererApp.PubSub,
      "character:#{character.id}"
    )

    {:ok, latest_transactions} = WandererApp.Api.CorpWalletTransaction.latest()

    case character.eve_id == WandererApp.Env.corp_wallet_eve_id() &&
           WandererApp.Character.can_track_corp_wallet?(character) do
      true ->
        Process.send_after(self(), :update_corp_wallets, 500)
        Process.send_after(self(), :check_wallets, 500)

      _ ->
        :ok
    end

    %{state | transactions: latest_transactions}
  end

  def handle_event({:server_status, status}, state),
    do: %{state | server_online: not status.vip}

  def handle_event(:token_updated, %{character: character} = state),
    do: %{state | character: load_character(character.id)}

  def handle_event(
        :update_corp_wallets,
        %{character: character} = state
      ) do
    Process.send_after(self(), :update_corp_wallets, @update_interval)

    Task.async(fn -> update_corp_wallets(character) end)

    state
  end

  def handle_event(
        :update_corp_wallets,
        state
      ) do
    Process.send_after(self(), :update_corp_wallets, :timer.seconds(15))

    state
  end

  def handle_event(
        :check_wallets,
        %{wallets: []} = state
      ) do
    Process.send_after(self(), :check_wallets, :timer.seconds(5))

    state
  end

  def handle_event(
        :check_wallets,
        %{character: character, wallets: wallets} = state
      ) do
    check_wallets(wallets, character)

    Process.send_after(self(), :check_wallets, @update_interval)

    state
  end

  def handle_event({ref, result}, state) do
    Process.demonitor(ref, [:flush])

    case result do
      {:corporation_wallets, result} ->
        state |> maybe_update_total_balance(result)

      {:corporation_wallet_journal, result} ->
        state |> maybe_update_transactions(result)

      {:error, _error} ->
        state

      _ ->
        state
    end
  end

  def handle_event(_action, state),
    do: state

  defp check_wallets([], _character), do: :ok

  defp check_wallets([wallet | wallets], character) do
    check_wallet(wallet, character)
    check_wallets(wallets, character)
  end

  defp check_wallet(%{"division" => division} = _wallet, character) do
    Task.async(fn -> get_wallet_journal(character, division) end)
  end

  defp get_wallet_journal(
         %{
           id: character_id,
           corporation_id: corporation_id,
           access_token: access_token,
           tracking_pool: tracking_pool
         } =
           _character,
         division
       )
       when not is_nil(access_token) do
    case WandererApp.Esi.get_corporation_wallet_journal(corporation_id, division,
           params: %{datasource: "tranquility"},
           access_token: access_token,
           character_id: character_id
         ) do
      {:ok, result} ->
        {:corporation_wallet_journal, result}

      {:error, :forbidden} ->
        Logger.warning("#{__MODULE__} failed to get_wallet_journal: forbidden")
        {:error, :forbidden}

      {:error, :error_limited, _headers} ->
        Logger.warning("#{inspect(tracking_pool)} ..")
        {:error, :error_limited}

      {:error, error} ->
        Logger.warning("#{__MODULE__} failed to get_wallet_journal: #{inspect(error)}")
        {:error, error}
    end
  end

  defp get_wallet_journal(_character, _division), do: {:error, :skipped}

  defp update_corp_wallets(
         %{
           id: character_id,
           corporation_id: corporation_id,
           access_token: access_token,
           tracking_pool: tracking_pool
         } =
           _character
       )
       when not is_nil(access_token) do
    case WandererApp.Esi.get_corporation_wallets(corporation_id,
           params: %{datasource: "tranquility"},
           access_token: access_token,
           character_id: character_id
         ) do
      {:ok, result} ->
        {:corporation_wallets, result}

      {:error, :forbidden} ->
        Logger.warning("#{__MODULE__} failed to update_corp_wallets: forbidden")
        {:error, :forbidden}

      {:error, :error_limited, _headers} ->
        Logger.warning("#{inspect(tracking_pool)} ..")
        {:error, :error_limited}

      {:error, error} ->
        Logger.warning("#{__MODULE__} failed to update_corp_wallets: #{inspect(error)}")
        {:error, error}
    end
  end

  defp update_corp_wallets(_character), do: {:error, :skipped}

  defp maybe_update_total_balance(
         %{character: character, total_balance: total_balance} =
           state,
         wallets
       ) do
    new_total_balance =
      Enum.reduce(wallets, 0, fn %{"balance" => balance}, acc ->
        acc + balance
      end)

    if new_total_balance != total_balance do
      Phoenix.PubSub.broadcast(
        WandererApp.PubSub,
        "corporation",
        {:total_balance_changed, character.corporation_id, new_total_balance}
      )

      %{state | wallets: wallets, total_balance: new_total_balance}
    else
      %{state | wallets: wallets}
    end
  end

  defp maybe_update_transactions(
         %{character: character, transactions: transactions} =
           state,
         new_transactions
       ) do
    new_transactions =
      new_transactions
      |> Enum.map(&map_transaction/1)

    maybe_save_transactions(new_transactions)

    new_transactions = filter_new_transactions(transactions, new_transactions)

    new_transactions
    |> Enum.each(fn transaction ->
      maybe_update_user_balance(transaction)
    end)

    {:ok, transactions} = WandererApp.Api.CorpWalletTransaction.latest()

    if not (new_transactions |> Enum.empty?()) do
      Phoenix.PubSub.broadcast(
        WandererApp.PubSub,
        "corporation",
        {:transactions, character.corporation_id, transactions |> Enum.sort_by(& &1.date, :desc)}
      )
    end

    %{state | transactions: transactions}
  end

  def maybe_update_user_balance(
        %{first_party_id: first_party_id, amount_encoded: amount} =
          _transaction
      ) do
    case WandererApp.Api.Character.by_eve_id("#{first_party_id}") |> Ash.load(:user) do
      {:ok, character} ->
        {:ok, user} =
          character.user
          |> Ash.load([:balance])

        {:ok, user} =
          user
          |> WandererApp.Api.User.update_balance(%{
            balance: (user.balance || 0.0) + amount
          })

        Phoenix.PubSub.broadcast(
          WandererApp.PubSub,
          "user:#{user.id}",
          :wanderer_balance_changed
        )

        :telemetry.execute([:wanderer_app, :user, :wallet_balance, :changed], %{count: 1})
        :ok

      _ ->
        :ok
    end
  end

  def maybe_save_transactions(transactions) do
    if not (transactions |> Enum.empty?()) do
      transactions
      |> Ash.bulk_create(WandererApp.Api.CorpWalletTransaction, :new)
    end
  end

  def filter_new_transactions(old_transactions, new_transactions) do
    new_transactions
    |> Enum.filter(fn new_transaction ->
      old_transactions
      |> Enum.find(fn old_transaction ->
        old_transaction.eve_transaction_id == new_transaction.eve_transaction_id
      end)
      |> is_nil()
    end)
  end

  defp map_transaction(%{
         "id" => id,
         "amount" => amount,
         "balance" => balance,
         "date" => date,
         "description" => description,
         "first_party_id" => first_party_id,
         "reason" => reason,
         "ref_type" => ref_type,
         "second_party_id" => second_party_id
       }) do
    {:ok, date, _} = DateTime.from_iso8601(date)

    %{
      eve_transaction_id: id,
      amount_encoded: amount,
      balance_encoded: balance,
      date: date,
      description: description,
      first_party_id: first_party_id,
      reason_encoded: reason,
      ref_type: ref_type,
      second_party_id: second_party_id
    }
  end

  defp load_character(nil), do: nil

  defp load_character(character_id) do
    case Character.by_id(character_id) do
      {:ok, character} -> character
      {:error, _} -> nil
    end
  end
end
