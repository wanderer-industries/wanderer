defmodule WandererApp.Api.MapPing do
  @moduledoc """
  Map pings resource for v1 API.

  Pings are notifications placed on map systems to alert other users
  about rally points, danger, or other important information.
  """

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  import WandererApp.CharacterHelpers
  alias WandererApp.Api.Changes.InjectMapFromActor
  alias WandererApp.Api.Preparations.FilterPingsByAccessibleMaps

  postgres do
    repo(WandererApp.Repo)
    table("map_pings_v1")
  end

  json_api do
    type "map_pings"

    includes([:map, :character, :system])

    default_fields([
      :type,
      :message,
      :expires_at,
      :acknowledged,
      :inserted_at
    ])

    derive_filter?(true)
    derive_sort?(true)

    routes do
      base("/map_pings")

      get(:read)
      index :read
      post(:create)
      patch(:acknowledge, route: "/:id/acknowledge")
      delete(:destroy)
    end
  end

  code_interface do
    define(:new, action: :new)
    define(:destroy, action: :destroy)

    define(:by_id,
      get_by: [:id],
      action: :read
    )

    define(:by_map,
      action: :by_map
    )

    define(:by_map_and_system,
      action: :by_map_and_system
    )

    define(:by_inserted_before, action: :by_inserted_before, args: [:inserted_before])
  end

  actions do
    default_accept [
      :type,
      :message
    ]

    read :read do
      primary? true

      # Security: Filter to only pings from the actor's accessible map(s)
      prepare WandererApp.Api.Preparations.FilterPingsByAccessibleMaps

      pagination offset?: true,
                 default_limit: 100,
                 max_page_size: 500,
                 countable: true,
                 required?: false
    end

    defaults [:update, :destroy]

    create :new do
      accept [
        # Note: map_id is auto-injected from authenticated token via InjectMapFromActor
        :system_id,
        :character_id,
        :type,
        :message,
        :expires_at
      ]

      primary?(true)

      argument :system_id, :uuid, allow_nil?: false
      argument :character_id, :uuid, allow_nil?: false

      # Auto-inject map_id from authenticated token
      change InjectMapFromActor
      change manage_relationship(:system_id, :system, on_lookup: :relate, on_no_match: nil)
      change manage_relationship(:character_id, :character, on_lookup: :relate, on_no_match: nil)
    end

    create :create do
      accept [
        # Note: map_id is auto-injected from authenticated token via InjectMapFromActor
        :system_id,
        :type,
        :message,
        :expires_at
      ]

      argument :system_id, :uuid, allow_nil?: false
      # Optional for tests
      argument :character_id, :uuid, allow_nil?: true

      # Auto-inject map_id from authenticated token
      change InjectMapFromActor
      change manage_relationship(:system_id, :system, on_lookup: :relate, on_no_match: nil)

      change fn changeset, _context ->
        # Get actor from changeset context (where Ash stores it)
        actor = get_in(changeset.context, [:private, :actor])

        # Try to get character_id from:
        # 1. Explicit argument
        # 2. ActorWithMap (use map owner's character)
        # 3. Actor's active character
        character_id =
          Ash.Changeset.get_argument(changeset, :character_id) ||
            case actor do
              %WandererApp.Api.ActorWithMap{map: %{owner_id: owner_id}}
              when not is_nil(owner_id) ->
                owner_id

              _ ->
                get_active_character_id(actor)
            end

        case character_id do
          nil ->
            Ash.Changeset.add_error(changeset,
              field: :character_id,
              message: "No active character found"
            )

          id ->
            changeset
            |> Ash.Changeset.force_change_attribute(:character_id, id)
            |> Ash.Changeset.manage_relationship(:character, %{id: id}, type: :append_and_remove)
        end
      end
    end

    update :acknowledge do
      accept []
      require_atomic? false

      change fn changeset, _context ->
        Ash.Changeset.force_change_attribute(changeset, :acknowledged, true)
      end
    end

    read :by_map do
      argument(:map_id, :string, allow_nil?: false)

      filter(expr(map_id == ^arg(:map_id)))
    end

    read :by_map_and_system do
      argument(:map_id, :string, allow_nil?: false)
      argument(:system_id, :string, allow_nil?: false)

      filter(expr(map_id == ^arg(:map_id) and system_id == ^arg(:system_id)))
    end

    read :by_inserted_before do
      argument(:inserted_before, :utc_datetime, allow_nil?: false)

      filter(expr(inserted_at <= ^arg(:inserted_before)))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :type, :atom do
      allow_nil? false
      constraints one_of: [:ping, :rally_point, :danger, :info, :help]
      default :ping
      description "Type of ping"
    end

    attribute :message, :string do
      allow_nil? true
      description "Optional message"
    end

    attribute :expires_at, :utc_datetime do
      allow_nil? true
      description "When ping expires"
    end

    attribute :acknowledged, :boolean do
      allow_nil? false
      default false
      description "Whether ping has been acknowledged"
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :map, WandererApp.Api.Map do
      attribute_writable? true
      public? true
    end

    belongs_to :system, WandererApp.Api.MapSystem do
      attribute_writable? true
      public? true
    end

    belongs_to :character, WandererApp.Api.Character do
      attribute_writable? true
      public? true
    end
  end

  postgres do
    references do
      reference :map, on_delete: :delete
      reference :system, on_delete: :delete
      reference :character, on_delete: :delete
    end
  end

  # get_active_character_id/1 is now imported from WandererApp.CharacterHelpers
end
