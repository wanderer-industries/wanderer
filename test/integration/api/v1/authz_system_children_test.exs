defmodule WandererAppWeb.Api.V1.AuthzSystemChildrenTest do
  @moduledoc """
  Authorization matrix for the `system`-path `/api/v1` resources:
  `map_system_signature` (read + delete), `map_system_structure` (full CRUD)
  and `map_system_comment` (read-only).

  Only routes that actually exist are exercised, and each denial is paired
  with an own-map positive control — a policy that forbade everything would
  pass the deny half on its own.

  Status codes follow the contract used across the `/api/v1` authz suite:

    * Read/update/destroy are FILTER checks, so an out-of-scope row is
      *excluded* rather than rejected: list omits it, and `GET`/`PATCH`/
      `DELETE` on a foreign id return **404**, not 403. Returning 404 also
      avoids confirming that another map's row exists.
    * Create has no existing row to filter and is guarded by a SimpleCheck
      that looks up the parent system, so a foreign parent returns **403**.

  `WandererApp.Api.MapSystem`'s primary read carries an always-on
  `FilterSystemsByActorMap` preparation, but these resources are separate
  and carry no competing preparation, so an HTTP round-trip here does
  exercise the policy under test.
  """
  use WandererAppWeb.ApiCase, async: false

  require Ash.Query

  setup %{conn: conn} do
    owner = insert(:user)
    char = insert(:character, %{user_id: owner.id})
    map = insert(:map, %{owner_id: char.id})
    own_system = insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})

    other_user = insert(:user)
    other_char = insert(:character, %{user_id: other_user.id})
    other_map = insert(:map, %{owner_id: other_char.id})
    other_system = insert(:map_system, %{map_id: other_map.id, solar_system_id: 30_000_144})

    own_sig = insert(:map_system_signature, %{system_id: own_system.id})
    other_sig = insert(:map_system_signature, %{system_id: other_system.id})
    own_struct = insert(:map_system_structure, %{system_id: own_system.id})
    other_struct = insert(:map_system_structure, %{system_id: other_system.id})

    %{
      conn: create_authenticated_conn(conn, map),
      map: map,
      own_char: char,
      other_char: other_char,
      own_system: own_system,
      other_system: other_system,
      own_sig: own_sig,
      other_sig: other_sig,
      own_struct: own_struct,
      other_struct: other_struct
    }
  end

  defp ids(data), do: Enum.map(data, & &1["id"])

  defp create_comment(system_id, character_id, text) do
    {:ok, comment} =
      Ash.create(
        WandererApp.Api.MapSystemComment,
        %{system_id: system_id, character_id: character_id, text: text},
        authorize?: false
      )

    comment
  end

  # The JSON:API schema for structures marks these as required on both POST and
  # PATCH, so every write body must carry them.
  defp structure_attrs(overrides) do
    Map.merge(
      %{
        "character_eve_id" => "2112625428",
        "solar_system_name" => "Jita",
        "solar_system_id" => 30_000_142,
        "structure_type_id" => "35832",
        "structure_type" => "Astrahus",
        "name" => "POS"
      },
      overrides
    )
  end

  describe "map_system_signature (read + delete)" do
    test "index includes own and excludes foreign", %{
      conn: conn,
      own_sig: own,
      other_sig: other
    } do
      data = conn |> get("/api/v1/map_system_signatures") |> json_response(200) |> Map.get("data")

      assert own.id in ids(data)
      refute other.id in ids(data)
    end

    test "GET own signature -> 200 (positive control)", %{conn: conn, own_sig: own} do
      conn |> get("/api/v1/map_system_signatures/#{own.id}") |> json_response(200)
    end

    test "GET foreign signature -> 404", %{conn: conn, other_sig: other} do
      conn |> get("/api/v1/map_system_signatures/#{other.id}") |> json_response(404)
    end

    test "DELETE own signature -> 2xx and row is gone (positive control)", %{
      conn: conn,
      own_sig: own
    } do
      resp = delete(conn, "/api/v1/map_system_signatures/#{own.id}")
      assert resp.status in [200, 204]

      assert {:error, _} =
               Ash.get(WandererApp.Api.MapSystemSignature, own.id, authorize?: false)
    end

    test "DELETE foreign signature -> 404 and row survives", %{conn: conn, other_sig: other} do
      assert conn |> delete("/api/v1/map_system_signatures/#{other.id}") |> Map.get(:status) ==
               404

      # Match the struct: {:ok, _} would also pass if the row had been deleted.
      assert {:ok, %WandererApp.Api.MapSystemSignature{}} =
               Ash.get(WandererApp.Api.MapSystemSignature, other.id, authorize?: false)
    end
  end

  describe "map_system_structure (full CRUD)" do
    test "index includes own and excludes foreign", %{
      conn: conn,
      own_struct: own,
      other_struct: other
    } do
      data = conn |> get("/api/v1/map_system_structures") |> json_response(200) |> Map.get("data")

      assert own.id in ids(data)
      refute other.id in ids(data)
    end

    test "GET foreign structure -> 404", %{conn: conn, other_struct: other} do
      conn |> get("/api/v1/map_system_structures/#{other.id}") |> json_response(404)
    end

    test "create under own system -> 201 (positive control)", %{conn: conn, own_system: sys} do
      body = %{
        "data" => %{
          "type" => "map_system_structures",
          "attributes" => structure_attrs(%{"system_id" => sys.id})
        }
      }

      conn |> post("/api/v1/map_system_structures", body) |> json_response(201)
    end

    test "create under foreign system -> 403 and nothing is created", %{
      conn: conn,
      other_system: sys
    } do
      body = %{
        "data" => %{
          "type" => "map_system_structures",
          "attributes" =>
            structure_attrs(%{
              "system_id" => sys.id,
              "name" => "Foreign POS",
              "solar_system_id" => 30_000_144
            })
        }
      }

      conn |> post("/api/v1/map_system_structures", body) |> json_response(403)

      {:ok, rows} =
        WandererApp.Api.MapSystemStructure
        |> Ash.Query.filter(name == "Foreign POS")
        |> Ash.read(authorize?: false)

      assert rows == []
    end

    test "PATCH own structure -> 200 (positive control)", %{conn: conn, own_struct: own} do
      body = %{
        "data" => %{
          "type" => "map_system_structures",
          "id" => own.id,
          "attributes" => structure_attrs(%{"name" => "Renamed"})
        }
      }

      conn |> patch("/api/v1/map_system_structures/#{own.id}", body) |> json_response(200)
    end

    test "PATCH foreign structure -> 404 and row is unchanged", %{
      conn: conn,
      other_struct: other
    } do
      body = %{
        "data" => %{
          "type" => "map_system_structures",
          "id" => other.id,
          "attributes" => structure_attrs(%{"name" => "Hacked"})
        }
      }

      assert conn
             |> patch("/api/v1/map_system_structures/#{other.id}", body)
             |> Map.get(:status) == 404

      {:ok, reloaded} =
        Ash.get(WandererApp.Api.MapSystemStructure, other.id, authorize?: false)

      assert reloaded.name == other.name
      refute reloaded.name == "Hacked"
    end

    test "DELETE foreign structure -> 404 and row survives", %{conn: conn, other_struct: other} do
      assert conn |> delete("/api/v1/map_system_structures/#{other.id}") |> Map.get(:status) ==
               404

      assert {:ok, %WandererApp.Api.MapSystemStructure{}} =
               Ash.get(WandererApp.Api.MapSystemStructure, other.id, authorize?: false)
    end
  end

  describe "map_system_comment (read-only)" do
    setup %{
      own_char: own_char,
      other_char: other_char,
      own_system: own_system,
      other_system: other_system
    } do
      # NOTE: the shared `insert(:map_system_comment, ...)` factory is stale --
      # it passes map_id/solar_system_id/position_x/position_y, none of which
      # MapSystemComment's :create accepts (only system_id, character_id, text).
      # Fixing the shared factory is out of scope for this task, so create
      # directly here.
      own_comment = create_comment(own_system.id, own_char.id, "own comment")
      other_comment = create_comment(other_system.id, other_char.id, "foreign comment")

      %{own_comment: own_comment, other_comment: other_comment}
    end

    test "index includes own and excludes foreign", %{
      conn: conn,
      own_comment: own,
      other_comment: other
    } do
      data = conn |> get("/api/v1/map_system_comments") |> json_response(200) |> Map.get("data")

      assert own.id in ids(data)
      refute other.id in ids(data)
    end

    test "GET foreign comment -> 404", %{conn: conn, other_comment: other} do
      conn |> get("/api/v1/map_system_comments/#{other.id}") |> json_response(404)
    end

    test "by_system route for a foreign system returns no rows", %{
      conn: conn,
      other_system: sys,
      other_comment: other
    } do
      data =
        conn
        |> get("/api/v1/map_system_comments/by_system/#{sys.id}")
        |> json_response(200)
        |> Map.get("data")

      refute other.id in ids(data)
    end
  end
end
