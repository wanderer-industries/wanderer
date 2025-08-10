defmodule WandererApp.Api.MapDefaultSettings do
  @moduledoc """
  Resource for storing default map settings that admins can configure.
  These settings will be applied to new users when they first access the map.
  """

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    repo(WandererApp.Repo)
    table("map_default_settings")
  end

  json_api do
    type "map_default_settings"

    includes([
      :map,
      :created_by,
      :updated_by
    ])

    routes do
      base("/map_default_settings")

      get(:read)
      index(:read)
      post(:create)
      patch(:update)
      delete(:destroy)
    end
  end

  code_interface do
    define(:create, action: :create)
    define(:update, action: :update)
    define(:destroy, action: :destroy)
    define(:get_by_map_id, action: :get_by_map_id)
  end

  actions do
    default_accept [
      :map_id,
      :settings
    ]

    defaults [:read, :destroy]

    create :create do
      primary?(true)
      accept [:map_id, :settings]

      change relate_actor(:created_by)
      change relate_actor(:updated_by)

      change fn changeset, _context ->
        changeset
        |> validate_json_settings()
      end
    end

    update :update do
      primary?(true)
      accept [:settings]

      # Required for managing relationships
      require_atomic? false

      change relate_actor(:updated_by)

      change fn changeset, _context ->
        changeset
        |> validate_json_settings()
      end
    end

    read :get_by_map_id do
      argument :map_id, :uuid, allow_nil?: false

      filter expr(map_id == ^arg(:map_id))

      prepare fn query, _context ->
        Ash.Query.limit(query, 1)
      end
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :settings, :string do
      allow_nil? false
      constraints min_length: 2
      description "JSON string containing the default map settings"
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :map, WandererApp.Api.Map do
      primary_key? false
      allow_nil? false
      public? true
    end

    belongs_to :created_by, WandererApp.Api.Character do
      allow_nil? true
      public? true
    end

    belongs_to :updated_by, WandererApp.Api.Character do
      allow_nil? true
      public? true
    end
  end

  identities do
    identity :unique_map_settings, [:map_id]
  end

  defp validate_json_settings(changeset) do
    case Ash.Changeset.get_attribute(changeset, :settings) do
      nil ->
        changeset

      settings ->
        case Jason.decode(settings) do
          {:ok, _} ->
            changeset

          {:error, _} ->
            Ash.Changeset.add_error(
              changeset,
              field: :settings,
              message: "must be valid JSON"
            )
        end
    end
  end
end
