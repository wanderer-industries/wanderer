defmodule WandererApp.Api.MapDiscordNotification do
  @moduledoc """
  Per-map Discord webhook configuration for kill notifications.

  Exactly one row per map. The webhook URL is a credential — anyone holding it
  can post arbitrary messages to the channel — so it is encrypted at rest and
  never rendered back in full.
  """

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshCloak]

  @discord_hosts ["discord.com", "discordapp.com", "ptb.discord.com", "canary.discord.com"]

  # Mirrors `WebhookDispatcher`'s threshold (webhook_dispatcher.ex:32): a run of
  # 10 consecutive failures disables the config. Only a 404 bypasses this.
  @max_consecutive_failures 10

  # The truncation length for :last_error, and the attribute's own max_length
  # constraint, so the two cannot drift apart. record_failure/disable slice to
  # this rather than letting an unexpectedly long error be rejected outright.
  @max_error_length 500

  # Discord rejects webhook URLs longer than this, so reject them here rather
  # than at delivery time.
  @max_webhook_url_length 2000

  postgres do
    repo(WandererApp.Repo)
    table("map_discord_notifications_v1")

    references do
      reference :map, on_delete: :delete
    end
  end

  cloak do
    vault(WandererApp.Vault)
    attributes([:webhook_url])
    # Deliberately NOT decrypt_by_default: AshCloak applies that as a
    # resource-wide read preparation and update change, so every read and every
    # status write would decrypt the credential — including the notification
    # struct DiscordDispatcher caches in ETS, which would then hold the webhook
    # in plaintext for the cache TTL. Only two call sites need the plaintext
    # (Discord.Worker's POST and the settings tab's masked hint) and both load
    # `:webhook_url` explicitly. Everywhere else `webhook_url` is
    # %Ash.NotLoaded{}; read it via the argument, as ValidateWebhookUrl does.
  end

  code_interface do
    define(:create, action: :create)
    define(:update, action: :update)
    define(:destroy, action: :destroy)
    define(:by_id, get_by: [:id], action: :read)
    define(:by_map, action: :by_map, args: [:map_id])
    define(:record_success, action: :record_success, exclude_inputs: [:webhook_url])

    define(:record_failure,
      action: :record_failure,
      args: [:error],
      exclude_inputs: [:webhook_url]
    )

    define(:disable, action: :disable, args: [:error], exclude_inputs: [:webhook_url])
  end

  actions do
    default_accept [:map_id, :webhook_url, :enabled?, :wh_only, :excluded_systems]

    defaults [:read]

    # Custom destroy, following map_webhook_subscription.ex:51-58. The default
    # destroy would leave a stale cache entry AND leave the map's delivery
    # worker draining its queue into a webhook the user just removed.
    destroy :destroy do
      primary? true
      require_atomic? false

      change after_transaction(&__MODULE__.after_destroy/3)
    end

    create :create do
      primary? true
      validate {__MODULE__.ValidateWebhookUrl, []}
      change after_transaction(&__MODULE__.invalidate_cache/3)
    end

    update :update do
      primary? true
      require_atomic? false
      # Explicit accept, narrower than default_accept: :map_id is writable
      # (belongs_to sets attribute_writable?), so without this an :update could
      # move an existing webhook config to a different map, bypassing the
      # per-map scoping the LiveView authorizes against. :create still needs it.
      accept [:webhook_url, :enabled?, :wh_only, :excluded_systems]
      validate {__MODULE__.ValidateWebhookUrl, []}

      # A replaced URL is a different endpoint, so the previous one's failure run
      # must not follow it: a config sitting at 9 consecutive failures would
      # otherwise be disabled by the very first hiccup against the new webhook,
      # and would keep displaying the old endpoint's error in the settings tab.
      # AshCloak rewrites the encrypted field into an argument, so this reads the
      # argument — status-only updates leave it nil and are untouched.
      change fn changeset, _ctx ->
        case Ash.Changeset.get_argument(changeset, :webhook_url) do
          url when is_binary(url) ->
            changeset
            |> Ash.Changeset.change_attribute(:consecutive_failures, 0)
            |> Ash.Changeset.change_attribute(:last_error, nil)
            |> Ash.Changeset.change_attribute(:last_error_at, nil)

          _ ->
            changeset
        end
      end

      change after_transaction(&__MODULE__.invalidate_cache/3)
    end

    read :by_map do
      argument :map_id, :uuid, allow_nil?: false
      get? true
      filter expr(map_id == ^arg(:map_id))
    end

    update :record_success do
      require_atomic? false
      accept []

      change set_attribute(:last_delivery_at, &DateTime.utc_now/0)
      change set_attribute(:consecutive_failures, 0)
      change set_attribute(:last_error, nil)
      change set_attribute(:last_error_at, nil)

      change after_transaction(&__MODULE__.broadcast_status/3)
    end

    # Increments the counter and disables the config once the run reaches
    # @max_consecutive_failures.
    #
    # Both writes are atomic SQL expressions, so the increment is a single
    # UPDATE with no preceding read: concurrent deliveries cannot lose an
    # increment, and the threshold is evaluated against the row's committed
    # value rather than a possibly-stale in-memory copy. This holds under
    # clustering, not just the single-delivery-node assumption in the spec.
    #
    # `require_atomic? false` remains because :last_error is set from an
    # argument in a regular change; the two counter writes are atomic
    # regardless.
    update :record_failure do
      require_atomic? false
      accept []
      argument :error, :string, allow_nil?: false

      change atomic_update(:consecutive_failures, expr(consecutive_failures + 1))

      # Evaluated in SQL as a CASE over the pre-update value, so it agrees with
      # the increment above even if another delivery commits in between.
      change atomic_update(
               :enabled?,
               expr(
                 if consecutive_failures + 1 >= ^@max_consecutive_failures do
                   false
                 else
                   enabled?
                 end
               )
             )

      change fn changeset, _ctx ->
        changeset
        |> Ash.Changeset.change_attribute(
          :last_error,
          changeset |> Ash.Changeset.get_argument(:error) |> String.slice(0, @max_error_length)
        )
        |> Ash.Changeset.change_attribute(:last_error_at, DateTime.utc_now())
      end

      change after_transaction(&__MODULE__.invalidate_cache/3)
      change after_transaction(&__MODULE__.broadcast_status/3)
    end

    # Immediate disable, used only for a 404 (webhook deleted upstream, will
    # never recover). Everything else goes through record_failure's threshold.
    update :disable do
      require_atomic? false
      accept []
      argument :error, :string, allow_nil?: false

      change set_attribute(:enabled?, false)
      change set_attribute(:last_error_at, &DateTime.utc_now/0)

      change fn changeset, _ctx ->
        Ash.Changeset.change_attribute(
          changeset,
          :last_error,
          changeset |> Ash.Changeset.get_argument(:error) |> String.slice(0, @max_error_length)
        )
      end

      change after_transaction(&__MODULE__.invalidate_cache/3)
      change after_transaction(&__MODULE__.broadcast_status/3)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :webhook_url, :string do
      allow_nil? false
      sensitive? true
      constraints max_length: @max_webhook_url_length
    end

    attribute :enabled?, :boolean, default: true, allow_nil?: false
    attribute :wh_only, :boolean, default: true, allow_nil?: false

    attribute :excluded_systems, {:array, :integer} do
      default []
      allow_nil? false
    end

    attribute :last_delivery_at, :utc_datetime
    attribute :last_error, :string, constraints: [max_length: @max_error_length]
    attribute :last_error_at, :utc_datetime
    attribute :consecutive_failures, :integer, default: 0, allow_nil?: false

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :map, WandererApp.Api.Map do
      attribute_writable? true
      allow_nil? false
    end
  end

  identities do
    identity :unique_map_id, [:map_id]
  end

  # after_transaction, not after_action: an after_action hook runs *inside* the
  # transaction, so a concurrent reader can re-populate the cache from the
  # pre-commit row in the window between the invalidation and the commit.
  # DiscordDispatcher's cache has a 5-minute TTL (discord_dispatcher.ex:271,277),
  # but within that window a stale entry would survive an after_action
  # invalidation racing a concurrent reader — kills would keep being posted to
  # a webhook the user had already replaced or disabled until the TTL expires.
  # The sibling resource map_webhook_subscription.ex still uses after_action for
  # the same purpose; this deviates from it deliberately.
  @doc """
  PubSub topic carrying delivery-status changes for a map's Discord config.

  Delivery outcomes are written by the map's Discord worker, out of band from
  whoever is looking at the settings tab, so the tab has no other way to learn
  that a webhook has started failing — or has been auto-disabled after
  #{@max_consecutive_failures} consecutive failures.
  """
  def status_topic(map_id), do: "discord_notification_status:#{map_id}"

  @doc false
  def broadcast_status(_changeset, {:ok, record} = result, _context) do
    Phoenix.PubSub.broadcast(
      WandererApp.PubSub,
      status_topic(record.map_id),
      %{event: :discord_notification_status, map_id: record.map_id}
    )

    result
  end

  def broadcast_status(_changeset, result, _context), do: result

  @doc false
  def invalidate_cache(_changeset, {:ok, record} = result, _context) do
    WandererApp.ExternalEvents.DiscordDispatcher.invalidate_cache(record.map_id)
    result
  end

  def invalidate_cache(_changeset, result, _context), do: result

  @doc false
  def after_destroy(_changeset, {:error, _} = result, _context), do: result

  # A destroy yields `:ok` or `{:ok, record}` depending on `return_destroyed?`,
  # so the map id is taken from the changeset's own data, which is the record
  # being destroyed in either case.
  def after_destroy(changeset, result, _context) do
    map_id = changeset.data.map_id

    WandererApp.ExternalEvents.DiscordDispatcher.invalidate_cache(map_id)
    # Stop the map's delivery worker too: without this, anything already queued
    # keeps posting to a webhook the user has just removed.
    WandererApp.ExternalEvents.Discord.WorkerSupervisor.stop_worker(map_id)
    result
  end

  @doc """
  Returns true when the URL is a syntactically valid Discord webhook endpoint.

  Used by the changeset validation on create/update; also available to any
  caller that wants to check a URL up front, outside of a changeset.
  """
  def valid_webhook_url?(url) when is_binary(url) do
    trimmed = String.trim(url)

    # Control characters are rejected rather than stripped: URI.parse/1 keeps
    # them inside the path, so ".../api/webhooks/1/abc\ndef" would clear the
    # segment checks below and reach Finch as a request URL. Discord tokens
    # never contain one.
    #
    # Surrounding whitespace is tolerated instead, because Ash's :string type
    # trims before the value is stored — rejecting it here would make this
    # function disagree with what the write actually does.
    not String.match?(trimmed, ~r/[[:cntrl:]]/u) and parsed_webhook_url?(trimmed)
  end

  def valid_webhook_url?(_), do: false

  defp parsed_webhook_url?(url) do
    case URI.parse(url) do
      %URI{scheme: "https", host: host, path: path} when is_binary(host) and is_binary(path) ->
        # URI.parse/1 normalizes the scheme but not the host, so a pasted
        # "https://Discord.com/..." would otherwise fail the allowlist.
        String.downcase(host) in @discord_hosts and valid_webhook_path?(path)

      _ ->
        false
    end
  end

  defp valid_webhook_path?(path) do
    case String.split(path, "/", trim: true) do
      ["api", "webhooks", id, token] ->
        id != "" and token != ""

      ["api", version, "webhooks", id, token] ->
        String.starts_with?(version, "v") and id != "" and token != ""

      _ ->
        false
    end
  end

  defmodule ValidateWebhookUrl do
    @moduledoc false
    use Ash.Resource.Validation

    @impl true
    def validate(changeset, _opts, _context) do
      # AshCloak rewrites the encrypted field into a changeset *argument* (the
      # stored attribute is `encrypted_webhook_url`, and `webhook_url` becomes a
      # calculation). Reading only the attribute yields `%Ash.NotLoaded{}` — not
      # nil — which fails every validity check and rejects even valid URLs.
      # Read the argument first so the value being written is what gets checked.
      case Ash.Changeset.get_argument_or_attribute(changeset, :webhook_url) do
        # The action is not writing a URL. Because the resource does not
        # decrypt by default, the attribute falls back to the unloaded
        # calculation, so every status-only update (enabled?, wh_only,
        # excluded_systems) lands here. There is nothing to validate — the
        # stored ciphertext is untouched.
        %Ash.NotLoaded{} ->
          :ok

        nil ->
          :ok

        url ->
          if WandererApp.Api.MapDiscordNotification.valid_webhook_url?(url) do
            :ok
          else
            {:error,
             field: :webhook_url,
             message:
               "must be a Discord webhook URL, e.g. https://discord.com/api/webhooks/{id}/{token}"}
          end
      end
    end
  end
end
