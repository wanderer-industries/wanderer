defmodule WandererApp.Api.MapInvite do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer

  require Ash.Query

  postgres do
    repo(WandererApp.Repo)
    table("map_invites_v1")

    references do
      reference :map, on_delete: :delete
      reference :inviter, on_delete: :nilify
    end
  end

  code_interface do
    define(:new, action: :new)
    define(:read, action: :read)
    define(:destroy, action: :destroy)

    define(:by_id,
      get_by: [:id],
      action: :read
    )

    define(:by_map,
      action: :by_map
    )
  end

  actions do
    default_accept [:token]

    defaults [:update, :destroy]

    read :read do
      primary?(true)

      # Auto-filter by map_id from authenticated token
      prepare fn query, context ->
        case Map.get(context, :map) do
          %{id: map_id} ->
            Ash.Query.filter(query, expr(map_id == ^map_id))

          _ ->
            query
        end
      end

      pagination offset?: true,
                 default_limit: 100,
                 max_page_size: 500,
                 countable: true,
                 required?: false
    end

    create :new do
      accept [:map_id, :token, :type, :valid_until]
      primary?(true)

      argument :map_id, :uuid, allow_nil?: true
      change manage_relationship(:map_id, :map, on_lookup: :relate, on_no_match: nil)
    end

    update :revoke do
      accept []
      require_atomic? false

      change fn changeset, _context ->
        Ash.Changeset.force_change_attribute(changeset, :revoked_at, DateTime.utc_now())
      end
    end

    read :by_map do
      argument(:map_id, :string, allow_nil?: false)
      filter(expr(map_id == ^arg(:map_id)))
    end
  end

  attributes do
    uuid_primary_key :id

    # New v1 fields
    attribute :code, :string do
      allow_nil? true
    end

    attribute :email, :string do
      allow_nil? true
    end

    attribute :expires_at, :utc_datetime do
      allow_nil? true
    end

    attribute :accepted_at, :utc_datetime do
      allow_nil? true
    end

    attribute :revoked_at, :utc_datetime do
      allow_nil? true
    end

    attribute :max_uses, :integer do
      allow_nil? false
      default 1
    end

    attribute :use_count, :integer do
      allow_nil? false
      default 0
    end

    # Legacy fields
    attribute :token, :string do
      allow_nil? true
    end

    attribute :type, :atom do
      default :user
      constraints(one_of: [:user, :admin])
      allow_nil?(false)
    end

    attribute :valid_until, :utc_datetime do
      allow_nil? true
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :map, WandererApp.Api.Map do
      attribute_writable? true
    end

    belongs_to :inviter, WandererApp.Api.User do
      allow_nil? true
    end
  end
end
