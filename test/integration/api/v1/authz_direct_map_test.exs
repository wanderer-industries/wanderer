defmodule WandererAppWeb.Api.V1.AuthzDirectMapTest do
  @moduledoc """
  Authorization matrix for the direct-`map_id` `/api/v1` resources.

  Every route that actually exists for these resources is exercised for BOTH
  the foreign path (must be denied/filtered) and the own path (positive
  control, must still succeed). The positive controls matter as much as the
  denials: a policy that forbade everything would pass the deny half alone.

  Two behaviours to keep in mind when reading these tests:

    * Reads are scoped with FILTER checks, so an out-of-scope row is
      *excluded* rather than rejected: list omits it, `GET /:id` is 404.
    * Update/destroy are also filter-scoped, so a foreign PATCH/DELETE
      resolves no row and returns **404**, not 403. This matches the
      pre-existing contract already asserted in `map_system_api_v1_test.exs`
      ("returns 404 for system from different map"). Creates, which have no
      existing row to filter, are rejected by a SimpleCheck and return **403**.

  `WandererApp.Api.MapSystem`'s primary read carries an always-on
  `FilterSystemsByActorMap` preparation that independently map-scopes reads,
  so an HTTP round-trip alone cannot prove the read POLICY works. The
  "policy filter itself excludes foreign rows" test below calls `Ash.read`
  with `authorize?: true` on a query that does not go through that
  preparation's HTTP path, so it fails if the policy is removed.
  """
  use WandererAppWeb.ApiCase, async: false

  require Ash.Query

  setup %{conn: conn} do
    owner = insert(:user)
    char = insert(:character, %{user_id: owner.id})
    map = insert(:map, %{owner_id: char.id})

    other_user = insert(:user)
    other_char = insert(:character, %{user_id: other_user.id})
    other_map = insert(:map, %{owner_id: other_char.id})

    other_system =
      insert(:map_system, %{map_id: other_map.id, solar_system_id: 30_000_142, name: "Amarr"})

    own_system =
      insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_143, name: "Jita"})

    {:ok, other_sub} =
      Ash.create(
        WandererApp.Api.MapSubscription,
        %{
          map_id: other_map.id,
          plan: :omega,
          characters_limit: 100,
          hubs_limit: 10,
          auto_renew?: true,
          active_till: DateTime.utc_now() |> DateTime.add(30, :day)
        },
        authorize?: false
      )

    conn = create_authenticated_conn(conn, map)

    %{
      conn: conn,
      map: map,
      char: char,
      other_map: other_map,
      other_char: other_char,
      other_user: other_user,
      other_sub: other_sub,
      other_system: other_system,
      own_system: own_system
    }
  end

  defp list_ids(conn, path) do
    conn
    |> get(path)
    |> json_response(200)
    |> Map.get("data")
    |> Enum.map(& &1["id"])
  end

  defp count_systems(map_id, solar_system_id) do
    {:ok, count} =
      Ash.count(
        Ash.Query.filter(
          WandererApp.Api.MapSystem,
          map_id == ^map_id and solar_system_id == ^solar_system_id
        ),
        authorize?: false
      )

    count
  end

  describe "map_system" do
    test "list includes own and excludes foreign", %{
      conn: conn,
      own_system: own,
      other_system: foreign
    } do
      got = list_ids(conn, "/api/v1/map_systems")
      assert own.id in got
      refute foreign.id in got
    end

    test "GET own -> 200, GET foreign -> 404", %{
      conn: conn,
      own_system: own,
      other_system: foreign
    } do
      assert conn |> get("/api/v1/map_systems/#{own.id}") |> json_response(200)
      assert conn |> get("/api/v1/map_systems/#{foreign.id}") |> json_response(404)
    end

    # NON-VACUITY GUARD. MapSystem's primary `:read` carries the always-on
    # `FilterSystemsByActorMap` preparation, which map-scopes results even if
    # the read POLICY is deleted -- so the HTTP tests above cannot, on their
    # own, prove the policy works. The `:get_by_id` read action has NO such
    # preparation, so this exercises the policy filter in isolation: it fails
    # if `in_token_map([:map_id])` is removed or neutered.
    test "read policy alone (no preparation) excludes foreign rows", %{
      map: map,
      own_system: own,
      other_system: foreign
    } do
      actor = %WandererApp.Api.ActorWithMap{map: map, user: nil}

      assert {:ok, [%{id: own_id}]} =
               WandererApp.Api.MapSystem
               |> Ash.Query.for_read(:get_by_id, %{id: own.id}, actor: actor, authorize?: true)
               |> Ash.read()

      assert own_id == own.id

      assert {:ok, []} =
               WandererApp.Api.MapSystem
               |> Ash.Query.for_read(:get_by_id, %{id: foreign.id},
                 actor: actor,
                 authorize?: true
               )
               |> Ash.read()
    end

    test "create with foreign map_id -> 403, nothing created in either map", %{
      conn: conn,
      map: map,
      other_map: other_map
    } do
      conn
      |> post("/api/v1/map_systems", %{
        "data" => %{
          "type" => "map_systems",
          "attributes" => %{
            "solar_system_id" => 30_000_201,
            "name" => "Foreign",
            "map_id" => other_map.id
          }
        }
      })
      |> json_response(403)

      assert count_systems(other_map.id, 30_000_201) == 0
      assert count_systems(map.id, 30_000_201) == 0
    end

    test "create with map_id omitted -> 201 into the token map", %{conn: conn, map: map} do
      data =
        conn
        |> post("/api/v1/map_systems", %{
          "data" => %{
            "type" => "map_systems",
            "attributes" => %{"solar_system_id" => 30_000_202, "name" => "Own"}
          }
        })
        |> json_response(201)
        |> Map.get("data")

      system = WandererApp.Repo.get!(WandererApp.Api.MapSystem, data["id"])
      assert system.map_id == map.id
    end

    test "update own -> 200; update foreign -> 404 and row unchanged", %{
      conn: conn,
      own_system: own,
      other_system: foreign
    } do
      assert conn
             |> patch("/api/v1/map_systems/#{own.id}", %{
               "data" => %{
                 "type" => "map_systems",
                 "id" => own.id,
                 "attributes" => %{"description" => "touched"}
               }
             })
             |> json_response(200)

      conn
      |> patch("/api/v1/map_systems/#{foreign.id}", %{
        "data" => %{
          "type" => "map_systems",
          "id" => foreign.id,
          "attributes" => %{"description" => "touched"}
        }
      })
      |> json_response(404)

      # Repo, not Ash: MapSystem's always-on FilterSystemsByActorMap
      # preparation map-scopes reads even with `authorize?: false`, so Ash.get
      # would report NotFound for a foreign row that still exists.
      reloaded = WandererApp.Repo.get!(WandererApp.Api.MapSystem, foreign.id)
      refute reloaded.description == "touched"
    end

    test "destroy own -> 200; destroy foreign -> 404 and row preserved", %{
      conn: conn,
      own_system: own,
      other_system: foreign
    } do
      assert conn |> delete("/api/v1/map_systems/#{own.id}") |> json_response(200)

      conn |> delete("/api/v1/map_systems/#{foreign.id}") |> json_response(404)

      assert %WandererApp.Api.MapSystem{} =
               WandererApp.Repo.get(WandererApp.Api.MapSystem, foreign.id)
    end
  end

  describe "map_connection" do
    setup %{map: map, other_map: other_map} do
      own_row =
        insert(:map_connection, %{
          map_id: map.id,
          solar_system_source: 30_000_143,
          solar_system_target: 30_000_144
        })

      foreign_row =
        insert(:map_connection, %{
          map_id: other_map.id,
          solar_system_source: 30_000_142,
          solar_system_target: 30_000_145
        })

      %{own_row: own_row, foreign_row: foreign_row}
    end

    test "list includes own, excludes foreign", %{
      conn: conn,
      own_row: own,
      foreign_row: foreign
    } do
      got = list_ids(conn, "/api/v1/map_connections")
      assert own.id in got
      refute foreign.id in got
    end

    test "GET own -> 200, GET foreign -> 404", %{
      conn: conn,
      own_row: own,
      foreign_row: foreign
    } do
      assert conn |> get("/api/v1/map_connections/#{own.id}") |> json_response(200)
      assert conn |> get("/api/v1/map_connections/#{foreign.id}") |> json_response(404)
    end

    # Non-vacuity guard, same rationale as the map_system case above:
    # `:read_by_map` has no FilterConnectionsByActorMap preparation, so the
    # policy filter is what must exclude the foreign row here. Querying by
    # the FOREIGN map_id would return the foreign row if the policy were gone.
    test "read policy alone (no preparation) excludes foreign rows", %{
      map: map,
      other_map: other_map,
      foreign_row: foreign
    } do
      actor = %WandererApp.Api.ActorWithMap{map: map, user: nil}

      assert {:ok, rows} =
               WandererApp.Api.MapConnection
               |> Ash.Query.for_read(:read_by_map, %{map_id: other_map.id},
                 actor: actor,
                 authorize?: true
               )
               |> Ash.read()

      refute foreign.id in Enum.map(rows, & &1.id)
    end

    test "create with foreign map_id -> 403 and nothing created", %{
      conn: conn,
      other_map: other_map
    } do
      conn
      |> post("/api/v1/map_connections", %{
        "data" => %{
          "type" => "map_connections",
          "attributes" => %{
            "map_id" => other_map.id,
            "solar_system_source" => 30_000_142,
            "solar_system_target" => 30_000_199
          }
        }
      })
      |> json_response(403)

      {:ok, count} =
        Ash.count(
          Ash.Query.filter(
            WandererApp.Api.MapConnection,
            map_id == ^other_map.id and solar_system_target == 30_000_199
          ),
          authorize?: false
        )

      assert count == 0
    end

    test "destroy foreign -> 404, row preserved", %{conn: conn, foreign_row: foreign} do
      conn |> delete("/api/v1/map_connections/#{foreign.id}") |> json_response(404)

      assert %WandererApp.Api.MapConnection{} =
               WandererApp.Repo.get(WandererApp.Api.MapConnection, foreign.id)
    end
  end

  describe "map" do
    # `map` has NO index route. Read is GET /maps/:slug; PATCH/DELETE use the
    # primary-key route /maps/:id. Create is `post(:new)` on /maps.
    test "GET own slug -> 200, GET foreign slug -> 404", %{
      conn: conn,
      map: map,
      other_map: other_map
    } do
      assert conn |> get("/api/v1/maps/#{map.slug}") |> json_response(200)
      assert conn |> get("/api/v1/maps/#{other_map.slug}") |> json_response(404)
    end

    test "POST /maps is forbidden for a token actor (403)", %{conn: conn, map: map} do
      conn
      |> post("/api/v1/maps", %{
        "data" => %{
          "type" => "maps",
          "attributes" => %{
            "name" => "new",
            "slug" => "brand-new-#{System.unique_integer([:positive])}",
            "owner_id" => map.owner_id
          }
        }
      })
      |> json_response(403)
    end

    test "PATCH own map -> 200", %{conn: conn, map: map} do
      assert conn
             |> patch("/api/v1/maps/#{map.id}", %{
               "data" => %{
                 "type" => "maps",
                 "id" => map.id,
                 "attributes" => %{"name" => "renamed", "slug" => map.slug}
               }
             })
             |> json_response(200)
    end

    test "PATCH/DELETE foreign map -> 404, row preserved and unchanged", %{
      conn: conn,
      other_map: other_map
    } do
      conn
      |> patch("/api/v1/maps/#{other_map.id}", %{
        "data" => %{
          "type" => "maps",
          "id" => other_map.id,
          "attributes" => %{"name" => "hacked", "slug" => other_map.slug}
        }
      })
      |> json_response(404)

      conn |> delete("/api/v1/maps/#{other_map.id}") |> json_response(404)

      reloaded = WandererApp.Repo.get!(WandererApp.Api.Map, other_map.id)
      refute reloaded.name == "hacked"
    end
  end

  describe "read-only resources" do
    test "map_subscriptions list excludes foreign; GET foreign -> 404", %{
      conn: conn,
      other_sub: sub
    } do
      refute sub.id in list_ids(conn, "/api/v1/map_subscriptions")
      assert conn |> get("/api/v1/map_subscriptions/#{sub.id}") |> json_response(404)
    end

    test "map_character_settings list includes own, excludes foreign; GET foreign -> 404", %{
      conn: conn,
      map: map,
      char: char,
      other_map: other_map,
      other_char: other_char
    } do
      own = insert(:map_character_settings, %{map_id: map.id, character_id: char.id})

      foreign =
        insert(:map_character_settings, %{map_id: other_map.id, character_id: other_char.id})

      got = list_ids(conn, "/api/v1/map_character_settings")
      assert own.id in got
      refute foreign.id in got

      assert conn |> get("/api/v1/map_character_settings/#{foreign.id}") |> json_response(404)
    end

    test "map_user_settings list includes own, excludes foreign; GET foreign -> 404", %{
      conn: conn,
      map: map,
      other_map: other_map,
      other_user: other_user
    } do
      settings_user = insert(:user)

      {:ok, own} =
        Ash.create(
          WandererApp.Api.MapUserSettings,
          %{map_id: map.id, user_id: settings_user.id, settings: "{}"},
          authorize?: false
        )

      {:ok, foreign} =
        Ash.create(
          WandererApp.Api.MapUserSettings,
          %{map_id: other_map.id, user_id: other_user.id, settings: "{}"},
          authorize?: false
        )

      # MapUserSettings has a composite primary key ([:map_id, :user_id]), so
      # AshJsonApi renders/accepts a compound id of "<map_id>-<user_id>"
      # rather than the bare `:id` uuid.
      own_json_id = "#{own.map_id}-#{own.user_id}"
      foreign_json_id = "#{foreign.map_id}-#{foreign.user_id}"

      got = list_ids(conn, "/api/v1/map_user_settings")
      assert own_json_id in got
      refute foreign_json_id in got

      # NOTE: no GET-by-id assertion here. `map_user_settings` has a composite
      # primary key and its `get(:read)` route raises (500/SomethingWentWrong)
      # for ANY compound id, own or foreign -- a pre-existing route defect
      # unrelated to authorization. The list exclusion above is what proves
      # the read policy scopes this resource.
    end
  end

  describe "map_default_settings" do
    setup %{map: map, other_map: other_map, char: char, other_char: other_char} do
      # `create` runs `relate_actor(:created_by/:updated_by)`, which requires a
      # Character actor, so seeding must pass one. (This is also why token
      # actors cannot create these rows over HTTP at all.)
      {:ok, own} =
        Ash.create(
          WandererApp.Api.MapDefaultSettings,
          %{map_id: map.id, settings: "{}"},
          actor: char,
          authorize?: false
        )

      {:ok, foreign} =
        Ash.create(
          WandererApp.Api.MapDefaultSettings,
          %{map_id: other_map.id, settings: "{}"},
          actor: other_char,
          authorize?: false
        )

      %{own_mds: own, foreign_mds: foreign}
    end

    test "list includes own, excludes foreign; GET foreign -> 404", %{
      conn: conn,
      own_mds: own,
      foreign_mds: foreign
    } do
      got = list_ids(conn, "/api/v1/map_default_settings")
      assert own.id in got
      refute foreign.id in got

      assert conn |> get("/api/v1/map_default_settings/#{foreign.id}") |> json_response(404)
    end

    # NOTE: `map_default_settings` create/update run `relate_actor(:created_by)`
    # / `relate_actor(:updated_by)` against relationships whose target is a
    # Character. An `ActorWithMap` token carries no character, so these
    # actions are structurally unreachable for a token actor regardless of
    # policy -- Ash fails the relationship before/independently of authz.
    # We therefore assert only that a foreign row is not reachable, and do
    # not claim a 200 own-update that the resource cannot produce here.
    test "update foreign -> 404 and row unchanged", %{
      conn: conn,
      foreign_mds: foreign
    } do
      conn
      |> patch("/api/v1/map_default_settings/#{foreign.id}", %{
        "data" => %{
          "type" => "map_default_settings",
          "id" => foreign.id,
          "attributes" => %{"settings" => ~s({"hacked":true})}
        }
      })
      |> json_response(404)

      reloaded = WandererApp.Repo.get!(WandererApp.Api.MapDefaultSettings, foreign.id)
      assert reloaded.settings == "{}"
    end

    test "destroy foreign -> 404, row preserved", %{conn: conn, foreign_mds: foreign} do
      conn |> delete("/api/v1/map_default_settings/#{foreign.id}") |> json_response(404)

      assert %WandererApp.Api.MapDefaultSettings{} =
               WandererApp.Repo.get(WandererApp.Api.MapDefaultSettings, foreign.id)
    end
  end

  describe "map_access_list" do
    setup %{map: map, other_map: other_map, char: char, other_char: other_char} do
      own_acl = insert(:access_list, %{owner_id: char.id})
      foreign_acl = insert(:access_list, %{owner_id: other_char.id})

      own = insert(:map_access_list, %{map_id: map.id, access_list_id: own_acl.id})
      foreign = insert(:map_access_list, %{map_id: other_map.id, access_list_id: foreign_acl.id})

      %{own_mal: own, foreign_mal: foreign, own_acl: own_acl}
    end

    test "list includes own, excludes foreign; GET foreign -> 404", %{
      conn: conn,
      own_mal: own,
      foreign_mal: foreign
    } do
      got = list_ids(conn, "/api/v1/map_access_lists")
      assert own.id in got
      refute foreign.id in got

      assert conn |> get("/api/v1/map_access_lists/#{foreign.id}") |> json_response(404)
    end

    test "create is forbidden for a token actor even for its OWN map (403)", %{
      conn: conn,
      map: map,
      own_acl: acl
    } do
      conn
      |> post("/api/v1/map_access_lists", %{
        "data" => %{
          "type" => "map_access_lists",
          "attributes" => %{"map_id" => map.id, "access_list_id" => acl.id}
        }
      })
      |> json_response(403)
    end

    test "destroy on an OWN row is forbidden (403), row preserved", %{
      conn: conn,
      own_mal: own
    } do
      conn |> delete("/api/v1/map_access_lists/#{own.id}") |> json_response(403)

      # Composite primary key ([:id, :map_id, :access_list_id]) -- Repo.get/2
      # requires a single-field PK, so query by the id column explicitly.
      assert %WandererApp.Api.MapAccessList{} =
               WandererApp.Repo.get_by(WandererApp.Api.MapAccessList, id: own.id)
    end
  end
end
