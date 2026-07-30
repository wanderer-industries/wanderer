# Handover: /api/v1 Authorization Hardening

**Branch:** `worktree-api-v1-authz`
**Status:** Design + implementation plan complete and reviewed (4 review rounds). **No production code written yet** — this is a planning handover.
**Date:** 2026-07-29

## TL;DR

The `/api/v1` JSON:API surface has **no framework-level authorization**. A map API
token resolves to the map owner's full user actor, and only a few resources have
hand-written map-scoping filters — so a single map's key can read (and sometimes
write) other maps' and accounts' data. This branch contains a validated design and
a task-by-task TDD plan to make every `/api/v1` resource deny-by-default and scope
map tokens to a single map.

## Where things are

| Artifact | Path | Commit |
|---|---|---|
| Design spec | `docs/superpowers/specs/2026-07-29-api-v1-authz-design.md` | `d314ba13` |
| Implementation plan | `docs/superpowers/plans/2026-07-29-api-v1-authz.md` | `a1ba3209` |
| This handover | `docs/superpowers/handovers/2026-07-29-api-v1-authz-handover.md` | (this commit) |

Read the **design first**, then the **plan**. The plan is written for a worker with
zero context and is executable task-by-task.

## The problem (verified against code)

- No Ash resource in `lib/wanderer_app/api/` declares an authorizer; no `policies`
  blocks exist. The domain (`lib/wanderer_app/api.ex`) has no `authorization` block.
- `CheckJsonApiAuth` (`lib/wanderer_app_web/controllers/plugs/check_json_api_auth.ex`)
  maps a map API key → the map **owner user**, wrapped as `ActorWithMap{user, map}`.
- `ApiV1Router` forwards to all Ash resources. Scoping exists only as ad-hoc
  `prepare` filters on a handful of read actions (`map_system`, `map_connection`).
- Result: `access_lists`, `map_subscriptions`, settings, signatures, structures,
  etc. are reachable/mutable across maps by any token.

The legacy `/api/*` surface (via `CheckMapApiKey`) is genuinely map-scoped and is
out of scope. ACL API keys work only on legacy `/api/acls/*`.

## The solution (key decisions)

1. **Deny-by-default Ash policies** (`Ash.Policy.Authorizer`) on every route-exposed
   resource.
2. **Domain gate `authorize :when_requested`** — policies fire when a caller passes
   `actor:`/`authorize?: true`. AshJsonApi always does; most internal calls don't.
   (Verified in Ash source: under `:when_requested`, passing `actor:` alone triggers
   authorization.)
3. **`/api/v1` is token-only** — the session auth branch is removed from
   `CheckJsonApiAuth`. Session auth would wrap any logged-in user as
   `ActorWithMap{map: nil}`; treating that as trusted was a cross-tenant superuser
   hole. The only HTTP actor is a scoped token.
4. **Policy composition is a `bypass` for trusted actors, then action policies** —
   NOT stacked `policy` blocks (Ash requires all applicable policies to pass, which
   would deny everyone).
5. **Actor shapes:** API token `ActorWithMap{map: %{id}}` → scoped to `map.id`;
   internal in-process `User` or `Character` → trusted via bypass;
   `ActorWithMap{map: nil}` → denied.
