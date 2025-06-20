defmodule WandererAppWeb.Schemas.MapSchemas do
  @moduledoc """
  OpenAPI schema definitions for map-related resources.

  This module contains schema definitions for map systems, connections,
  signatures, and other map-specific data structures.
  """

  alias OpenApiSpex.Schema

  @doc """
  Map system schema for API responses.
  """
  def map_system_schema do
    %Schema{
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Map system UUID"},
        map_id: %Schema{type: :string, description: "Map UUID"},
        solar_system_id: %Schema{type: :integer, description: "EVE solar system ID"},
        solar_system_name: %Schema{type: :string, description: "EVE solar system name"},
        region_name: %Schema{type: :string, description: "EVE region name"},
        custom_name: %Schema{
          type: :string,
          nullable: true,
          description: "Custom name for the system"
        },
        position_x: %Schema{type: :number, description: "X coordinate"},
        position_y: %Schema{type: :number, description: "Y coordinate"},
        status: %Schema{
          type: :integer,
          enum: [0, 1, 2, 3, 4, 5, 6, 7, 8],
          description:
            "System status (0: unknown, 1: friendly, 2: warning, 3: targetPrimary, 4: targetSecondary, 5: dangerousPrimary, 6: dangerousSecondary, 7: lookingFor, 8: home)"
        },
        visible: %Schema{type: :boolean, description: "Visibility flag"},
        description: %Schema{type: :string, nullable: true, description: "Custom description"},
        tag: %Schema{type: :string, nullable: true, description: "Custom tag"},
        locked: %Schema{type: :boolean, description: "Lock flag"},
        temporary_name: %Schema{type: :string, nullable: true, description: "Temporary name"},
        labels: %Schema{
          type: :array,
          items: %Schema{type: :string},
          description: "List of labels"
        },
        inserted_at: %Schema{type: :string, format: :date_time, description: "Creation timestamp"},
        updated_at: %Schema{
          type: :string,
          format: :date_time,
          description: "Last update timestamp"
        }
      },
      required: ~w(id map_id solar_system_id)a
    }
  end

  @doc """
  Map connection schema for API responses.
  """
  def map_connection_schema do
    %Schema{
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Connection UUID"},
        map_id: %Schema{type: :string, description: "Map UUID"},
        solar_system_source: %Schema{type: :integer, description: "Source system ID"},
        solar_system_target: %Schema{type: :integer, description: "Target system ID"},
        type: %Schema{type: :integer, description: "Connection type (0: wormhole, 1: stargate)"},
        mass_status: %Schema{type: :integer, nullable: true, description: "Mass status (0-3)"},
        time_status: %Schema{type: :integer, nullable: true, description: "Time status (0-3)"},
        ship_size_type: %Schema{
          type: :integer,
          nullable: true,
          description: "Ship size limit (0-3)"
        },
        locked: %Schema{type: :boolean, description: "Locked flag"},
        custom_info: %Schema{type: :string, nullable: true, description: "Optional metadata"},
        wormhole_type: %Schema{type: :string, nullable: true, description: "Wormhole code"},
        inserted_at: %Schema{type: :string, format: :date_time, description: "Creation timestamp"},
        updated_at: %Schema{
          type: :string,
          format: :date_time,
          description: "Last update timestamp"
        }
      },
      required: ~w(id map_id solar_system_source solar_system_target)a
    }
  end

  @doc """
  Map signature schema for API responses.
  """
  def map_signature_schema do
    %Schema{
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Signature UUID"},
        system_id: %Schema{type: :string, description: "System UUID"},
        eve_id: %Schema{type: :string, description: "EVE signature ID"},
        name: %Schema{type: :string, nullable: true, description: "Signature name"},
        description: %Schema{type: :string, nullable: true, description: "Description"},
        group: %Schema{
          type: :string,
          description: "Signature group",
          enum: ["", "Cosmic Anomaly", "Cosmic Signature", "Deployment", "Wormhole"]
        },
        type: %Schema{type: :string, nullable: true, description: "Signature type"},
        inserted_at: %Schema{type: :string, format: :date_time},
        updated_at: %Schema{type: :string, format: :date_time}
      },
      required: ~w(id system_id eve_id)a
    }
  end

  @doc """
  Map structure timer schema.
  """
  def structure_timer_schema do
    %Schema{
      type: :object,
      properties: %{
        system_id: %Schema{type: :string},
        solar_system_name: %Schema{type: :string},
        solar_system_id: %Schema{type: :integer},
        structure_type_id: %Schema{type: :integer},
        structure_type: %Schema{type: :string},
        character_eve_id: %Schema{type: :string},
        name: %Schema{type: :string},
        notes: %Schema{type: :string},
        owner_name: %Schema{type: :string},
        owner_ticker: %Schema{type: :string},
        owner_id: %Schema{type: :string},
        status: %Schema{type: :string},
        end_time: %Schema{type: :string, format: :date_time}
      },
      required: ["system_id", "solar_system_id", "name", "status"]
    }
  end

  @doc """
  Kill detail schema for system kills data.
  """
  def kill_detail_schema do
    %Schema{
      type: :object,
      description: "Kill detail object",
      properties: %{
        kill_id: %Schema{type: :integer, description: "Unique identifier for the kill"},
        kill_time: %Schema{
          type: :string,
          format: :date_time,
          description: "Time when the kill occurred"
        },
        victim_id: %Schema{type: :integer, description: "ID of the victim character"},
        victim_name: %Schema{type: :string, description: "Name of the victim character"},
        ship_type_id: %Schema{
          type: :integer,
          description: "Type ID of the destroyed ship"
        },
        ship_name: %Schema{type: :string, description: "Name of the destroyed ship"}
      }
    }
  end

  @doc """
  System kills schema containing kill details for a solar system.
  """
  def system_kills_schema do
    %Schema{
      type: :object,
      properties: %{
        solar_system_id: %Schema{type: :integer},
        kills: %Schema{
          type: :array,
          items: kill_detail_schema()
        }
      },
      required: ["solar_system_id", "kills"]
    }
  end

  @doc """
  Character tracking schema for map character settings.
  """
  def character_tracking_schema do
    %Schema{
      type: :object,
      properties: %{
        id: %Schema{type: :string},
        map_id: %Schema{type: :string},
        character_id: %Schema{type: :string},
        tracked: %Schema{type: :boolean},
        followed: %Schema{type: :boolean, nullable: true},
        inserted_at: %Schema{type: :string, format: :date_time},
        updated_at: %Schema{type: :string, format: :date_time},
        character: WandererAppWeb.Schemas.ApiSchemas.character_schema()
      },
      required: ["id", "map_id", "character_id", "tracked"]
    }
  end

  @doc """
  User characters response schema with main character indication.
  """
  def user_characters_schema do
    %Schema{
      type: :object,
      properties: %{
        user_id: %Schema{type: :string, description: "User UUID"},
        characters: %Schema{
          type: :array,
          items: WandererAppWeb.Schemas.ApiSchemas.character_schema(),
          description: "List of characters belonging to a user"
        },
        main_character_eve_id: %Schema{
          type: :string,
          nullable: true,
          description: "EVE ID of the user's main character"
        }
      },
      required: ["characters"]
    }
  end

  @doc """
  Audit log entry schema.
  """
  def audit_log_schema do
    %Schema{
      type: :object,
      properties: %{
        id: %Schema{type: :string},
        action: %Schema{type: :string},
        character_id: %Schema{type: :string},
        character_name: %Schema{type: :string},
        map_id: %Schema{type: :string},
        solar_system_id: %Schema{type: :integer, nullable: true},
        solar_system_name: %Schema{type: :string, nullable: true},
        old_solar_system_id: %Schema{type: :integer, nullable: true},
        old_solar_system_name: %Schema{type: :string, nullable: true},
        ship_type_id: %Schema{type: :integer, nullable: true},
        ship_name: %Schema{type: :string, nullable: true},
        inserted_at: %Schema{type: :string, format: :date_time}
      },
      required: ["id", "action", "character_id", "map_id", "inserted_at"]
    }
  end
end
