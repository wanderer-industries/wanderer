# /api/v1 Authorization Hardening — Design

**Date:** 2026-07-29
**Status:** Approved design, pending implementation plan
**Area:** `WandererApp.Api` (Ash domain), `WandererAppWeb` `/api/v1` JSON:API surface

## Problem

The `/api/v1` JSON:API surface (AshJsonApi, `WandererAppWeb.ApiV1Router`) exposes
~28 Ash resources with **no framework-level authorization**. No resource declares
an authorizer, and no `policies` blocks exist anywhere in `lib/wanderer_app/api`.

Authentication (`WandererAppWeb.Plugs.CheckJsonApiAuth`) resolves a map API key to
the map's **owner user** and sets an `ActorWithMap{user, map}` actor. Because there
are no policies, the actor's reach is bounded only by whichever ad-hoc `prepare`
filters each read action happens to include.

Inventory of route-exposed resources and their current scoping:

| Resource | Actor-map scoping today |
|---|---|
| `map_system`, `map_connection` | Scoped via `FilterByActorMap` preparation |
| `map`, `access_list` | Role-based filter only on non-primary actions (`available`) |
| `access_list_member`, `map_access_list`, `map_character_settings`, `map_subscription`, `map_system_comment`, `map_system_signature`, `map_system_structure`, `map_user_settings`, `user_activity` | **None** — reads/writes unscoped |

Result: a single map's API key can read (and in some cases write) rows belonging
to other maps/accounts on the unscoped resources. This is the reported
"map keys behave like superuser keys" defect.

A second reported symptom — "ACL API keys are invalid" — is a design mismatch, not
a bug: ACL keys are only honored on the legacy `/api/acls/*` routes
(`CheckAclApiKey`). `/api/v1` only understands map keys. Out of scope for this fix
except to document the boundary.

## Goals

- Deny-by-default authorization for every `/api/v1`-exposed resource.
- A map API token authorizes **only** its own map and resources linked to that map.
- Internal (non-API) callers — LiveViews, repositories, background jobs — are
  **unaffected**.
- Close the cross-map read/write holes on all currently-unscoped resources.

## Non-goals

- Changing ACL-key auth on legacy `/api/acls/*` routes.
- Introducing session-based auth (none exists in practice today).
- Reworking the `/api/*` legacy surface (already map-scoped via `CheckMapApiKey`).
- Exposing account-level resources (users, transactions) via the API.

## Key decisions

