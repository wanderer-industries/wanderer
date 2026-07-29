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
3. **Token scope:** strictly single-map — a map token reaches only its own map and
   that map's child resources.
4. **Rollout:** all route-exposed resources at once, via a shared policy helper.
5. **ACL scope:** a map token may read/write an `AccessList` (and its members) only
   if that ACL is linked to the token's map through `map_access_lists`.

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

### Two actor shapes

Every policy must handle:

- **Plain `User`** — internal calls (`Map.available(actor: current_user)`, etc.).
  `authorize_if always()` — preserves current trusted behavior.
- **`ActorWithMap`** (API token) — filter/relationship checks scope to
  `actor.map.id`.
- **Any other / nil actor** with `authorize?: true` → falls through to default
  `forbid` (deny-by-default).

### Shared policy helper

New module `WandererApp.Api.Policies.MapScoped` provides reusable checks so each
resource's `policies` block stays small:

- `trusted_user/0` — a check that authorizes when the actor is a plain `User`
  (not `ActorWithMap`).
- `in_token_map/1` — a **filter check** producing an Ash filter that scopes rows to
  the token's map along a declared path. Filter (not simple) so list endpoints
  return the in-scope subset rather than 403.
- A changeset check for create/update/destroy verifying the target row / incoming
  `map_id` belongs to the token's map.

Per-resource skeleton:

```elixir
policies do
  policy always() do
    authorize_if MapScoped.trusted_user()
    authorize_if MapScoped.in_token_map(:map_id)
  end
end
```

The helper reuses `WandererApp.Api.ActorHelpers.get_map/1` to extract the map from
context.

### Per-resource map path

| Resource | Path to token map |
|---|---|
| `map` | `id == actor.map.id` |
| `map_system`, `map_connection` | `map_id == actor.map.id` |
| `map_subscription`, `map_user_settings`, `map_character_settings`, `map_access_list` | `map_id == actor.map.id` |
| `map_system_signature`, `map_system_structure`, `map_system_comment` | via `system.map_id == actor.map.id` |
| `access_list` | `exists(map_access_lists, map_id == actor.map.id)` |
| `access_list_member` | via `access_list.map_access_lists` linked to token map |
| `user_activity` | scope to `actor.map.id` if a clean map/entity link exists; otherwise forbid for token actors |

Two linkage facts to confirm during implementation, each with a safe
forbid-for-token fallback:

- `user_activity`'s exact map linkage (`belongs_to :character`, `belongs_to :user`;
  no direct `map_id`).
- `access_list_member` reads through the ACL → `map_access_lists` join path.

## Error behavior

- **Reads** — filter checks silently exclude out-of-scope rows. List returns the
  in-scope subset; `GET /:id` for an out-of-map row returns **404** (matches the
  existing `map_system` v1 test expectation).
- **Writes** (create/update/destroy) on an out-of-scope row → **403 Forbidden**.
- Unknown/nil actor with `authorize?: true` → **403** (deny-by-default).

## Edge cases

1. `ActorWithMap` with `map: nil` → no scope → forbid for the token branch.
2. Create where body omits `map_id` → changeset check derives it from
   `actor.map.id`, or forbids on mismatch. Never allow a create to land in
   another map.
3. Relationship-path resources (signatures/structures/comments) with a null parent
   `system` → forbid.
4. `includes` / compound documents (`?include=owner,characters`) — included
   relationships are authorized by Ash. Verify includes of account data (owner
   user) do not leak; restrict includable fields if they do.

## Internal call-site audit (blast radius)

Sites passing `actor:` (a plain `User`) that become enforced under
`:when_requested`; each must still succeed via the `trusted_user` branch and be
covered by a regression test:

| Site | Call |
|---|---|
| `lib/wanderer_app/maps.ex:17` | `Map.available(%{}, actor: current_user)` |
| `lib/wanderer_app/acls.ex:12` | `AccessList.available(%{}, actor: current_user)` |
| `lib/wanderer_app/repositories/map_repo.ex:39` | `Ash.load(..., :user_permissions, actor: current_user)` |
| `lib/wanderer_app_web/live/maps/maps_live.ex:734` | `Ash.load!(:user_permissions, actor: current_user)` |
| `lib/wanderer_app_web/live/map/event_handlers/map_core_event_handler.ex:375,379` | `MapDefaultSettings.update(..., actor: actor)` |
| `lib/wanderer_app_web/controllers/map_api_controller.ex:1373` | `Map.duplicate(map_attrs, actor: current_user)` |

Sites passing `authorize?: false` (explicit bypass, unaffected): `map_pings_repo.ex:45`,
`map_audit_api_controller.ex:136`.

## Testing strategy

Reuse the harness in `test/integration/api/v1/map_system_api_v1_test.exs`
(two maps, two owners, one token).

Per exposed resource — cross-map matrix:

1. Read list — token for map A returns only map-A rows.
2. Read by id — `GET /:id` of a map-B row → 404.
3. Create — body `map_id = B` (or parent in B) → 403 (or coerced to A; assert never
   lands in B).
4. Update — patch a map-B row → 403, unchanged.
5. Destroy — delete a map-B row → 403, still present.

Special cases:

- `access_list` — token for A reads an ACL linked to A; cannot read an ACL linked
  only to B.
- `access_list_member` — same, through the join path.
- `user_activity` — out-of-scope excluded (or forbidden if unlinkable).
- Includes leak test — `?include=owner` does not expose another account's data.

Regression / non-breakage:

- Internal-path tests for each audited `actor:` site — assert they still succeed.
- Full suite green.

## Verification gate

- `mix test` (targeted v1 + affected internal paths).
- `mix format`, `mix credo` (if configured), `mix compile --warnings-as-errors`.
- Manual: confirm the original exploit (map key listing another map's
  `access_lists` / `map_subscriptions`) now returns only in-scope rows.
