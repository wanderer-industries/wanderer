# Handover: /api/v1 Authorization Hardening — session 3 (COMPLETE)

**Branch:** `worktree-api-v1-authz`
**Worktree:** `/worktrees/api-v1-authz`
**PR:** https://github.com/wanderer-industries/wanderer/pull/633 (upstream `main`)
**Status:** Tasks 0–7 ALL COMPLETE. Plan fully executed.
**Date:** 2026-08-01

> **Correction:** the session-2 handover said "PR #99". That was wrong — #99 is an
> unrelated merged ARM64 Docker revert. No PR existed for this branch until #633.

## What landed

| Task | Commit | What |
|---|---|---|
| 0 | `ab397f93` | `/api/v1` token-only; session branch removed from `check_json_api_auth.ex` |
| 1 | `24f03eb9`, `e6f60aae`, `1a598fb3` | `MapScoped` policy checks |
| 2 | `037a2b3c` | Domain gate + policies on direct-`map_id` resources |
| 3 | `d790f8df` | System-child resources (signature / comment / structure) |
| 4 | `4bedfc34` | `AclScoped`; ACL read-only + `user_activity` hard-403 |
| 5 | `adf29c03` | Deny-all for the four zero-route resources |
| 6 | `bf57588f` | Custom endpoint guard + actor propagation |
| 7 | `227e8aea` | Internal regression + includes-leak suites |
| — | `ffd357e7` | **Bonus:** fixed map duplication 500 (pre-existing, unrelated) |

**Verification:** ~110 new tests across 7 authz suites, all mutation-verified.
Full suite vs merge-base `b7ddbc48`: **zero new failures, six fixed.**

## Binding decisions (do not revisit silently)

1. **Foreign `map_id` on create → 403.** Intentional breaking change vs Nov-2025
   behaviour (silent override → 201). `InjectMapFromActor` unmodified. Called
   out in the PR body.
2. **Foreign PATCH/DELETE → 404, not 403.** Filter checks make the row
   invisible. Amends the plan's "writes → 403" constraint.
3. **ACL writes → 403 even on a *linked* ACL**, and `user_activity` /zero-op
   resources → 403 on every action. These are `forbid_if always()` hard
   denials, deliberately NOT filters. **Do not homogenize these with #2.**

## Hard-won facts

1. **`MapScoped` filters return KEYWORD LISTS** (`[map_id: v]`,
   `[system: [map_id: v]]`). Dynamic `Ash.Expr.ref/2` does **not** work across
   relationship paths. Do not reintroduce it.
   *But:* `AclScoped` uses literal `expr(exists(...))`, which is fine — the ban
   is on *dynamically built* refs. Static paths are safe, and keyword lists
   cannot express `exists`.
2. **Use FILTER checks for update/destroy, not `write_direct/1`.**
   SimpleCheck → `requires_original_data? -> true` → disqualifies `:atomic` →
   PATCH fails `NoMatchingBulkStrategy` → DELETE falls to `:stream` →
   `Ash.Query.select([])` re-read → `%Ash.NotLoaded{}` → `Protocol.UndefinedError`
   in response rendering. `WriteDirect` still exists for `map_default_settings`
   create — do not delete it.
3. **`MapSystem`'s primary `:read` has an always-on `FilterSystemsByActorMap`
   preparation** (`map_system.ex:205`) that independently map-scopes reads. It
   **confounds policy tests** — a round-trip can pass with the policy fully
   broken. Assert raw filter values or use an action that bypasses it.
4. **`simple_sat` is a required runtime dep** of Ash's policy authorizer.
5. **Composition is `bypass Trusted` then action policies.** Never stack
   unconditional `policy` blocks — Ash requires *all* to pass.
6. **NEVER pattern-match structs in a policy check module.** `Trusted` matched
   `%Api.User{}`; struct patterns expand at COMPILE time, so the module depended
   on `Api.User`. Once `User` gained a policy referencing it, the cycle closed
   and `mix compile --force` died with 24× *"deadlocked waiting on struct"*.
   Use `is_struct(actor, Mod)` guards (runtime, equivalent).