1. **Model:** deny-by-default Ash policies (`Ash.Policy.Authorizer`).
2. **Enforcement gate:** domain `authorize :when_requested`.
3. **Token scope:** strictly single-map.
4. **Rollout:** all route-exposed resources at once, via a shared policy helper.
5. **Composition:** a `bypass` for trusted actors, then action policies (NOT
   stacked `policy` blocks — that denies everyone; see review #1).
6. **Actor shapes (three):** API token `ActorWithMap{map: %{}}` → scoped; session
   `ActorWithMap{map: nil}` → trusted; internal `User` **or** `Character` →
   trusted.
7. **ACLs:** read-only for token actors on `/api/v1`; mutation stays on legacy
   `/api/acls/*`.
8. **`user_activity`:** token actors denied (no single-map link).
9. **Custom endpoint** `.../systems_and_connections`: direct controller guard
   (path map vs token map), since it bypasses Ash.

## Revision note

This design was revised after a code review that identified: broken policy
composition (#1), a missed exposed resource `map_default_settings` (#2), unsound
relationship-path write checks (#3), an overlooked session actor shape (#4),
undefined ACL write semantics (#5), non-proving tests (#6), an unguarded custom
endpoint (#7), a wrong factory module name (#8), and a third (Character) actor
shape. All are incorporated above.

## Authorization mechanism

### Domain gate

Add to `WandererApp.Api`:

```elixir
authorization do
  authorize :when_requested
end
```

**Critical semantic (verified against Ash source, `lib/ash/actions/helpers.ex`):**
under `:when_requested`, passing **`actor:` alone** triggers authorization — not
only explicit `authorize?: true`:

```elixir
:when_requested ->
  if Keyword.has_key?(opts, :actor) do
    Keyword.put_new(opts, :authorize?, true)
  else
    Keyword.put(opts, :authorize?, opts[:authorize?] || Keyword.has_key?(opts, :actor))
  end
```

AshJsonApi always passes `authorize?: true`, so the API path is always enforced.
Internal `code_interface` calls that pass neither `actor:` nor `authorize?:` remain
unenforced. Internal calls that **do** pass `actor:` (a plain `User`) become
enforced and are handled by the `trusted_user` policy branch (below).

### Three actor shapes (revised after review)

There are **three** actor shapes reaching these resources, not two:

1. **API token** — `%ActorWithMap{user: user, map: %{id: _}}` from `CheckJsonApiAuth`
   token auth. Scope to `actor.map.id`.
2. **Session** — `%ActorWithMap{user: user, map: nil}` from `CheckJsonApiAuth`
   session auth (line 76). **Decision: treat `map == nil` as trusted/full-access**,
   preserving current session behavior (the actor is the logged-in owner via the
   web app).
3. **Internal** — a plain `%User{}` (`Map.available(actor: current_user)`) **or** a
   plain `%Character{}` (`MapDefaultSettings.update(actor: character)` at
   `map_core_event_handler.ex:366`). Both are trusted/full-access.

Anything else (nil actor with `authorize?: true`, unexpected structs) → deny.

### Policy composition — bypass, not stacked policies (fixes review #1)

**The original design was wrong.** Ash requires *every applicable policy* to pass.
Two separate `policy` blocks (an unconditional trusted-user policy + an
action-specific map policy) means a token actor fails the trusted policy and a
plain user fails the map policy — **every request is denied.**

Correct structure: a **`bypass`** for trusted actors (if it passes, remaining
policies are skipped), followed by the action policies:

```elixir
policies do
  # Trusted actors (internal User/Character, or session ActorWithMap{map: nil})
  # short-circuit the whole request.
  bypass WandererApp.Api.Policies.MapScoped.Trusted do
    authorize_if always()
  end

  policy action_type(:read) do
    authorize_if WandererApp.Api.Policies.MapScoped.in_token_map([:map_id])
  end

  policy action_type([:create, :update, :destroy]) do
    authorize_if WandererApp.Api.Policies.MapScoped.write_in_token_map([:map_id])
  end
end
```

### Shared policy helper

New module `WandererApp.Api.Policies.MapScoped` provides:

- `MapScoped.Trusted` — a `SimpleCheck` that matches a plain `User`, a plain
  `Character`, or an `ActorWithMap` whose `map` is `nil`. Used only inside `bypass`.
- `in_token_map/1` — builds a **filter check** scoping rows to the token map along
  a declared path (filter, not simple, so reads return the in-scope subset and
  `GET /:id` yields 404 rather than 403).
- `write_in_token_map/1` — a changeset check for create/update/destroy. For
  **direct `map_id`** it reads the changeset attribute. For **relationship paths**
  it runs an **authorization query against the parent** (see review #3 below), not
  loaded relationship data.

The helper reuses `WandererApp.Api.ActorHelpers.get_map/1` to extract the token
map. Note `get_map/1` returns `nil` for `ActorWithMap{map: nil}` and for
User/Character actors — so the filter/write checks naturally match nothing for
non-token actors, but those actors never reach the action policies because the
`bypass` already authorized them.

### Per-resource map path (complete route-exposed inventory)

Every resource with active `/api/v1` routes (operations > 0). The `(0 routes)`
resources (`map_solar_system`, `map_state`, `ship_type_info`, `user`) declare a
routes block but expose no operations, so no policy is required; they get a
deny-by-default `Trusted`-only policy as defense-in-depth.

| Resource | Read scope path | Write policy |
|---|---|---|
| `map` | `[:id]` | `write_in_token_map([:id])` |
| `map_system`, `map_connection` | `[:map_id]` | `write_in_token_map([:map_id])` |
| `map_subscription`, `map_user_settings`, `map_character_settings`, `map_access_list`, `map_default_settings` | `[:map_id]` | `write_in_token_map([:map_id])` |
| `map_system_signature`, `map_system_structure`, `map_system_comment` | via `[:system, :map_id]` | parent-query write check (review #3) |
| `access_list` | `exists(map_access_lists, map_id == ^token_map)` | **read-only for tokens** (review #5) |
| `access_list_member` | via `exists(access_list.map_access_lists, map_id == ^token_map)` | **read-only for tokens** |
| `user_activity` | **token actors denied** — no clean single-map link | denied |

**`map_default_settings` (fixes review #2).** Full CRUD routes, previously missed.
It has a direct `map_id`, so it joins the direct-path group. Its `use` block must
gain `authorizers: [Ash.Policy.Authorizer]` — domain config alone does not attach
the authorizer.

**ACLs are read-only for token actors (fixes review #5).** An ACL may link to
several maps, so allowing a token to mutate a shared ACL would affect other maps,
and create cannot satisfy a pre-existing join. Decision: tokens may **read** ACLs /
members / `map_access_list` links scoped to their map; all ACL **mutation** stays
on the legacy `/api/acls/*` routes (ACL-key auth). Concretely, `access_list` and
`access_list_member` get a read policy only; their create/update/destroy policies
`forbid_if always()` for the token branch (the `Trusted` bypass still lets internal
callers through). `map_access_list` (the join itself) keeps direct-`map_id`
read scoping; its writes are token-forbidden too, since attaching/detaching ACLs is
an ownership operation.

**`user_activity` (resolves the prior open question).** `belongs_to :character`,
`belongs_to :user`; no map linkage. Token actors are **denied** (read policy
`forbid_if always()` for the token branch). Internal callers pass via `Trusted`.

### Relationship-path write checks (fixes review #3)

The original `WriteInTokenMap` read `changeset.data.system.map_id`. Ash
relationships are generally **unloaded**, and creates only carry `system_id` — so
valid signature/structure/comment writes would be denied.

Correct approach for the `[:system, :map_id]` resources:

- **Update/Destroy** — use a **filter check** (same as reads): Ash applies it to the
  row being modified via `exists(system, map_id == ^token_map)`. No manual load.
- **Create** — a `SimpleCheck` that reads `system_id` from the changeset, then runs
  an **authorization query** `MapSystem` `exists(id == ^system_id and map_id ==
  ^token_map)`. Authorize only if the parent system is in the token map.

This avoids relying on loaded relationship data entirely.

## Custom endpoint outside the Ash router (fixes review #7)

`GET /api/v1/maps/:map_id/systems_and_connections`
(`MapSystemsConnectionsController.show/2`) is a hand-written controller, not an Ash
action, so **policies do not apply**. Today it never compares the path `map_id` to
the authenticated token map and calls `load_map_data/1` without an actor.

**Decision: add a direct guard in the controller** — compare the path `map_id`
against `conn.assigns.map.id` (set by `CheckJsonApiAuth`). On mismatch, return the
same 404 shape the action path returns for out-of-scope reads. This closes the hole
without an Ash rewrite; the endpoint keeps its current data-loading path.

## Error behavior

- **Reads** — filter checks silently exclude out-of-scope rows. List returns the
  in-scope subset; `GET /:id` for an out-of-map row returns **404**.
- **Writes** (create/update/destroy) on an out-of-scope row / parent → **403**.
- Token actor on a token-forbidden resource (ACLs write, `user_activity`) → 404 on
  read-forbidden, 403 on write-forbidden.
- Unknown/nil actor with `authorize?: true` → **403** (deny-by-default).

## Edge cases

1. `ActorWithMap{map: nil}` (session) → **trusted** via `bypass` (decision above).
2. Create where body omits `map_id` → `write_in_token_map` must default/derive it
   from the token map, or forbid on mismatch. Never allow a create to land in
   another map.
3. Relationship-path create with `system_id` pointing at another map's system →
   parent authorization query fails → 403.
4. Relationship-path resource with a null/absent parent `system` → 403.
5. `includes` / compound documents (`?include=owner,characters`) — included
   relationships are authorized by Ash. Verify includes of account data do not
   leak; restrict includable/public fields if they do.

## Internal call-site audit (blast radius)

Sites passing `actor:` become enforced under `:when_requested`; each actor is
User/Character and must pass via the `Trusted` bypass. Each is covered by a
regression test.

| Site | Actor type | Call |
|---|---|---|
| `lib/wanderer_app/maps.ex:17` | User | `Map.available(%{}, actor: current_user)` |
| `lib/wanderer_app/acls.ex:12` | User | `AccessList.available(%{}, actor: current_user)` |
| `lib/wanderer_app/repositories/map_repo.ex:39` | User | `Ash.load(..., :user_permissions, actor: current_user)` |
| `lib/wanderer_app_web/live/maps/maps_live.ex:734` | User | `Ash.load!(:user_permissions, actor: current_user)` |
| `lib/wanderer_app_web/live/map/event_handlers/map_core_event_handler.ex:375,379` | **Character** | `MapDefaultSettings.update/create(..., actor: character)` |
| `lib/wanderer_app_web/controllers/map_api_controller.ex:1373` | User | `Map.duplicate(map_attrs, actor: current_user)` |

The Character actor at `map_core_event_handler.ex:366` is why `Trusted` must match
`Character`, not just `User`.

Sites passing `authorize?: false` (explicit bypass, unaffected): `map_pings_repo.ex:45`,
`map_audit_api_controller.ex:136`.

## Testing strategy

Test module uses `import WandererAppWeb.Factory` (the actual module name — the
original plan's `WandererApp.Factory` was wrong, review #8). Harness: two maps, two
owners, one token (`test/integration/api/v1/map_system_api_v1_test.exs`).

Per exposed **writable** resource, the full operation matrix with **real
assertions** (review #6 — list/get alone is insufficient):

1. **Read list** — asserts the other map's row id is absent from `data`.
2. **Read by id** — `GET /:id` of a map-B row → asserts **404**.
3. **Create** — POST with `map_id`/parent in map B → asserts **403** AND that no
   row was created in map B (`Repo` count unchanged).
4. **Update** — PATCH a map-B row → asserts **403** AND the row's attributes are
   unchanged in the DB.
5. **Destroy** — DELETE a map-B row → asserts **403** AND `Repo.get/2` still
   returns the row.
6. **Positive control** — the same operations on the token's *own* map succeed
   (proves the policy doesn't over-deny valid writes; directly guards review #3).

Special cases:

- `access_list` / `access_list_member` — token reads only ACLs linked to its map;
  create/update/destroy via token → **403** (read-only decision), and a positive
  test that an internal (User) actor can still mutate.
- `map_default_settings` — full matrix (previously unprotected).
- `user_activity` — token read returns `[]`; token write → 403.
- Custom endpoint — `GET /api/v1/maps/:other_map_id/systems_and_connections` with
  token for map A → **404**; own map → 200.
- **Includes leak (non-vacuous, review #6)** — request `?include=owner` for the
  token's own map, then assert the `included` set contains **only** the token map's
  owner id and does **not** contain the other account's owner id or any
  account-sensitive field (e.g. `hash`, email). Asserting "ids are strings" is not
  acceptable.

Regression / non-breakage:

- One test per audited `actor:` site (User and Character) asserting success.
- Full suite green.

## Verification gate

- `mix test` (targeted v1 + affected internal paths).
- `mix format`, `mix credo` (if configured), `mix compile --warnings-as-errors`.
- Manual: confirm the original exploit (map key listing another map's
  `access_lists` / `map_subscriptions`) now returns only in-scope rows.
