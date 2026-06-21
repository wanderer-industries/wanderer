defmodule WandererAppWeb.HandlerAuth do
  @moduledoc """
  Authorization helpers used by LiveView event handlers to verify that a
  client-supplied record id belongs to the map (or user) currently in scope.

  These helpers exist because LiveView `handle_event` callbacks receive
  unvalidated client params. A malicious client can submit any UUID it likes;
  the server must check that the record actually belongs to the authenticated
  context before acting on it.

  Each helper returns `{:ok, record}` when the lookup succeeds AND the record
  is scoped to the given context, or `{:error, :not_found}` otherwise.

  We deliberately return `:not_found` (rather than `:unauthorized`) for both
  the "record does not exist" and "record exists but on a different map"
  cases — this avoids leaking the existence of records in other contexts.
  """

  @doc """
  Returns `{:ok, subscription}` if the subscription exists and belongs to `map_id`,
  `{:error, :not_found}` otherwise.
  """
  def authorize_subscription(subscription_id, map_id) when is_binary(map_id) do
    with {:ok, subscription} <- WandererApp.Api.MapSubscription.by_id(subscription_id),
         true <- subscription.map_id == map_id do
      {:ok, subscription}
    else
      _ -> {:error, :not_found}
    end
  end

  def authorize_subscription(_subscription_id, _map_id), do: {:error, :not_found}

  @doc """
  Returns `{:ok, character}` if the character exists and is owned by `user_id`,
  `{:error, :not_found}` otherwise.
  """
  def authorize_character(character_id, user_id) when is_binary(user_id) do
    with {:ok, character} <- WandererApp.Api.Character.by_id(character_id),
         true <- character.user_id == user_id do
      {:ok, character}
    else
      _ -> {:error, :not_found}
    end
  end

  def authorize_character(_character_id, _user_id), do: {:error, :not_found}

  @doc """
  Returns `{:ok, ping}` if the ping exists and belongs to `map_id`,
  `{:error, :not_found}` otherwise.

  Uses the `:all_pings` read action (which has no actor filter) so the
  helper can do the map-scoping check itself. The primary `:read` action's
  `FilterPingsByActorMap` preparation is for token-based API auth and is
  not applicable in the LiveView context.
  """
  def authorize_ping(ping_id, map_id) when is_binary(map_id) do
    require Ash.Query

    result =
      WandererApp.Api.MapPing
      |> Ash.Query.for_read(:all_pings)
      |> Ash.Query.filter(id == ^ping_id)
      |> Ash.read_one()

    case result do
      {:ok, %{} = ping} ->
        if ping.map_id == map_id, do: {:ok, ping}, else: {:error, :not_found}

      _ ->
        {:error, :not_found}
    end
  end

  def authorize_ping(_ping_id, _map_id), do: {:error, :not_found}

  @doc """
  Returns `{:ok, comment}` if the comment's system belongs to `map_id`,
  `{:error, :not_found}` otherwise.

  Comments live on a system (`comment.system_id`), and we want the comment's
  system to belong to the current map.
  """
  def authorize_system_comment(comment_id, map_id) when is_binary(map_id) do
    with {:ok, comment} <- WandererApp.MapSystemCommentRepo.get_by_id(comment_id),
         {:ok, system} <- WandererApp.Api.MapSystem.by_id(comment.system_id),
         true <- system.map_id == map_id do
      {:ok, comment}
    else
      _ -> {:error, :not_found}
    end
  end

  def authorize_system_comment(_comment_id, _map_id), do: {:error, :not_found}

  @doc """
  Returns `{:ok, passage}` if the passage exists and belongs to `map_id`,
  `{:error, :not_found}` otherwise.
  """
  def authorize_passage(passage_id, map_id) when is_binary(map_id) do
    with {:ok, passage} when not is_nil(passage) <-
           WandererApp.Api.MapChainPassages.by_id(passage_id),
         true <- passage.map_id == map_id do
      {:ok, passage}
    else
      _ -> {:error, :not_found}
    end
  end

  def authorize_passage(_passage_id, _map_id), do: {:error, :not_found}

  @doc """
  Returns `true` if the given `eve_id` matches any character in the user's
  loaded character list.
  """
  def user_owns_character_eve_id?(user_characters, eve_id) when is_list(user_characters) do
    eve_id_str = "#{eve_id}"
    Enum.any?(user_characters, fn c -> "#{c.eve_id}" == eve_id_str end)
  end

  def user_owns_character_eve_id?(_user_characters, _eve_id), do: false

  @doc """
  Parses a client-supplied subscription period (in months).

  Returns `{:ok, n}` only for values offered by the form select
  (1, 3, 6, or 12 months). Anything else — non-numeric strings, negative
  numbers, very large numbers — returns `{:error, message}`.

  This blocks the negative-period exploit where `period: "-1"` produces
  a back-dated subscription and flips the price calculation to negative.
  """
  @valid_subscription_periods [1, 3, 6, 12]
  def parse_subscription_period(period) when is_binary(period) do
    case Integer.parse(period) do
      {n, ""} when n in @valid_subscription_periods -> {:ok, n}
      _ -> {:error, "Invalid subscription period."}
    end
  end

  def parse_subscription_period(_), do: {:error, "Invalid subscription period."}

  @doc """
  Parses a client-supplied `characters_limit` value. The form range input
  allows 50..5000 step 50; anything outside that range is rejected.
  """
  def parse_characters_limit(value), do: parse_bounded_int(value, 50, 5_000, "characters limit")

  @doc """
  Parses a client-supplied `hubs_limit` value. The form range input
  allows 20..50 step 10; anything outside that range is rejected.
  """
  def parse_hubs_limit(value), do: parse_bounded_int(value, 20, 50, "hubs limit")

  defp parse_bounded_int(value, min, max, label) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} when n >= min and n <= max -> {:ok, n}
      _ -> {:error, "Invalid #{label}."}
    end
  end

  defp parse_bounded_int(value, min, max, _label)
       when is_integer(value) and value >= min and value <= max,
       do: {:ok, value}

  defp parse_bounded_int(_, _, _, label), do: {:error, "Invalid #{label}."}
end
