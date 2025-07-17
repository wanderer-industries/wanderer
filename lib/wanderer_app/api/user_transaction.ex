defmodule WandererApp.Api.UserTransaction do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    repo(WandererApp.Repo)
    table("user_transaction_v1")
  end

  code_interface do
    define(:new, action: :new)
  end

  actions do
    default_accept [
      :journal_ref_id,
      :user_id,
      :date,
      :amount,
      :corporation_id
    ]

    defaults [:read]

    create :new do
      accept [:journal_ref_id, :user_id, :date, :amount, :corporation_id]
      primary?(true)

      argument :user_id, :uuid, allow_nil?: false

      change manage_relationship(:user_id, :user, on_lookup: :relate, on_no_match: nil)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :journal_ref_id, :integer do
      allow_nil? false
    end

    attribute :corporation_id, :integer do
      allow_nil? false
    end

    attribute :amount, :float do
      allow_nil? false
    end

    attribute :date, :utc_datetime do
      allow_nil? true
    end

    attribute :reason, :string

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :user, WandererApp.Api.User do
      primary_key? true
      allow_nil? false
      attribute_writable? true
    end
  end
end
