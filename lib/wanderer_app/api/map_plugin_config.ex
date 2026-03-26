defmodule WandererApp.Api.MapPluginConfig do
  @moduledoc """
  Ash resource for storing per-map plugin configuration.

  Each map can have one config per plugin. The config field is encrypted at rest
  (via AshCloak) since it may contain sensitive data like Discord bot tokens.
  """

  use Ash.Resource,
    domain: WandererApp.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshCloak]

  postgres do
    repo(WandererApp.Repo)
    table("map_plugin_configs_v1")
  end

  cloak do
    vault(WandererApp.Vault)
    attributes([:config])
    decrypt_by_default([:config])
  end

  code_interface do
    define(:create, action: :create)
    define(:update, action: :update)
    define(:destroy, action: :destroy)

    define(:by_id,
      get_by: [:id],
      action: :read
    )

    define(:by_map_and_plugin, action: :by_map_and_plugin, args: [:map_id, :plugin_name])
    define(:enabled_by_plugin, action: :enabled_by_plugin, args: [:plugin_name])
    define(:by_map, action: :by_map, args: [:map_id])
  end

  actions do
    default_accept [
      :map_id,
      :plugin_name,
      :enabled,
      :config
    ]

    defaults [:read, :destroy]

    create :create do
      accept [
        :map_id,
        :plugin_name,
        :enabled,
        :config
      ]

      change fn changeset, _context ->
        plugin_name = Ash.Changeset.get_attribute(changeset, :plugin_name)

        if WandererApp.Plugins.PluginRegistry.plugin_exists?(plugin_name) do
          changeset
        else
          Ash.Changeset.add_error(changeset,
            field: :plugin_name,
            message: "unknown plugin: #{plugin_name}"
          )
        end
      end
    end

    update :update do
      accept [
        :enabled,
        :config
      ]

      require_atomic? false

      # Auto-increment config_version on every update
      change fn changeset, _context ->
        current_version = changeset.data.config_version
        Ash.Changeset.force_change_attribute(changeset, :config_version, current_version + 1)
      end
    end

    read :by_map_and_plugin do
      argument :map_id, :uuid, allow_nil?: false
      argument :plugin_name, :string, allow_nil?: false
      get? true
      filter expr(map_id == ^arg(:map_id) and plugin_name == ^arg(:plugin_name))
    end

    read :enabled_by_plugin do
      argument :plugin_name, :string, allow_nil?: false
      filter expr(plugin_name == ^arg(:plugin_name) and enabled == true)
    end

    read :by_map do
      argument :map_id, :uuid, allow_nil?: false
      filter expr(map_id == ^arg(:map_id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :map_id, :uuid do
      allow_nil? false
    end

    attribute :plugin_name, :string do
      allow_nil? false
    end

    attribute :enabled, :boolean do
      allow_nil? false
      default false
    end

    attribute :config, :string do
      allow_nil? true
      sensitive? true
    end

    attribute :config_version, :integer do
      allow_nil? false
      default 1
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :map, WandererApp.Api.Map do
      source_attribute :map_id
      destination_attribute :id
      attribute_writable? true
    end
  end

  identities do
    identity :unique_map_plugin, [:map_id, :plugin_name]
  end
end