7. **`authorize :when_requested` authorizes ONLY when an `actor:` key is
   present** (`ash/lib/ash/actions/helpers.ex:390`). Actor-less internal reads
   skip authorization entirely — which is why deny-all on reference data is
   safe, and why a bare `Ash.read!()` in a controller is a hole.

## Test-shape gotchas (cost real time)

- **Reload actors the way production does.** `FilterMapsByRoles` reads
  `actor.characters`; a bare factory `User` has `%Ash.NotLoaded{}` and crashes.
  Use `User.by_id(id, load: :characters)` as `CheckJsonApiAuth` does.
- **`Map.duplicate` takes a Character, not a User.** The controller passes
  `conn.assigns[:current_character]`, and the action sets `owner_id` from
  `context.actor.id` where `Map.owner` is a Character FK.
- **`:available` is never called with a Character** — only `User`.
- **`Character` is NOT an AshJsonApi resource** (`extensions: [AshCloak]` only).
  `?include=owner` returns `"type": null` with **empty attributes**; no Character
  field serializes. Assert absence of sensitive attrs, not the type name.
- **The `insert(:map_system_comment, ...)` factory is stale** — passes
  `map_id`/`solar_system_id`/`position_*`, but `:create` accepts only
  `system_id`/`character_id`/`text` → `NoSuchInput`. Create comments directly.
  *Worth a follow-up fix.*

## Environment

- Devcontainer; test DB is compose service `db`. `config/runtime.exs:9` overrides
  `test.exs`'s `localhost` via `DB_HOST=db`.
- Integration tests excluded by default → `mix test --include integration`.
- `mix compile --warnings-as-errors` **already fails at baseline** (7 pre-existing
  warnings). Real gate: no NEW warnings in touched files.
- **Always `mix compile --force`** before trusting a run — stale artifacts
  produced a phantom *"WandererApp.Api is not a Spark DSL module"* failure.
- **Never hand-delete `_build` subdirs.** `rm -rf _build/test/.../ebin` corrupts
  the test build (*"module WandererAppWeb is not loaded"*). Recover with
  `rm -rf _build/test && MIX_ENV=test mix compile --force`.
- **`mix test --include integration` is UNSTABLE at full-suite scope** — 14, 15
  and 25 failures observed on an *unchanged* tree. Per-suite runs are
  deterministic. Never claim a bare failure count.
  **Baseline method:** `git worktree add /tmp/baseline-check b7ddbc48`, symlink
  `deps`, `MIX_ENV=test mix compile`, run, and `comm` the sorted failure-name
  lists.

## Open items

1. **`CharacterLocationTrackingTest` (8 failures)** — diagnosed, not fixed.
   Prompt: `docs/superpowers/prompts/2026-08-01-character-location-tracking-fix.md`
2. **`MapRepo.get/2` masks errors** (`repositories/map_repo.ex:24`) — flattens any
   error to `{:error, :not_found}`. This masking cost most of the flaky-suite
   diagnosis. Worth fixing independently.
3. **Stale `map_system_comment` factory** (see above).

## Process note

Four delegated subagents stalled across sessions 2 and 3 — going silent for
1–2 hours, or emitting only `idle_notification` pings with no findings. Both
Task 2 and the session-3 failure diagnosis were ultimately done in-session,
which worked. **Prefer working in-session; if you do delegate, set a hard
timeout and take over rather than re-dispatching.**

Check liveness with `ps -eo pid,etime,args | grep -E "beam.smp|/mix "` plus file
mtimes. No process and no recent writes means stalled, not thinking.

The *review* loop (as opposed to implementation delegation) did work well and is
worth keeping — reviewers caught a critical `ref/2` crash and a vacuous test that
a green 18/18 suite had hidden.
