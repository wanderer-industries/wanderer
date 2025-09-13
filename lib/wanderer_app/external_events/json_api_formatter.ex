defmodule WandererApp.ExternalEvents.JsonApiFormatter do
  @moduledoc """
  JSON:API event formatter for real-time events.

  Converts internal event structures to JSON:API compliant format
  for consistency with the API specification.
  """

  alias WandererApp.ExternalEvents.Event

  @doc """
  Formats an event into JSON:API structure.

  Converts internal events to JSON:API format:
  - `data`: Resource object with type, id, attributes, relationships
  - `meta`: Event metadata (type, timestamp, etc.)
  - `links`: Related resource links where applicable
  """
  @spec format_event(Event.t()) :: map()
  def format_event(%Event{} = event) do
    %{
      "data" => format_resource_data(event),
      "meta" => format_event_meta(event),
      "links" => format_event_links(event)
    }
  end

  @doc """
  Formats a legacy event (map format) into JSON:API structure.

  Handles events that are already in map format from existing system.
  """
  @spec format_legacy_event(map()) :: map()
  def format_legacy_event(event) when is_map(event) do
    %{
      "data" => format_legacy_resource_data(event),
      "meta" => format_legacy_event_meta(event),
      "links" => format_legacy_event_links(event)
    }
  end

  # Event-specific resource data formatting
  defp format_resource_data(%Event{type: :add_system, payload: payload} = event) do
    %{
      "type" => "map_systems",
      "id" => payload["system_id"] || payload[:system_id],
      "attributes" => %{
        "solar_system_id" => payload["solar_system_id"] || payload[:solar_system_id],
        "name" => payload["name"] || payload[:name],
        "locked" => payload["locked"] || payload[:locked],
        "x" => payload["x"] || payload[:x],
        "y" => payload["y"] || payload[:y],
        "created_at" => event.timestamp
      },
      "relationships" => %{
        "map" => %{
          "data" => %{"type" => "maps", "id" => event.map_id}
        }
      }
    }
  end

  defp format_resource_data(%Event{type: :deleted_system, payload: payload} = event) do
    %{
      "type" => "map_systems",
      "id" => payload["system_id"] || payload[:system_id],
      "meta" => %{
        "deleted" => true,
        "deleted_at" => event.timestamp
      },
      "relationships" => %{
        "map" => %{
          "data" => %{"type" => "maps", "id" => event.map_id}
        }
      }
    }
  end

  defp format_resource_data(%Event{type: :system_renamed, payload: payload} = event) do
    %{
      "type" => "map_systems",
      "id" => payload["system_id"] || payload[:system_id],
      "attributes" => %{
        "name" => payload["name"] || payload[:name],
        "updated_at" => event.timestamp
      },
      "relationships" => %{
        "map" => %{
          "data" => %{"type" => "maps", "id" => event.map_id}
        }
      }
    }
  end

  defp format_resource_data(%Event{type: :system_metadata_changed, payload: payload} = event) do
    %{
      "type" => "map_systems",
      "id" => payload["system_id"] || payload[:system_id],
      "attributes" => %{
        "locked" => payload["locked"] || payload[:locked],
        "x" => payload["x"] || payload[:x],
        "y" => payload["y"] || payload[:y],
        "updated_at" => event.timestamp
      },
      "relationships" => %{
        "map" => %{
          "data" => %{"type" => "maps", "id" => event.map_id}
        }
      }
    }
  end

  defp format_resource_data(%Event{type: :signature_added, payload: payload} = event) do
    %{
      "type" => "map_system_signatures",
      "id" => payload["signature_id"] || payload[:signature_id],
      "attributes" => %{
        "signature_id" => payload["signature_identifier"] || payload[:signature_identifier],
        "signature_type" => payload["signature_type"] || payload[:signature_type],
        "name" => payload["name"] || payload[:name],
        "created_at" => event.timestamp
      },
      "relationships" => %{
        "system" => %{
          "data" => %{
            "type" => "map_systems",
            "id" => payload["system_id"] || payload[:system_id]
          }
        },
        "map" => %{
          "data" => %{"type" => "maps", "id" => event.map_id}
        }
      }
    }
  end

  defp format_resource_data(%Event{type: :signature_removed, payload: payload} = event) do
    %{
      "type" => "map_system_signatures",
      "id" => payload["signature_id"] || payload[:signature_id],
      "meta" => %{
        "deleted" => true,
        "deleted_at" => event.timestamp
      },
      "relationships" => %{
        "system" => %{
          "data" => %{
            "type" => "map_systems",
            "id" => payload["system_id"] || payload[:system_id]
          }
        },
        "map" => %{
          "data" => %{"type" => "maps", "id" => event.map_id}
        }
      }
    }
  end

  defp format_resource_data(%Event{type: :connection_added, payload: payload} = event) do
    %{
      "type" => "map_connections",
      "id" => payload["connection_id"] || payload[:connection_id],
      "attributes" => %{
        "type" => payload["type"] || payload[:type],
        "time_status" => payload["time_status"] || payload[:time_status],
        "mass_status" => payload["mass_status"] || payload[:mass_status],
        "ship_size_type" => payload["ship_size_type"] || payload[:ship_size_type],
        "created_at" => event.timestamp
      },
      "relationships" => %{
        "solar_system_source" => %{
          "data" => %{
            "type" => "map_systems",
            "id" => payload["solar_system_source"] || payload[:solar_system_source]
          }
        },
        "solar_system_target" => %{
          "data" => %{
            "type" => "map_systems",
            "id" => payload["solar_system_target"] || payload[:solar_system_target]
          }
        },
        "map" => %{
          "data" => %{"type" => "maps", "id" => event.map_id}
        }
      }
    }
  end

  defp format_resource_data(%Event{type: :connection_removed, payload: payload} = event) do
    %{
      "type" => "map_connections",
      "id" => payload["connection_id"] || payload[:connection_id],
      "meta" => %{
        "deleted" => true,
        "deleted_at" => event.timestamp
      },
      "relationships" => %{
        "map" => %{
          "data" => %{"type" => "maps", "id" => event.map_id}
        }
      }
    }
  end

  defp format_resource_data(%Event{type: :connection_updated, payload: payload} = event) do
    %{
      "type" => "map_connections",
      "id" => payload["connection_id"] || payload[:connection_id],
      "attributes" => %{
        "type" => payload["type"] || payload[:type],
        "time_status" => payload["time_status"] || payload[:time_status],
        "mass_status" => payload["mass_status"] || payload[:mass_status],
        "ship_size_type" => payload["ship_size_type"] || payload[:ship_size_type],
        "updated_at" => event.timestamp
      },
      "relationships" => %{
        "map" => %{
          "data" => %{"type" => "maps", "id" => event.map_id}
        }
      }
    }
  end

  defp format_resource_data(%Event{type: :character_added, payload: payload} = event) do
    %{
      "type" => "characters",
      "id" => payload["character_id"] || payload[:character_id],
      "attributes" => %{
        "eve_id" => payload["eve_id"] || payload[:eve_id],
        "name" => payload["name"] || payload[:name],
        "corporation_name" => payload["corporation_name"] || payload[:corporation_name],
        "corporation_ticker" => payload["corporation_ticker"] || payload[:corporation_ticker],
        "added_at" => event.timestamp
      },
      "relationships" => %{
        "system" => %{
          "data" => %{
            "type" => "map_systems",
            "id" => payload["system_id"] || payload[:system_id]
          }
        },
        "map" => %{
          "data" => %{"type" => "maps", "id" => event.map_id}
        }
      }
    }
  end

  defp format_resource_data(%Event{type: :character_removed, payload: payload} = event) do
    %{
      "type" => "characters",
      "id" => payload["character_id"] || payload[:character_id],
      "meta" => %{
        "removed_from_system" => true,
        "removed_at" => event.timestamp
      },
      "relationships" => %{
        "system" => %{
          "data" => %{
            "type" => "map_systems",
            "id" => payload["system_id"] || payload[:system_id]
          }
        },
        "map" => %{
          "data" => %{"type" => "maps", "id" => event.map_id}
        }
      }
    }
  end

  defp format_resource_data(%Event{type: :character_updated, payload: payload} = event) do
    %{
      "type" => "characters",
      "id" => payload["character_id"] || payload[:character_id],
      "attributes" => %{
        "ship_type_id" => payload["ship_type_id"] || payload[:ship_type_id],
        "ship_name" => payload["ship_name"] || payload[:ship_name],
        "updated_at" => event.timestamp
      },
      "relationships" => %{
        "system" => %{
          "data" => %{
            "type" => "map_systems",
            "id" => payload["system_id"] || payload[:system_id]
          }
        },
        "map" => %{
          "data" => %{"type" => "maps", "id" => event.map_id}
        }
      }
    }
  end

  defp format_resource_data(%Event{type: :acl_member_added, payload: payload} = event) do
    %{
      "type" => "access_list_members",
      "id" => payload["member_id"] || payload[:member_id],
      "attributes" => %{
        "character_eve_id" => payload["character_eve_id"] || payload[:character_eve_id],
        "character_name" => payload["character_name"] || payload[:character_name],
        "role" => payload["role"] || payload[:role],
        "added_at" => event.timestamp
      },
      "relationships" => %{
        "access_list" => %{
          "data" => %{
            "type" => "access_lists",
            "id" => payload["access_list_id"] || payload[:access_list_id]
          }
        },
        "map" => %{
          "data" => %{"type" => "maps", "id" => event.map_id}
        }
      }
    }
  end

  defp format_resource_data(%Event{type: :acl_member_removed, payload: payload} = event) do
    %{
      "type" => "access_list_members",
      "id" => payload["member_id"] || payload[:member_id],
      "meta" => %{
        "deleted" => true,
        "deleted_at" => event.timestamp
      },
      "relationships" => %{
        "access_list" => %{
          "data" => %{
            "type" => "access_lists",
            "id" => payload["access_list_id"] || payload[:access_list_id]
          }
        },
        "map" => %{
          "data" => %{"type" => "maps", "id" => event.map_id}
        }
      }
    }
  end

  defp format_resource_data(%Event{type: :acl_member_updated, payload: payload} = event) do
    %{
      "type" => "access_list_members",
      "id" => payload["member_id"] || payload[:member_id],
      "attributes" => %{
        "role" => payload["role"] || payload[:role],
        "updated_at" => event.timestamp
      },
      "relationships" => %{
        "access_list" => %{
          "data" => %{
            "type" => "access_lists",
            "id" => payload["access_list_id"] || payload[:access_list_id]
          }
        },
        "map" => %{
          "data" => %{"type" => "maps", "id" => event.map_id}
        }
      }
    }
  end

  defp format_resource_data(%Event{type: :map_kill, payload: payload} = event) do
    %{
      "type" => "kills",
      "id" => payload["killmail_id"] || payload[:killmail_id],
      "attributes" => %{
        "killmail_id" => payload["killmail_id"] || payload[:killmail_id],
        "victim_character_name" =>
          payload["victim_character_name"] || payload[:victim_character_name],
        "victim_ship_type" => payload["victim_ship_type"] || payload[:victim_ship_type],
        "occurred_at" => payload["killmail_time"] || payload[:killmail_time] || event.timestamp
      },
      "relationships" => %{
        "system" => %{
          "data" => %{
            "type" => "map_systems",
            "id" => payload["system_id"] || payload[:system_id]
          }
        },
        "map" => %{
          "data" => %{"type" => "maps", "id" => event.map_id}
        }
      }
    }
  end

  defp format_resource_data(%Event{type: :rally_point_added, payload: payload} = event) do
    %{
      "type" => "rally_points",
      "id" => payload["rally_point_id"] || payload[:rally_point_id],
      "attributes" => %{
        "name" => payload["name"] || payload[:name],
        "description" => payload["description"] || payload[:description],
        "created_at" => event.timestamp
      },
      "relationships" => %{
        "system" => %{
          "data" => %{
            "type" => "map_systems",
            "id" => payload["system_id"] || payload[:system_id]
          }
        },
        "map" => %{
          "data" => %{"type" => "maps", "id" => event.map_id}
        }
      }
    }
  end

  defp format_resource_data(%Event{type: :rally_point_removed, payload: payload} = event) do
    %{
      "type" => "rally_points",
      "id" => payload["rally_point_id"] || payload[:rally_point_id],
      "meta" => %{
        "deleted" => true,
        "deleted_at" => event.timestamp
      },
      "relationships" => %{
        "map" => %{
          "data" => %{"type" => "maps", "id" => event.map_id}
        }
      }
    }
  end

  # Generic fallback for unknown event types
  defp format_resource_data(%Event{payload: payload} = event) do
    %{
      "type" => "events",
      "id" => event.id,
      "attributes" => payload,
      "relationships" => %{
        "map" => %{
          "data" => %{"type" => "maps", "id" => event.map_id}
        }
      }
    }
  end

  # Legacy event formatting (for events already in map format)
  defp format_legacy_resource_data(event) do
    event_type = event["type"] || "unknown"
    payload = event["payload"] || event
    map_id = event["map_id"]

    case event_type do
      "connected" ->
        %{
          "type" => "connection_status",
          "id" => event["id"] || Ecto.ULID.generate(),
          "attributes" => %{
            "status" => "connected",
            "server_time" => payload["server_time"],
            "connected_at" => payload["server_time"]
          },
          "relationships" => %{
            "map" => %{
              "data" => %{"type" => "maps", "id" => map_id}
            }
          }
        }

      _ ->
        # Use existing payload structure but wrap it in JSON:API format
        %{
          "type" => "events",
          "id" => event["id"] || Ecto.ULID.generate(),
          "attributes" => payload,
          "relationships" => %{
            "map" => %{
              "data" => %{"type" => "maps", "id" => map_id}
            }
          }
        }
    end
  end

  # Event metadata formatting
  defp format_event_meta(%Event{} = event) do
    %{
      "event_type" => event.type,
      "event_action" => determine_action(event.type),
      "timestamp" => DateTime.to_iso8601(event.timestamp),
      "map_id" => event.map_id,
      "event_id" => event.id
    }
  end

  defp format_legacy_event_meta(event) do
    %{
      "event_type" => event["type"],
      "event_action" => determine_legacy_action(event["type"]),
      "timestamp" => event["timestamp"] || DateTime.to_iso8601(DateTime.utc_now()),
      "map_id" => event["map_id"],
      "event_id" => event["id"]
    }
  end

  # Event links formatting
  defp format_event_links(%Event{map_id: map_id}) do
    %{
      "related" => "/api/v1/maps/#{map_id}",
      "self" => "/api/v1/maps/#{map_id}/events/stream"
    }
  end

  defp format_legacy_event_links(event) do
    map_id = event["map_id"]

    %{
      "related" => "/api/v1/maps/#{map_id}",
      "self" => "/api/v1/maps/#{map_id}/events/stream"
    }
  end

  # Helper functions
  defp determine_action(event_type) do
    case event_type do
      type
      when type in [
             :add_system,
             :signature_added,
             :connection_added,
             :character_added,
             :acl_member_added,
             :rally_point_added
           ] ->
        "created"

      type
      when type in [
             :deleted_system,
             :signature_removed,
             :connection_removed,
             :character_removed,
             :acl_member_removed,
             :rally_point_removed
           ] ->
        "deleted"

      type
      when type in [
             :system_renamed,
             :system_metadata_changed,
             :connection_updated,
             :character_updated,
             :acl_member_updated
           ] ->
        "updated"

      :signatures_updated ->
        "bulk_updated"

      :map_kill ->
        "created"

      _ ->
        "unknown"
    end
  end

  defp determine_legacy_action(event_type) do
    case event_type do
      "connected" ->
        "connected"

      _ ->
        try do
          determine_action(String.to_existing_atom(event_type))
        rescue
          ArgumentError -> "unknown"
        end
    end
  end
end
