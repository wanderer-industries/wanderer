defmodule WandererApp.Api.MapInvite do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    repo(WandererApp.Repo)
    table("map_invites_v1")

    references do
      reference :map, on_delete: :delete
    end
  end

  json_api do
    type "map_invites"

    default_fields([
      :code,
      :email,
      :expires_at,
      :accepted_at,
      :revoked_at,
      :max_uses,
      :use_count
    ])

    routes do
      base("/map_invites")
      index :read
      get(:read)
      post(:create)
      patch(:revoke, route: "/:id/revoke")
      delete(:destroy)
    end
  end

  code_interface do
    define(:new, action: :new)
    define(:create, action: :create)
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

    create :create do
      accept [:map_id, :email, :expires_at, :max_uses]

      change fn changeset, context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:code, generate_invite_code())
        |> Ash.Changeset.force_change_attribute(:inviter_id, get_user_id(context))
      end
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

  defp generate_invite_code do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  defp get_user_id(context) do
    case context do
      %{actor: %{id: id}} -> id
      _ -> nil
    end
  end
end
