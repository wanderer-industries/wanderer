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
    decrypt_by_default([:webhook_url])
  end

  code_interface do
    define(:create, action: :create)
    define(:update, action: :update)
    define(:destroy, action: :destroy)
    define(:by_id, get_by: [:id], action: :read)
    define(:by_map, action: :by_map, args: [:map_id])
    define(:record_success, action: :record_success)
    define(:record_failure, action: :record_failure, args: [:error])
    define(:disable, action: :disable, args: [:error])
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

      change after_action(&__MODULE__.after_destroy/3)
    end

    create :create do
      primary? true
      validate {__MODULE__.ValidateWebhookUrl, []}
      change after_action(&__MODULE__.invalidate_cache/3)
    end

    update :update do
      primary? true
      require_atomic? false
      validate {__MODULE__.ValidateWebhookUrl, []}
      change after_action(&__MODULE__.invalidate_cache/3)
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
    end

    # Increments the counter from the value re-read inside the change rather
    # than from a possibly-stale in-memory copy, and disables the config once
    # the run reaches @max_consecutive_failures.
    #
    # This read-then-write is NOT atomic across nodes: two concurrent deliveries
    # on separate nodes could each read N and write N+1, losing an increment.
    # That is safe under the single-delivery-node assumption documented in the
    # spec (one worker per map, one node), and the failure mode is benign — a
    # config disables slightly later than it should. If the app is ever
    # clustered, replace this with an atomic SQL increment.
    update :record_failure do
      require_atomic? false
      accept []
      argument :error, :string, allow_nil?: false

      change fn changeset, _ctx ->
        current =
          case Ash.get(__MODULE__, changeset.data.id) do
            {:ok, fresh} -> fresh.consecutive_failures || 0
            _ -> Ash.Changeset.get_data(changeset, :consecutive_failures) || 0
          end

        next = current + 1

        changeset =
          changeset
          |> Ash.Changeset.change_attribute(:consecutive_failures, next)
          |> Ash.Changeset.change_attribute(
            :last_error,
            changeset |> Ash.Changeset.get_argument(:error) |> String.slice(0, 500)
          )
          |> Ash.Changeset.change_attribute(:last_error_at, DateTime.utc_now())

        if next >= @max_consecutive_failures do
          Ash.Changeset.change_attribute(changeset, :enabled?, false)
        else
          changeset
        end
      end

      change after_action(&__MODULE__.invalidate_cache/3)
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
          Ash.Changeset.get_argument(changeset, :error)
        )
      end

      change after_action(&__MODULE__.invalidate_cache/3)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :webhook_url, :string do
      allow_nil? false
      sensitive? true
      constraints max_length: 2000
    end

    attribute :enabled?, :boolean, default: true, allow_nil?: false
    attribute :wh_only, :boolean, default: true, allow_nil?: false

    attribute :excluded_systems, {:array, :integer} do
      default []
      allow_nil? false
    end

    attribute :last_delivery_at, :utc_datetime
    attribute :last_error, :string, constraints: [max_length: 500]
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

  @doc false
  def invalidate_cache(_changeset, record, _context) do
    WandererApp.ExternalEvents.DiscordDispatcher.invalidate_cache(record.map_id)
    {:ok, record}
  end

  @doc false
  def after_destroy(_changeset, record, _context) do
    WandererApp.ExternalEvents.DiscordDispatcher.invalidate_cache(record.map_id)
    # Stop the map's delivery worker too: without this, anything already queued
    # keeps posting to a webhook the user has just removed.
    WandererApp.ExternalEvents.Discord.WorkerSupervisor.stop_worker(record.map_id)
    {:ok, record}
  end

  @doc """
  Returns true when the URL is a syntactically valid Discord webhook endpoint.
  Exposed so the LiveView form can validate before submitting.
  """
  def valid_webhook_url?(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: "https", host: host, path: path} when is_binary(host) and is_binary(path) ->
        host in @discord_hosts and valid_webhook_path?(path)

      _ ->
        false
    end
  end

  def valid_webhook_url?(_), do: false

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
