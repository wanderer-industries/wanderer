defmodule WandererApp.Api.CorpWalletTransaction do
  @moduledoc false

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshCloak]

  postgres do
    repo(WandererApp.Repo)
    table("corp_wallet_transactions_v1")
  end

  code_interface do
    define(:latest, action: :read)
    define(:new, action: :new)

    define(:latest_by_characters,
      action: :latest_by_characters
    )
  end

  actions do
    default_accept [
      :eve_transaction_id,
      :amount_encoded,
      :balance_encoded,
      :first_party_id,
      :second_party_id,
      :date,
      :description,
      :reason_encoded,
      :ref_type
    ]

    defaults [:create, :read, :update, :destroy]

    create :new do
      accept [
        :eve_transaction_id,
        :amount_encoded,
        :balance_encoded,
        :first_party_id,
        :second_party_id,
        :date,
        :description,
        :reason_encoded,
        :ref_type
      ]

      primary?(true)
      upsert? true
      upsert_identity :eve_transaction_id

      upsert_fields [
        :amount_encoded,
        :balance_encoded,
        :first_party_id,
        :second_party_id,
        :date,
        :description,
        :reason_encoded,
        :ref_type
      ]
    end

    read :latest_by_characters do
      argument(:eve_character_ids, {:array, :integer}, allow_nil?: false)
      filter(expr(first_party_id in ^arg(:eve_character_ids)))
    end
  end

  cloak do
    vault(WandererApp.Vault)

    attributes([
      :amount_encoded,
      :balance_encoded,
      :reason_encoded
    ])

    decrypt_by_default([
      :amount_encoded,
      :balance_encoded,
      :reason_encoded
    ])
  end

  attributes do
    uuid_primary_key :id

    attribute :eve_transaction_id, :integer do
      allow_nil? false
    end

    attribute :amount_encoded, :float do
      allow_nil? false
    end

    attribute :balance_encoded, :float do
      allow_nil? false
    end

    attribute :first_party_id, :integer do
      allow_nil? false
    end

    attribute :second_party_id, :integer do
      allow_nil? false
    end

    attribute :date, :utc_datetime do
      allow_nil? true
    end

    attribute :description, :string
    attribute :reason_encoded, :string
    attribute :ref_type, :string

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity :eve_transaction_id, [:eve_transaction_id] do
      pre_check?(true)
    end
  end
end
