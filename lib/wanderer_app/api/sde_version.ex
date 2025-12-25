defmodule WandererApp.Api.SdeVersion do
  @moduledoc """
  Tracks SDE (Static Data Export) version history.

  Each record represents an SDE update that was applied to the database,
  including version information, source, and metadata from the update.

  This allows administrators to:
  - See which SDE version is currently active
  - View update history
  - Track when updates were applied
  """

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    primary_read_warning?: false

  postgres do
    repo(WandererApp.Repo)
    table("sde_versions_v1")

    custom_indexes do
      index [:applied_at]
    end
  end

  code_interface do
    define(:read, action: :read)
    define(:get_latest, action: :get_latest)
    define(:record_update, action: :record_update)
  end

  actions do
    default_accept [
      :sde_version,
      :source,
      :release_date,
      :metadata
    ]

    read :read do
      primary?(true)

      pagination offset?: true,
                 default_limit: 10,
                 countable: true,
                 required?: false
    end

    read :get_latest do
      get? true

      prepare fn query, _context ->
        query
        |> Ash.Query.sort(applied_at: :desc)
        |> Ash.Query.limit(1)
      end
    end

    create :record_update do
      accept [:sde_version, :source, :release_date, :metadata]
      primary?(true)

      change set_attribute(:applied_at, &DateTime.utc_now/0)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :sde_version, :string do
      allow_nil? false
      public? true
      description "The SDE version number from CCP (e.g., '3142455')"
    end

    attribute :source, :atom do
      allow_nil? false
      public? true
      description "The source from which the SDE was downloaded"

      constraints(
        one_of: [
          :wanderer_assets,
          :fuzzworks
        ]
      )
    end

    attribute :release_date, :utc_datetime do
      allow_nil? true
      public? true
      description "When CCP released this SDE version"
    end

    attribute :applied_at, :utc_datetime do
      allow_nil? false
      public? true
      description "When this SDE version was applied to the database"
    end

    attribute :metadata, :map do
      allow_nil? true
      public? true
      description "Additional metadata from the SDE source (generated_by, generated_at, etc.)"
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end
end
