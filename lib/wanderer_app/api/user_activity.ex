defmodule WandererApp.Api.UserActivity do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  require Ash.Expr

  @ash_pagify_options %{
    default_limit: 15,
    scopes: %{
      role: []
    }
  }
  def ash_pagify_options, do: @ash_pagify_options

  postgres do
    repo(WandererApp.Repo)
    table("user_activity_v1")

    custom_indexes do
      index [:entity_id, :event_type, :inserted_at], unique: true
    end
  end

  json_api do
    type "user_activities"

    includes([:character, :user])

    derive_filter?(true)
    derive_sort?(true)

    primary_key do
      keys([:id])
    end

    routes do
      base("/user_activities")
      get(:read)
      index :read
    end
  end

  code_interface do
    define(:read, action: :read)
    define(:new, action: :new)
  end

  actions do
    default_accept [
      :entity_id,
      :entity_type,
      :event_type,
      :event_data,
      :user_id
    ]

    read :read do
      primary?(true)

      pagination offset?: true,
                 default_limit: @ash_pagify_options.default_limit,
                 countable: true,
                 required?: false

      prepare WandererApp.Api.Preparations.LoadCharacter
    end

    create :new do
      accept [:entity_id, :entity_type, :event_type, :event_data]
      primary?(true)

      argument :user_id, :uuid, allow_nil?: true
      argument :character_id, :uuid, allow_nil?: true

      change manage_relationship(:user_id, :user, on_lookup: :relate, on_no_match: nil)
      change manage_relationship(:character_id, :character, on_lookup: :relate, on_no_match: nil)
    end

    destroy :archive do
      soft? false
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :entity_id, :string do
      allow_nil? false
    end

    attribute :entity_type, :atom do
      default "map"

      constraints(
        one_of: [
          :map,
          :access_list,
          :security_event
        ]
      )

      allow_nil?(false)
    end

    attribute :event_type, :atom do
      default "custom"

      constraints(
        one_of: [
          :custom,
          :hub_added,
          :hub_removed,
          :system_added,
          :systems_removed,
          :system_updated,
          :character_added,
          :character_removed,
          :character_updated,
          :map_added,
          :map_removed,
          :map_updated,
          :map_acl_added,
          :map_acl_removed,
          :map_acl_updated,
          :map_acl_member_added,
          :map_acl_member_removed,
          :map_acl_member_updated,
          :map_connection_added,
          :map_connection_updated,
          :map_connection_removed,
          :map_rally_added,
          :map_rally_cancelled,
          :signatures_added,
          :signatures_removed,
          # Security audit events
          :auth_success,
          :auth_failure,
          :permission_denied,
          :privilege_escalation,
          :data_access,
          :admin_action,
          :config_change,
          :bulk_operation,
          :security_alert,
          # Subscription events
          :subscription_created,
          :subscription_updated,
          :subscription_deleted,
          :subscription_unknown
        ]
      )

      allow_nil?(false)
    end

    attribute :event_data, :string

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :character, WandererApp.Api.Character do
      allow_nil? true
      attribute_writable? true
      public? true
    end

    belongs_to :user, WandererApp.Api.User do
      allow_nil? true
      attribute_writable? true
      public? true
    end
  end
end
