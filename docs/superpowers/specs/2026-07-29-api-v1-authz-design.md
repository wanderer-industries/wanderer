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
- Preserving session authentication on `/api/v1` — it is intentionally removed
  (token-only); no client depends on it.
- Reworking the `/api/*` legacy surface (already map-scoped via `CheckMapApiKey`).
- Exposing account-level resources (users, transactions) via the API.

## Key decisions

1. **Model:** deny-by-default Ash policies (`Ash.Policy.Authorizer`).
2. **Enforcement gate:** domain `authorize :when_requested`.
3. **Token scope:** strictly single-map.
4. **Rollout:** all route-exposed resources at once, via a shared policy helper.
5. **Composition:** a `bypass` for trusted actors, then action policies (NOT
   stacked `policy` blocks — that denies everyone).
6. **`/api/v1` is token-only:** the session branch is removed from
   `CheckJsonApiAuth`. The only HTTP actor is a scoped `ActorWithMap{map: %{}}`.
   Internal in-process `User`/`Character` actors are trusted via bypass. A
   `map: nil` actor is **denied**, never trusted.
7. **ACLs:** read-only for token actors on `/api/v1`; mutation stays on legacy
   `/api/acls/*`. `map_access_list` writes also token-forbidden.
8. **`user_activity`:** token actors denied (no single-map link).
9. **Custom endpoint** `.../systems_and_connections`: guard path-map vs token-map
   **and** pass the actor into the reads; tests assert real IDs.
10. **Cross-map create:** reject with 403 (augment `InjectMapFromActor`), not coerce.
11. **Policies follow each resource's real route/action matrix** (see the matrix
    table); tests exercise only routes that exist.

## Revision note

**Round 1 review** fixed: broken policy composition, missed `map_default_settings`,
unsound relationship-path write checks, ACL write semantics, non-proving tests, an
unguarded custom endpoint, a wrong factory module, and the Character actor shape.

**Round 2 review** fixed the more serious issues that the round-1 revision
introduced or left open:

- **#1 (critical):** treating the session `map: nil` actor as trusted made any
  logged-in user a cross-tenant superuser. Resolved by making `/api/v1`
  **token-only** (remove the session branch); `map: nil` is never trusted.
- **#2/#3:** policies/tests must follow each resource's **real route/action
  matrix** — signatures are delete-only, comments read-only, only structures have
  full child CRUD. Added the authoritative matrix table.
- **#4:** the custom endpoint's reads run without an actor and would return empty;
  now pass the actor and assert real IDs.
- **#5:** `InjectMapFromActor` coerces rather than rejects cross-map creates;
  contract is now **reject with 403**.
- **#6:** zero-operation resources' defense-in-depth policies are now a scheduled
  task, not just prose.
- **#7:** `Repo.aggregate/2` can't take an `Ash.Query`; use `Ash.count!`/`Ash.read`.
- **#8:** includes test now asserts the expected owner is present and enumerates
  real Character-sensitive fields as forbidden.

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

### Actor shapes and the token-only HTTP boundary (revised — review round 2)

**Critical correction.** A previous revision treated the session actor
(`%ActorWithMap{map: nil}`) as trusted/full-access. That is a **cross-tenant
superuser hole**: `CheckJsonApiAuth` checks the session *before* the bearer token
(`authenticate_request/1`), so any logged-in user hitting `/api/v1` would be wrapped
as `map: nil` and — under a trusted bypass — could read/mutate **every** map. That
is worse than the original bug. Reversed.

**Decision: `/api/v1` is token-only.** Remove the session branch from
`CheckJsonApiAuth` so the HTTP surface accepts *only* a map bearer token. This
eliminates the `%ActorWithMap{map: nil}` shape from the HTTP path entirely. We
verified no test or client depends on session-authenticated `/api/v1` traffic.

After this change, the actor shapes are:

1. **API token** — `%ActorWithMap{user: user, map: %{id: _}}`. The *only* HTTP
   actor. Scope to `actor.map.id`.
2. **Internal (in-process only)** — a plain `%User{}` or `%Character{}` passed by
   internal callers (`Map.available(actor: current_user)`,
   `MapDefaultSettings.update(actor: character)`). Trusted via bypass. These never
   arrive over HTTP.

A `%ActorWithMap{map: nil}` must **not** be treated as trusted. If one ever appears
(defensive), it is denied. Anything else (nil actor with `authorize?: true`,
unexpected structs) → deny.

### Policy composition — bypass, not stacked policies (fixes review round 1 #1)

