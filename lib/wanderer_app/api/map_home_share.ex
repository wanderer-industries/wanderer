defmodule WandererApp.Api.MapHomeShare do
  @moduledoc """
  A home somebody else shared, as this map sees it.

  One row is one subscription: a token, the map it points at, and - when that map lives on
  another instance - where to find it. A row without a base url is a map on this instance, which
  is the same handshake without the trip over the wire.
  """

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    primary_read_warning?: false

  postgres do
    repo(WandererApp.Repo)
    table("map_home_shares_v1")

    references do
      reference :map, on_delete: :delete
    end
  end

  code_interface do
    define(:new, action: :new)
    define(:destroy, action: :destroy)
    define(:by_id, get_by: [:id], action: :read)
    define(:by_map, action: :by_map)
  end

  actions do
    defaults [:read, :destroy]

    create :new do
      accept [:map_id, :label, :base_url, :slug, :token]
      primary?(true)

      upsert?(true)
      upsert_identity(:unique_share)
      upsert_fields([:label, :token])
    end

    read :by_map do
      argument(:map_id, :string, allow_nil?: false)

      filter(expr(map_id == ^arg(:map_id)))
    end
  end

  attributes do
    uuid_primary_key :id

    # what to call it in the menu; the shared map's own name when it does not say otherwise
    attribute :label, :string do
      allow_nil? true
    end

    # empty means a map on this instance - kept as a string rather than nil because Postgres
    # counts two nulls as different rows, which would let the same share in twice
    attribute :base_url, :string do
      allow_nil? false
      default ""
      constraints max_length: 500, allow_empty?: true
    end

    attribute :slug, :string do
      allow_nil? false
    end

    attribute :token, :string do
      allow_nil? false
      constraints max_length: 64
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :map, WandererApp.Api.Map do
      attribute_writable? true
    end
  end

  identities do
    identity :unique_share, [:map_id, :base_url, :slug]
  end
end
