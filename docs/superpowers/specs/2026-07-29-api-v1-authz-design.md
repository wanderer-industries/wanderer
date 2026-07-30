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
8. **`user_activity` and zero-op resources:** hard-forbid for token actors
   (`forbid_if always()` → **403** on every action, including list/GET — not
   filter-to-empty).
9. **Custom endpoint** `.../systems_and_connections`: guard path-map vs token-map
   **and** pass the actor into the reads; tests assert real IDs.
10. **Cross-map create:** rejected via a **create policy** (→ `Ash.Error.Forbidden`
    → 403), NOT a changeset `add_error` (that is `:invalid` → 400/422).
    `InjectMapFromActor` is left unchanged.
11. **Map create is token-forbidden** (`:new` mints a new id; `write_direct(:id)`
    can't apply). Map create policy is `forbid_if always()`; create is not grouped
    with update/destroy.
12. **Policies follow each resource's real route/action matrix** (see the matrix
    table); tests exercise only routes that exist and are written to fail if
    authorization were removed.

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

**Round 3 review** fixed:

- **#1:** `map` has no index route (uses `/:slug`); dropped the nonexistent
  `GET /api/v1/maps` list test, assert read-scoping via `GET /:slug` → 404.
- **#2:** anti-vacuous-test rules — seed out-of-scope rows, forbid "has-id"
  acceptance, `Ash.get` matched to `{:ok, %Resource{}}` not `{:ok, _}`, real
  defense-in-depth assertions.
- **#3:** map creation is **token-forbidden** (`:new` mints a new id, so
  `write_direct(:id)` is unsatisfiable); create is not grouped with update/destroy.
- **#4:** cross-map create rejection is **policy-based** (403), not a changeset
  `add_error` (which is `:invalid` → 400/422); `InjectMapFromActor` left unchanged.
- **#5:** concrete per-resource test matrix replaces representative prose.
- **#6:** Task 0 also updates the plug moduledoc (drops the session claim); the
  `User` alias remains used by the token path (line 149), so no unused-alias warning.
- **#7:** all six audited internal call sites get direct regression tests.

**Round 4 review** fixed:

- **#1:** resolved the `user_activity` policy/test contradiction — decision is
  **hard 403** (`forbid_if always()`); tests assert 403 on list and GET, not
  200/404.
- **#2:** `map` PATCH/DELETE use the **primary-key route `/maps/:id`** (only GET is
  slug-based); tests target `foreign.id`, with foreign/own slug GET as separate
  cases.
- **#3:** `user_activity` fixture uses a valid `event_type: :map_added` (not the
  nonexistent `:map_created`), `entity_type: :map`.
- **#4:** defense-in-depth requires **`%Ash.Error.Forbidden{}` exclusively** and
  seeds a row per resource — no `{:ok, []}` acceptance.
- **#5:** every matrix row is a mandatory executable assertion (explicit instruction
  added); snippets are starting points, not the full set.
- **#6:** removed `inject_map_from_actor.ex` from Task 2's file list (it is left
  unchanged).