**The original design was wrong.** Ash requires *every applicable policy* to pass.
Two separate `policy` blocks (an unconditional trusted-user policy + an
action-specific map policy) means a token actor fails the trusted policy and a
plain user fails the map policy — **every request is denied.**

Correct structure: a **`bypass`** for trusted actors (if it passes, remaining
policies are skipped), followed by the action policies:

```elixir
policies do
  # Trusted actors (internal User/Character only — NOT session/map:nil)
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

- `MapScoped.Trusted` — a `SimpleCheck` that matches a plain `User` or a plain
  `Character` **only**. It does **not** match `%ActorWithMap{map: nil}` (that shape
  no longer reaches HTTP after the token-only change, and must never be trusted).
  Used only inside `bypass`.
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

### Per-resource route/action matrix (authoritative — review round 2 #2/#3)

Extracted from each resource's `routes do` block. Policies and tests must cover
**only the operations that actually exist**. `C=create, U=update, D=destroy`.

| Resource | Read | C | U | D | Read scope | Write handling |
|---|---|---|---|---|---|---|
| `map` | ✓ | new | ✓ | ✓ | `[:id]` | `write_direct(:id)` |
| `map_system` | ✓ | ✓ | ✓ | ✓ | `[:map_id]` | InjectMapFromActor→**reject 403** on mismatch (#5); `write_direct` for U/D |
| `map_connection` | ✓ | ✓ | ✓ | ✓ | `[:map_id]` | same as map_system |
| `map_subscription` | ✓ | — | — | — | `[:map_id]` | read-only route set |
| `map_user_settings` | ✓ | — | — | — | `[:map_id]` | read-only route set |
| `map_character_settings` | ✓ | — | — | — | `[:map_id]` | read-only route set |
| `map_default_settings` | ✓ | ✓ | ✓ | ✓ | `[:map_id]` | `write_direct(:map_id)` |
| `map_access_list` | ✓ | ✓ | ✓ | ✓ | `[:map_id]` | **token writes forbidden** (ownership op) |
| `map_system_signature` | ✓ | — | — | ✓ | `[:system, :map_id]` | D only: `parent_in_token_map` |
| `map_system_structure` | ✓ | ✓ | ✓ | ✓ | `[:system, :map_id]` | C: parent-query; U/D: `parent_in_token_map` |
| `map_system_comment` | ✓ | — | — | — | `[:system, :map_id]` | **read-only route set** |
| `access_list` | ✓ | new | ✓ | ✓ | `exists(map_access_lists, map_id == ^tok)` | **token writes forbidden** (#5) |
| `access_list_member` | ✓ | ✓ | update_role | ✓ | via `access_list.map_access_lists` | **token writes forbidden** (#5) |
| `user_activity` | ✓ | — | — | — | **token denied** | read denied for tokens |

Notes:
- Only `map`, `map_system`, `map_connection`, `map_default_settings`,
  `map_system_structure` expose token-permitted writes. Signatures expose **delete
  only**; subscriptions/settings/comments are **read-only**; ACLs and
  `map_access_list` are token-write-forbidden.
- A `policy action_type([...])` only fires for actions that exist, so listing
  create/update/destroy on a read-only resource is harmless — but tests must not
  POST/PATCH to routes that don't exist (they 404 at the router, not 403).

**`map_default_settings` (fixes round 1 #2).** Full CRUD, previously missed. Direct
`map_id`. Its `use` block must gain `authorizers: [Ash.Policy.Authorizer]`.

**Zero-operation resources (fixes round 2 #6).** `map_solar_system`, `map_state`,
`ship_type_info`, `user` declare a routes block but expose no operations. They still
get `authorizers: [Ash.Policy.Authorizer]` + a `policies` block:
`bypass Trusted` then `policy always() do forbid_if always() end`. This is
**scheduled as its own task**, not just described — it also governs these resources
when reached as relationship `includes` from a permitted resource.

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

### Cross-map create contract: reject, not coerce (fixes review round 2 #5)

`map_system` and `map_connection` currently use the `InjectMapFromActor` change,
which **force-overwrites** `map_id` to the actor's map. So a create naming another
map would be silently coerced into the caller's own map — not the promised 403, and
an inconsistent contract.

**Decision: reject with 403 on mismatch.** Augment `InjectMapFromActor` (or add a
paired validation) so that when the request supplies a `map_id` that differs from
the token map, the create is **rejected** rather than coerced. When no `map_id` is
supplied, injecting the token map is still fine. The policy layer
(`write_direct(:map_id)`) is the backstop; the change-level rejection produces the
explicit 403 and a clear error field. Tests assert 403 AND that no row was created
in either map.

## Custom endpoint outside the Ash router (fixes review round 1 #7, round 2 #4)

`GET /api/v1/maps/:map_id/systems_and_connections`
(`MapSystemsConnectionsController.show/2`) is a hand-written controller, not an Ash
action, so **policies do not apply**. Two problems:

1. It never compares the path `map_id` to the authenticated token map.
2. `load_map_data/1` calls `Ash.read!` with **no actor** — once policies are live,
   an actor-less read hits deny-by-default (the existing `FilterSystemsByActorMap`
   prep already filters to `false` without map context), so the endpoint would
   return **empty arrays** and silently break.

**Decision:**
- Guard: compare path `map_id` to `conn.assigns.map.id`; mismatch → 404.
- **Pass the actor** (`conn.assigns` actor / the `ActorWithMap`) into both
  `Ash.read` calls so the reads succeed for the token's own map.
- Tests assert the response contains the **expected system and connection IDs**
  (not just HTTP 200 with possibly-empty arrays — a positive control that catches
  the actor-less-read breakage).

## Error behavior

- **Reads** — filter checks silently exclude out-of-scope rows. List returns the
  in-scope subset; `GET /:id` for an out-of-map row returns **404**.
- **Writes** (create/update/destroy) on an out-of-scope row / parent → **403**.
- Cross-map create on `map_system`/`map_connection` → **403** (reject, not coerce).
- Token actor on a token-forbidden resource (ACLs write, `user_activity`) → 404 on
  read-forbidden, 403 on write-forbidden.
- Unknown/nil actor with `authorize?: true` → **403** (deny-by-default).

## Edge cases

1. Session auth is removed from `/api/v1` (token-only), so `%ActorWithMap{map: nil}`
   never reaches HTTP. If it appears defensively → **denied** (not trusted).
2. Create omitting `map_id` → token map injected (fine). Create naming another map →
   **403** (reject).
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

Tests `use WandererAppWeb.ApiCase`, `import WandererAppWeb.Factory`, and
authenticate with `create_authenticated_conn(conn, map)` (sets the Bearer header to
`map.public_api_key`). Harness: two maps, two owners, one token. Missing factories
(`map_subscription`, `map_default_settings`, `map_user_settings`, `user_activity`)
are created via `Ash.create/2` (as `api_case.ex` already does for subscriptions).

**Test only routes that exist** (review round 2 #2). Per the route/action matrix:

- **All 14 resources — read scoping:** list excludes the other map's rows; `GET
  /:id` of an out-of-scope row → 404.
- **Write-capable resources only** (`map`, `map_system`, `map_connection`,
  `map_default_settings`, `map_system_structure`) — for each **existing** write
  action: cross-map → **403**, and a **positive control** on the token's own map
  succeeds.
- **`map_system_signature`** — delete only: cross-map delete → 403; own delete
  succeeds. No POST/PATCH tests (routes don't exist).
- **Token-write-forbidden resources** (`map_access_list`, `access_list`,
  `access_list_member`) — every existing write action via token → 403; a positive
  control that an internal `User`/`Character` actor still mutates.
- **Read-only resources** (`map_subscription`, `map_user_settings`,
  `map_character_settings`, `map_system_comment`) — read scoping only.

**Correct DB assertions (fixes review round 2 #7).** Do **not** use
`WandererApp.Repo.aggregate/2` on an `Ash.Query`. Use `Ash.count!/2` with an Ash
query, `Ash.read!/2`, or an Ecto query against the schema. Example row-absence
check:

```elixir
{:ok, count} = Ash.count(Ash.Query.filter(WandererApp.Api.MapDefaultSettings, map_id == ^other_map.id))
assert count == 0
```

Mutation-unchanged and destroy-preserved checks read the row back via `Ash.get/2`
(or `Ash.read_one`) and assert attributes / presence.

**Non-vacuous includes test (fixes review round 2 #8).** For `?include=owner` on the
token's own map, assert **positively** that `included` contains an entry with the
expected owner `id` and `type`, and assert **negatively** that no entry carries a
Character-sensitive field (enumerate the actual sensitive attributes of the
Character resource, e.g. token/refresh fields — not `hash`, which is a User field).
An empty `included` array must **fail** the test.

Regression / non-breakage:

- One test per audited `actor:` site (User and Character) asserting success.
- Token-only auth: a request with **no** Authorization header (previously would try
  session) → 401.
- Full suite green.

## Verification gate

- `mix test` (targeted v1 + affected internal paths).
- `mix format`, `mix credo` (if configured), `mix compile --warnings-as-errors`.
- Manual: confirm the original exploit (map key listing another map's
  `access_lists` / `map_subscriptions`) now returns only in-scope rows.
