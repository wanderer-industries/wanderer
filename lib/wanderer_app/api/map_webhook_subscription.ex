defmodule WandererApp.Api.MapWebhookSubscription do
  @moduledoc """
  Ash resource for managing webhook subscriptions for map events.

  Stores webhook endpoint configurations that receive HTTP POST notifications
  when events occur on a specific map.
  """

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshCloak]

  postgres do
    repo(WandererApp.Repo)
    table("map_webhook_subscriptions_v1")
  end

  cloak do
    vault(WandererApp.Vault)
    attributes([:secret])
    decrypt_by_default([:secret])
  end

  code_interface do
    define(:create, action: :create)
    define(:update, action: :update)
    define(:destroy, action: :destroy)

    define(:by_id,
      get_by: [:id],
      action: :read
    )

    define(:by_map, action: :by_map, args: [:map_id])
    define(:active_by_map, action: :active_by_map, args: [:map_id])
    define(:rotate_secret, action: :rotate_secret)
  end

  actions do
    default_accept [
      :map_id,
      :url,
      :events,
      :active?
    ]

    defaults [:read, :destroy]

    update :update do
      accept [
        :url,
        :events,
        :active?,
        :last_delivery_at,
        :last_error,
        :last_error_at,
        :consecutive_failures,
        :secret
      ]
    end

    read :by_map do
      argument :map_id, :uuid, allow_nil?: false
      filter expr(map_id == ^arg(:map_id))
      prepare build(sort: [inserted_at: :desc])
    end

    read :active_by_map do
      argument :map_id, :uuid, allow_nil?: false
      filter expr(map_id == ^arg(:map_id) and active? == true)
      prepare build(sort: [inserted_at: :desc])
    end

    create :create do
      accept [
        :map_id,
        :url,
        :events,
        :active?
      ]

      # Validate webhook URL format
      change fn changeset, _context ->
        case Ash.Changeset.get_attribute(changeset, :url) do
          nil ->
            changeset

          url ->
            case validate_webhook_url_format(url) do
              :ok ->
                changeset

              {:error, message} ->
                Ash.Changeset.add_error(changeset, field: :url, message: message)
            end
        end
      end

      # Validate events list
      change fn changeset, _context ->
        case Ash.Changeset.get_attribute(changeset, :events) do
          nil ->
            changeset

          events when is_list(events) ->
            case validate_events_list(events) do
              :ok ->
                changeset

              {:error, message} ->
                Ash.Changeset.add_error(changeset, field: :events, message: message)
            end

          _ ->
            changeset
        end
      end

      # Generate secret on creation
      change fn changeset, _context ->
        secret = generate_webhook_secret()
        Ash.Changeset.force_change_attribute(changeset, :secret, secret)
      end
    end

    update :rotate_secret do
      accept []
      require_atomic? false

      change fn changeset, _context ->
        new_secret = generate_webhook_secret()
        Ash.Changeset.change_attribute(changeset, :secret, new_secret)
      end
    end
  end

  validations do
    validate present(:url), message: "URL is required"
    validate present(:events), message: "Events array is required"
    validate present(:map_id), message: "Map ID is required"
  end

  attributes do
    uuid_primary_key :id

    attribute :map_id, :uuid do
      allow_nil? false
    end

    attribute :url, :string do
      allow_nil? false
      # 2KB limit as per security requirements
      constraints max_length: 2000
    end

    attribute :events, {:array, :string} do
      allow_nil? false
      default []

      constraints min_length: 1,
                  # Reasonable limit on number of event types
                  max_length: 50,
                  # Max length per event type
                  items: [max_length: 100]
    end

    attribute :secret, :string do
      allow_nil? false
      # Hide in logs and API responses
      sensitive? true
    end

    attribute :active?, :boolean do
      allow_nil? false
      default true
    end

    # Delivery tracking fields
    attribute :last_delivery_at, :utc_datetime do
      allow_nil? true
    end

    attribute :last_error, :string do
      allow_nil? true
      constraints max_length: 1000
    end

    attribute :last_error_at, :utc_datetime do
      allow_nil? true
    end

    attribute :consecutive_failures, :integer do
      allow_nil? false
      default 0
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :map, WandererApp.Api.Map do
      source_attribute :map_id
      destination_attribute :id
      attribute_writable? true
    end
  end

  identities do
    # Allow multiple webhooks per map, but prevent duplicate URLs per map
    identity :unique_url_per_map, [:map_id, :url]
  end

  # Private helper functions

  defp generate_webhook_secret do
    :crypto.strong_rand_bytes(32) |> Base.encode64()
  end

  defp validate_webhook_url_format(url) do
    uri = URI.parse(url)

    cond do
      uri.scheme != "https" ->
        {:error, "Webhook URL must use HTTPS"}

      uri.host == nil ->
        {:error, "Webhook URL must have a valid host"}

      uri.host in ["localhost", "127.0.0.1", "0.0.0.0"] ->
        {:error, "Webhook URL cannot use localhost or loopback addresses"}

      String.starts_with?(uri.host, "192.168.") or String.starts_with?(uri.host, "10.") or
          is_private_ip_172_range?(uri.host) ->
        {:error, "Webhook URL cannot use private network addresses"}

      byte_size(url) > 2000 ->
        {:error, "Webhook URL cannot exceed 2000 characters"}

      true ->
        :ok
    end
  end

  defp validate_events_list(events) do
    alias WandererApp.ExternalEvents.Event

    # Get valid event types as strings
    valid_event_strings =
      Event.supported_event_types()
      |> Enum.map(&Atom.to_string/1)

    # Add wildcard as valid option
    valid_events = ["*" | valid_event_strings]

    invalid_events = Enum.reject(events, fn event -> event in valid_events end)

    if Enum.empty?(invalid_events) do
      :ok
    else
      {:error, "Invalid event types: #{Enum.join(invalid_events, ", ")}"}
    end
  end

  # Check if IP is in the 172.16.0.0/12 range (172.16.0.0 to 172.31.255.255)
  defp is_private_ip_172_range?(host) do
    case :inet.parse_address(String.to_charlist(host)) do
      {:ok, {172, b, _, _}} when b >= 16 and b <= 31 ->
        true

      _ ->
        false
    end
  end
end