6. **Per-resource scoping** follows each resource's **real** route/action matrix
   (see the design's matrix table). Direct `map_id`, parent-`system` path, or ACL
   join-path as appropriate.
7. **ACLs are read-only for token actors** (mutation stays on legacy `/api/acls`);
   `map_access_list` writes token-forbidden.
8. **`user_activity` and zero-op resources are hard-forbidden** for tokens
   (`forbid_if always()` → 403 on all actions).
9. **Map create is token-forbidden** (`:new` mints a new id; `write_direct(:id)`
   can't apply). Map create/update/destroy are not grouped.
10. **Cross-map create is rejected by a policy** (`create_map_matches_token` →
    `Ash.Error.Forbidden` → 403), NOT a changeset `add_error` (that's `:invalid` →
    400/422). `InjectMapFromActor` is left unchanged.
11. **Custom endpoint** `/api/v1/maps/:map_id/systems_and_connections` (a
    hand-written controller, not Ash) gets a path-map-vs-token-map guard AND the
    actor passed into its `Ash.read` calls.

## Plan shape (8 tasks, TDD)

- **Task 0:** make `/api/v1` token-only (remove session branch; moduledoc cleanup).
- **Task 1:** shared `WandererApp.Api.Policies.MapScoped` checks (`Trusted` bypass,
  `InTokenMap`/`ParentInTokenMap` filter checks, `WriteDirect`,
  `CreateParentInTokenMap`, `CreateMapMatchesToken`).
- **Task 2:** domain gate + direct-`map_id` resources + map-create-forbidden +
  policy-based cross-map create.
- **Task 3:** `system`-path resources (signature delete-only, comment read-only,
  structure full CRUD).
- **Task 4:** ACL resources token-read-only + `user_activity` hard-forbidden.
- **Task 5:** defense-in-depth deny policies for zero-op resources.
- **Task 6:** custom endpoint guard + actor propagation.
- **Task 7:** internal non-breakage regression (all 6 audited `actor:` sites) +
  non-vacuous includes test + full verification gate.

## Review history

Four review rounds, each verified against code before incorporating. Summary of
what each caught (full detail in the design's "Revision note" section):

- **Round 1:** broken policy composition (stacked → bypass); missed
  `map_default_settings`; unsound relationship-path write checks; ACL write
  semantics; non-proving tests; unguarded custom endpoint; wrong factory module;
  Character actor shape.
- **Round 2 (critical):** session `map: nil` actor treated as trusted was a
  cross-tenant superuser hole → made `/api/v1` token-only. Plus real route/action
  matrix; custom endpoint actor propagation; reject-not-coerce create; scheduled
  defense-in-depth; `Ash.count` (not `Repo.aggregate`); non-vacuous includes.
- **Round 3:** `map` has no index route (uses `/:slug`); anti-vacuous test rules;
  map-create-forbidden; 403-via-policy-not-add_error; per-resource matrix; all six
  regression sites.
- **Round 4:** hard-403 vs filter-empty contradiction (chose hard 403); map
  PATCH/DELETE use `/:id` not `/:slug`; valid `:map_added` fixture; defense-in-depth
  requires `Forbidden` exclusively; full-matrix mandate; includes `{id, type}`
  assertion.

The trend is convergent: round 1 restructured the approach, round 4 was almost
entirely test-fidelity.

## Open items for the implementer (each has a fallback in the plan)

These are quick to confirm during implementation, not blockers:

1. **`Ash.Expr.ref/1,2` dynamic filter construction** in `MapScoped.InTokenMap` —
   if it misbehaves, replace with per-pattern modules using literal
   `expr(map_id == ^map_id)` / `expr(system.map_id == ^map_id)`, same builder names.
2. **Exact Character sensitive-field names** for the includes-leak test (token/
   refresh fields; some AshCloak-encrypted) — verify in `character.ex`.
3. **The `owner` JSON:API type string** (`"characters"` assumed) — verify from the
   owner resource's `json_api do type ... end`.
4. **`Map.duplicate` argument shape** for the regression test — verify in `map.ex`.
5. **Missing factories** (`map_subscription`, `map_default_settings`,
   `map_user_settings`, `map_character_settings`, `user_activity`) — create via
   `Ash.create/2` in-test or add to `test/support/factory.ex`
   (`WandererAppWeb.Factory`).
6. Confirm `access_list` declares `has_many :map_access_lists` (inverse of the join)
   so `exists(map_access_lists, ...)` resolves; add it if missing.

## Internal call-site audit (blast radius)

Sites passing `actor:` that become enforced under `:when_requested` — all pass a
`User` or `Character`, so the `Trusted` bypass covers them; each has a regression
test in Task 7:

- `lib/wanderer_app/maps.ex:17` — `Map.available(actor: user)`
- `lib/wanderer_app/acls.ex:12` — `AccessList.available(actor: user)`
- `lib/wanderer_app/repositories/map_repo.ex:39` — `Ash.load(:user_permissions, actor: user)`
- `lib/wanderer_app_web/live/maps/maps_live.ex:734` — `Ash.load!(:user_permissions, actor: user)`
- `lib/wanderer_app_web/live/map/event_handlers/map_core_event_handler.ex:375,379` — `MapDefaultSettings.update/create(actor: character)`
- `lib/wanderer_app_web/controllers/map_api_controller.ex:1373` — `Map.duplicate(actor: user)`

## How to execute

Use `superpowers:subagent-driven-development` (fresh subagent per task, review
between) or `superpowers:executing-plans` (inline with checkpoints). Each task is
TDD: write failing test → run → implement → run → commit. Gate every commit with
`mix compile --warnings-as-errors` and the task's tests; full `mix test` at Task 7.

**Ordering note:** Task 0 (token-only) and Task 1 (checks) precede Task 2, which
lands the domain gate atomically with the first protected resource group (a resource
under an enabled gate but without policies would forbid authorized calls).

## Verification the fix works

After implementation, confirm the original exploit is closed: a token for map A
requesting `/api/v1/access_lists` and `/api/v1/map_subscriptions` returns only
in-scope rows, and a request with no Authorization header returns 401.