- **#7:** includes test asserts the exact `{id, type}` pair.

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
| `map` | GET `/:slug` only (no index) | new | ✓ | ✓ | `[:id]` | **create token-forbidden** (#3); scoped U/D |
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
| `user_activity` | ✓ | — | — | — | **403 all token actions** | 403 |

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

### Cross-map create contract: policy-based 403, not a changeset error (fixes review round 2 #5, round 3 #4)

`map_system` and `map_connection` use the `InjectMapFromActor` change, which
force-overwrites `map_id` to the actor's map — so a create naming another map is
silently coerced. We want an explicit **403**.

**Mechanism decision (corrected round 3):** do this with a **policy**, not a
changeset `add_error`. `Ash.Changeset.add_error` produces an `:invalid`-class error,
which AshJsonApi maps to **400/422, not 403** (verified: `InvalidAttribute` has
`class: :invalid`). Only an authorization failure yields `Ash.Error.Forbidden` →
**403**. Therefore:

- Add a **create policy** on `map_system`/`map_connection`:
  `MapScoped.CreateMapMatchesToken` — a `SimpleCheck` that reads the **supplied**
  `map_id` from the changeset params/attributes and authorizes only if it is absent
  (will be injected) **or** equals the token map. A supplied foreign `map_id` →
  policy fails → 403.
- **Do not modify `InjectMapFromActor`.** It still injects the token map when none is
  supplied; the policy handles the mismatch-rejection. This keeps the shared change
  untouched (it's used by internal callers too).

Tests assert 403 AND that no row was created in either map (via `Ash.count/2`).

### Map creation is token-forbidden (fixes review round 3 #3)

`POST /maps` runs the `:new` action, which mints a **new** map with a new `id`.
`write_direct(:id)` (which requires the row's `id` to equal the token map's existing
`id`) can therefore never pass on create — map creation would be permanently broken.

**Decision: map creation is token-forbidden.** Map lifecycle-create is an
account-level operation performed via the web app (a trusted `User`/`Character`
actor, allowed by the `Trusted` bypass). So `map`'s policies are:

```elixir
policies do
  bypass MapScoped.Trusted do authorize_if always() end
  policy action_type(:read)    do authorize_if MapScoped.in_token_map([:id]) end
  policy action_type(:create)  do forbid_if always() end          # token-forbidden
  policy action_type([:update, :destroy]) do authorize_if MapScoped.write_direct(:id) end
end
```

Do **not** group create with update/destroy for `map`.

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
- **Hard-forbidden resources** (`user_activity` and the zero-op resources
  `map_solar_system`/`map_state`/`ship_type_info`/`user`) use `forbid_if always()`
  for token actors: **every** token action — list, GET, write — returns **403**
  (not 404/empty). This is a deliberate "you may not touch this" signal, distinct
  from the map-scoped resources' filter-to-empty behavior.
- ACL/`map_access_list` **writes** by token → **403** (reads are filter-scoped →
  404/empty).
- Unknown/nil actor with `authorize?: true` → **403** (deny-by-default).

## Edge cases

1. Session auth is removed from `/api/v1` (token-only), so `%ActorWithMap{map: nil}`
   never reaches HTTP. If it appears defensively → **denied** (not trusted).
2. Create omitting `map_id` → token map injected (fine). Create naming another map →
   **403** via create policy (not a changeset error). `POST /maps` → 403 (map create
   token-forbidden).
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
authenticate with `create_authenticated_conn(conn, map)` (Bearer =
`map.public_api_key`). Harness: two maps, two owners, one token. Missing factories
(`map_subscription`, `map_default_settings`, `map_user_settings`,
`map_character_settings`, `user_activity`) are created via `Ash.create/2`.

### Anti-vacuous-test rules (fixes review round 3 #2)

Every negative test must be constructed so it would **fail if authorization were
removed**:

1. **Seed the out-of-scope data first.** A "returns `[]`" test must create a row in
   the other map/account, then assert that specific row's id is absent — never
   assert `== []` against an empty table (`user_activity`, comments included).
2. **No "has an id" acceptance.** Do not assert `Enum.all?(data, & &1["id"])`.
   Assert the specific foreign row id is **not** in the returned ids.
3. **Destroy checks use `Ash.get` pattern-matched to a row, not `{:ok, _}`.**
   `Ash.get(Resource, id, authorize?: false)` returns `{:ok, nil}` for a missing
   row, so `{:ok, _}` passes vacuously. Assert `{:ok, %Resource{}}` (record present)
   after a forbidden delete, and `{:ok, nil}` (or `:error`) after a permitted one.
4. **Defense-in-depth is a real assertion, not a placeholder.** Seed a row in each
   zero-op resource and assert a token cannot read it (direct route → 404/403, or
   via include → absent), and that the include of `owner` omits sensitive fields.

### Concrete per-resource matrix (fixes review round 3 #5)

Each row is an explicit test; `map` has **no index route** (uses `/:slug`) so its
"list" test is omitted and read scoping is asserted via `GET /:slug` of a foreign
map → 404.

| Resource | Tests |
|---|---|
| `map` | GET `/maps/:foreign_slug` → 404; own `/:slug` → 200; POST `/maps` (token) → 403; **PATCH/DELETE use the primary-key route `/maps/:id`** (not slug): PATCH `foreign.id` → 403, DELETE `foreign.id` → 403 (+ `Ash.get` still present), own PATCH `map.id` → 200 |
| `map_system` | list excludes foreign; GET foreign → 404; own create → 201; create with foreign `map_id` → 403 (+count 0); foreign PATCH/DELETE → 403; own DELETE → 200 (row gone) |
| `map_connection` | same matrix as `map_system` |
| `map_default_settings` | list excl; GET foreign → 404; own C/U/D succeed; foreign create → 403 (+count 0); foreign U/D → 403 |
| `map_subscription`, `map_user_settings`, `map_character_settings` | seed foreign row; list excludes it; GET foreign → 404 (read-only routes only) |
| `map_access_list` | list excl; GET foreign → 404; token C/U/D → 403; internal `User` C succeeds (positive) |
| `map_system_signature` | seed foreign sig; list excl; GET foreign → 404; DELETE foreign → 403 (+ present); own DELETE → 200 (gone) |
| `map_system_structure` | list excl; GET foreign → 404; own create (valid `system_id`) → 201; create with foreign system → 403; foreign U/D → 403; own U/D → 200 |
| `map_system_comment` | seed foreign comment; list excludes it; GET foreign → 404 (read-only) |
| `access_list` | linked read ✓ / unlinked → 404; token new/PATCH/DELETE → 403; internal `User` mutate succeeds |
| `access_list_member` | seed member under foreign ACL; list excl; token create/update_role/DELETE → 403; internal succeeds |
| `user_activity` | **hard-forbid**: token list → **403**, token GET → **403** (not 404/empty). Use a valid seed (`event_type: :map_added`, `entity_type: :map`) so the row is real |
| zero-op (`map_solar_system`,`map_state`,`ship_type_info`,`user`) | **seed one row per resource**; token authorized read → **`%Ash.Error.Forbidden{}` exclusively** (do NOT accept `{:ok, []}`) |

**Correct DB assertions.** Never `Repo.aggregate/2` on an `Ash.Query`. Use
`Ash.count/2`, and for presence `Ash.get(Resource, id, authorize?: false)` matched
to `{:ok, %Resource{}}` / `{:ok, nil}`.

**Every matrix row is mandatory (fixes review round 4 #5).** The table above is not
illustrative — the implementer must write a distinct test case (or a clearly-named
assertion) for **every cell**: each resource's list, GET-by-id, and each *existing*
write action, for both foreign (deny) and own (positive control) paths. A task is
not complete while any listed row lacks an executable assertion. The plan's code
snippets are starting points to be expanded to the full matrix, not the full set.

### Non-vacuous includes test

For `?include=owner` on the token's own map: assert `included` **contains** an entry
whose **`id` equals the expected owner id AND `type` equals the expected JSON:API
resource type** (assert both fields explicitly, e.g. `%{"id" => owner_id, "type" =>
"characters"}` — verify the actual type string from the resource's `json_api do type
...`), and that **no** included entry carries a Character-sensitive attribute.
Enumerate the real sensitive fields from `character.ex` (token/refresh fields; some
are `AshCloak`-encrypted) — verify names before finalizing. An empty `included` must
**fail** the test.

### Regression / non-breakage (fixes review round 3 #7)

One direct test per audited internal `actor:` site — all six:

- `Map.available(actor: user)` (User)
- `AccessList.available(actor: user)` (User)
- `map_repo.ex:39` `Ash.load(:user_permissions, actor: user)` (User)
- `maps_live.ex:734` `Ash.load!(:user_permissions, actor: user)` (User) — exercise
  via the load call directly with a User actor
- `map_core_event_handler` `MapDefaultSettings.update` **and** `create` (Character)
- `map_api_controller.ex:1373` `Map.duplicate(actor: user)` (User)

Plus: token-only auth — a request with **no** Authorization header → 401. Full suite
green.

## Verification gate

- `mix test` (targeted v1 + affected internal paths).
- `mix format`, `mix credo` (if configured), `mix compile --warnings-as-errors`.
- Manual: confirm the original exploit (map key listing another map's
  `access_lists` / `map_subscriptions`) now returns only in-scope rows.
