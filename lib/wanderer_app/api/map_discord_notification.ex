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

  # Keep the form predicate consistent with the URL argument's length limit.
  @max_webhook_url_length 2000

  # Exclusions reach both integer-based dispatch filters and a PostgreSQL
  # bigint[] column. Reject invalid IDs before they become storage errors.
  @max_postgres_bigint 9_223_372_036_854_775_807

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
    # status write would decrypt the credential — including any copy of the
    # struct a caller caches, which would then hold the webhook in plaintext for
    # the lifetime of that cache entry. Only the call sites that actually post
    # to Discord, or render the masked hint, need the plaintext, and they load
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

    defaults [:read, :destroy]

    create :create do
      primary? true
      validate {__MODULE__.ValidateWebhookUrl, []}
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

      change after_transaction(&__MODULE__.broadcast_status/3)
    end
  end

  changes do
    # Ciphertext is stable across status writes but changes whenever the URL is
    # replaced. Match it in the SQL UPDATE so an in-flight outcome for the old
    # endpoint cannot affect the replacement. Unlike updated_at locking, this
    # still permits concurrent failure increments for the same endpoint.
    change fn changeset, _context ->
      if changeset.action.name in [:record_success, :record_failure, :disable] do
        Ash.Changeset.filter(changeset,
          encrypted_webhook_url: changeset.data.encrypted_webhook_url
        )
      else
        changeset
      end
    end

    # AshCloak's generated argument does not inherit sensitive?. Cast failures
    # (for example max_length) therefore retain the credential in error.value,
    # which callers may log even though Ash redacts the enclosing changeset.
    change fn changeset, _context ->
      errors =
        Enum.map(changeset.errors, fn
          %Ash.Error.Changes.InvalidArgument{field: :webhook_url} = error ->
            %{error | value: Ash.Helpers.redact(error.value)}

          error ->
            error
        end)

      %{changeset | errors: errors}
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
      constraints items: [min: 1, max: @max_postgres_bigint]
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
  # transaction, so a subscriber that re-reads the record on receiving the
  # broadcast can observe the pre-commit row and render stale status. The
  # sibling resource map_webhook_subscription.ex still uses after_action; this
  # deviates from it deliberately.
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

  @doc """
  Returns true when the URL is a syntactically valid Discord webhook endpoint.
  Exposed so the LiveView form can validate before submitting.
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
    # function, which the form also calls to pre-validate raw input, disagree
    # with what the write actually does.
    String.length(trimmed) <= @max_webhook_url_length and
      not String.match?(trimmed, ~r/[[:cntrl:]]/u) and parsed_webhook_url?(trimmed)
  end

  def valid_webhook_url?(_), do: false

  defp parsed_webhook_url?(url) do
    # URI.parse/1 accepts malformed ports; URI.new/1 rejects invalid request
    # URLs before a saved credential can reach the HTTP client.
    case URI.new(url) do
      {:ok, %URI{scheme: "https", host: host, port: 443, userinfo: nil, path: path}}
      when is_binary(host) and is_binary(path) ->
        String.downcase(host) in @discord_hosts and valid_webhook_path?(path)

      _ ->
        false
    end
  end

  defp valid_webhook_path?(path) do
    # Keep numeric API-version variants and an optional trailing slash. Query
    # parameters (for example thread_id) remain untouched by the path check.
    String.match?(path, ~r{\A/api/(?:v[0-9]+/)?webhooks/[0-9]+/[^/]+/?\z})
  end

  defmodule ValidateWebhookUrl do
    @moduledoc false
    use Ash.Resource.Validation

    @impl true
    def validate(changeset, _opts, _context) do
      # AshCloak turns the field into an optional action argument. Distinguish
      # an omitted update from an explicit nil/blank value: encrypting nil would
      # still produce non-null ciphertext, bypassing the column's NOT NULL.
      case Ash.Changeset.fetch_argument(changeset, :webhook_url) do
        :error when changeset.action_type == :update ->
          :ok

        argument ->
          url =
            case argument do
              {:ok, value} -> value
              :error -> nil
            end

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
