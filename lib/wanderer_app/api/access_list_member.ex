defmodule WandererApp.Api.AccessListMember do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  require Ash.Query

  postgres do
    repo(WandererApp.Repo)
    table("access_list_members_v1")
  end

  json_api do
    type "access_list_members"

    includes([:access_list])

    derive_filter?(true)
    derive_sort?(true)

    routes do
      base("/access_list_members")
      get(:read)
      index :read
      post(:create)
      patch(:update_role)
      delete(:destroy)
    end
  end

  code_interface do
    define(:create, action: :create)
    define(:update_role, action: :update_role)
    define(:block, action: :block)
    define(:unblock, action: :unblock)
    define(:read_by_access_list, action: :read_by_access_list)
    define(:destroy, action: :destroy)

    define(:by_id,
      get_by: [:id],
      action: :read
    )
  end

  actions do
    default_accept [
      :access_list_id,
      :name,
      :eve_character_id,
      :eve_corporation_id,
      :eve_alliance_id,
      :role
    ]

    defaults [:create, :update, :destroy]

    read :read do
      primary?(true)

      # Filter to only show members of ACLs owned by the authenticated user
      prepare fn query, context ->
        # Context structure depends on how it's called - check all possible locations
        actor =
          case context do
            %{actor: actor} when not is_nil(actor) ->
              actor

            %{private: %{actor: actor}} when not is_nil(actor) ->
              actor

            _ ->
              nil
          end

        case WandererApp.Api.ActorHelpers.get_character_ids(actor) do
          {:ok, character_ids} ->
            Ash.Query.filter(query, expr(access_list.owner_id in ^character_ids))

          {:error, _} ->
            query
        end
      end

      pagination offset?: true,
                 default_limit: 100,
                 max_page_size: 500,
                 countable: true,
                 required?: false
    end

    read :read_by_access_list do
      argument(:access_list_id, :string, allow_nil?: false)
      filter(expr(access_list_id == ^arg(:access_list_id)))
    end

    update :update_role do
      accept [:role]
      require_atomic? false
    end

    update :block do
      accept([])

      change(set_attribute(:blocked, true))
    end

    update :unblock do
      accept([])

      change(set_attribute(:blocked, false))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end

    attribute :eve_character_id, :string do
      allow_nil? true
    end

    attribute :eve_corporation_id, :string do
      allow_nil? true
    end

    attribute :eve_alliance_id, :string do
      allow_nil? true
    end

    attribute :role, :atom do
      default "viewer"

      constraints(
        one_of: [
          :admin,
          :manager,
          :member,
          :viewer,
          :blocked
        ]
      )

      allow_nil?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :access_list, WandererApp.Api.AccessList do
      attribute_writable? true
      public? true
    end
  end

  postgres do
    references do
      reference :access_list, on_delete: :delete
    end
  end

  identities do
    identity :uniq_acl_character_id, [:access_list_id, :eve_character_id] do
      pre_check?(true)
    end

    identity :uniq_acl_corporation_id, [:access_list_id, :eve_corporation_id] do
      pre_check?(true)
    end

    identity :uniq_acl_alliance_id, [:access_list_id, :eve_alliance_id] do
      pre_check?(true)
    end
  end
end
