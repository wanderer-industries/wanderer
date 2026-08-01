# Handover: /api/v1 Authorization Hardening — session 2

**Branch:** `worktree-api-v1-authz` (PR #99)
**Worktree:** `/worktrees/api-v1-authz`
**Status:** Tasks 0, 1, 2 COMPLETE and committed. Tasks 3–7 remain.
**Date:** 2026-08-01

## Start here

Read, in order:

1. `docs/superpowers/specs/2026-07-29-api-v1-authz-design.md` — the design.
2. `docs/superpowers/plans/2026-07-29-api-v1-authz.md` — the 8-task plan.
3. `.superpowers/sdd/2026-07-29-api-v1-authz/progress.md` — the SDD ledger
   (gitignored; it is the authoritative record of what happened).

Then read the **Decisions** and **Hard-won facts** sections below. They are not
in the plan and will cost you hours to rediscover.

## What is done

| Task | Commit | What landed |
|---|---|---|
| 0 | `ab397f93` | `/api/v1` token-only; session-auth branch removed from `check_json_api_auth.ex` |
| 1 | `24f03eb9`, `e6f60aae`, `1a598fb3` | `WandererApp.Api.Policies.MapScoped` checks |
| 2 | `037a2b3c` | Domain gate `authorize :when_requested` + policies on all direct-`map_id` resources |

Also `4542eb00` (chore: gitignore `.superpowers`).

Verified state at `037a2b3c`, measured on a frozen tree after `mix compile --force`:

- 25/25 new authz matrix tests pass (`test/integration/api/v1/authz_direct_map_test.exs`)
- Full integration suite: **13 failures, identical to the pre-branch baseline** (zero new)
- Unit suites 82/82
- Exactly the 7 pre-existing compile warnings, none new

## Remaining tasks

- **Task 3** — `system`-path resources: `map_system_signature` (delete-only),
  `map_system_comment` (read-only), `map_system_structure` (full CRUD).
  Brief already extracted: `.superpowers/sdd/2026-07-29-api-v1-authz/task-3-brief.md`
- **Task 4** — ACL resources token-read-only (`AclScoped`) + `user_activity` hard-403
- **Task 5** — defense-in-depth deny-all for zero-op resources
  (`map_solar_system`, `map_state`, `ship_type_info`, `user`); must raise
  `Ash.Error.Forbidden` exclusively
- **Task 6** — custom endpoint `/api/v1/maps/:map_id/systems_and_connections`:
  path-map-vs-token-map guard + actor propagation into its `Ash.read` calls
- **Task 7** — internal-caller regression tests (6 audited `actor:` sites),
  non-vacuous includes-leak test, full verification gate

## DECISIONS the human made (binding — do not revisit silently)

**1. Foreign `map_id` on create → 403.** `POST /api/v1/map_systems` (and
`map_connections`) carrying a foreign `map_id` now returns **403** and creates
nothing. Previously `InjectMapFromActor` silently overrode it and returned 201
(behavior tested since Nov 2025). This is an **intentional breaking API change**
and must be called out in the PR description. The old test at
`map_system_api_v1_test.exs` was renamed and rewritten to assert 403 + count 0 in
both maps. Omitting `map_id` still injects the token map → 201, and now has an
explicit positive-control test. **`InjectMapFromActor` is unmodified.**

**2. Foreign PATCH/DELETE returns 404, NOT 403.** The plan's global constraint
says "writes → 403". That constraint is **amended**: out-of-scope writes on
filter-checked resources return **404**. Rationale below under hard-won facts.
**Later tasks must expect 404 and must not "fix" this back to 403.**

## HARD-WON FACTS (each cost real debugging time)

**1. `MapScoped` filters return KEYWORD LISTS**, e.g. `[map_id: v]`,
`[system: [map_id: v]]` — not Ash exprs. Dynamic `Ash.Expr.ref/2` **does not work
across relationship paths**; it raises `Invalid reference ... at relationship_path`.
Its signature is `ref(path, name)` (path first). Do not reintroduce it.

**2. Use FILTER checks for update/destroy, not the `write_direct/1` SimpleCheck.**
This is the cause of decision 2 and the single most expensive thing to rediscover.
Full causal chain:
`write_direct/1` is a SimpleCheck needing `requires_original_data? -> true`
→ that disqualifies Ash's `:atomic` bulk strategy
→ PATCH fails with `NoMatchingBulkStrategy` (400, *not* an authz denial)
→ DELETE falls back to the `:stream` path
→ `deps/ash/lib/ash/actions/destroy/bulk.ex:1009` does `Ash.Query.select([])` on
the re-read batch
→ the destroyed record returns pkey-only
→ `MapSystem`'s `@derive {Jason.Encoder, only: [...:name...]}` hits
`%Ash.NotLoaded{field: :name}`
→ `Protocol.UndefinedError` in `AshJsonApi.Controllers.Response.render_one/5`.
Filter checks scope in SQL, need no original data, keep `:atomic` eligible, and
never reach `select([])`. `WriteDirect` still exists and is still tested — it is
used for `map_default_settings` create; do not delete it.

**3. `MapSystem`'s primary `:read` has an always-on preparation
`FilterSystemsByActorMap` (`map_system.ex:205`)** that independently map-scopes
every read. **It confounds policy tests** — a test round-tripping through
MapSystem can pass with the policy completely broken. A reviewer caught exactly
this via mutation testing in Task 1. Assert on raw filter values, or use a
resource with no competing preparation. `authz_direct_map_test.exs` has a
"read policy alone (no preparation) excludes foreign rows" test that uses the
`:get_by_id` action for this reason — follow that pattern.

**4. `simple_sat` is a required runtime dep** of Ash's policy authorizer. Already
added to `mix.exs`/`mix.lock`.

**5. Composition is `bypass Trusted` then action policies.** Never stacked
unconditional `policy` blocks — Ash requires *all* applicable policies to pass, so
stacking denies everyone.

## Environment (verified — do not re-derive)

- Devcontainer. Test DB is the compose service `db` (172.18.0.2:5432).
  `config/test.exs` says `hostname: "localhost"` but `config/runtime.exs:9`
  overrides it from `DB_HOST=db`. Already created and migrated.
- Integration tests are **excluded by default** (`test/test_helper.exs:28`).
  Run with `mix test --include integration`.
- **`mix compile --warnings-as-errors` already FAILS at baseline** with 7
  pre-existing warnings (`map_server_connections_impl.ex:216`,
  `operations/connections.ex:25/27`, `map_audit_api_controller.ex:7`,
  `map_pings_event_handler.ex:245/246`, gettext). Do not fix them. The real gate
  is: **no NEW warnings in touched files**.
- **13 pre-existing integration failures** that are NOT this branch's fault:
  `CharacterLocationTrackingTest` (7) and `MapDuplicationAPIControllerSuccessTest`
  (6). The full list is in the ledger. Diff against it; anything else is yours.
  Note `Map.duplicate` is a Task 7 regression site whose tests already fail at
  baseline — Task 7 must distinguish "already broken" from "we broke it".
- **Always `mix compile --force` before trusting a test run.** A stale build
  artifact produced a phantom `WandererApp.Api is not a Spark DSL module` failure
  across 6 audit tests that vanished on a forced recompile.
- **Never measure while an agent is editing.** Two consecutive full runs
  disagreed because a subagent was still writing test files mid-run.

## Process note (why this handover exists)

Three delegated subagents stalled on Task 2 — going silent for 1–2 hours with
uncommitted work and no report. Check liveness with
`ps -eo pid,etime,args | grep -E "beam.smp|/mix "` plus file mtimes; no process
and no recent writes means stalled, not thinking. Task 2 was ultimately
implemented directly in-session, which worked better. Consider doing Tasks 3–7
inline, or set a hard timeout and take over rather than re-dispatching.

The subagent-driven-development skill's review loop **did work well** and is worth
keeping: reviewers caught a critical `ref/2` crash and a vacuous test that a green
18/18 suite had hidden. Recommend keeping per-task review even if implementation
moves in-session.

## Suggested opening prompt for the new session

> Continue the `/api/v1` authorization hardening on branch
> `worktree-api-v1-authz` in `/worktrees/api-v1-authz` (PR #99). Tasks 0–2 are
> committed through `037a2b3c`; Tasks 3–7 remain. Read
> `docs/superpowers/handovers/2026-08-01-api-v1-authz-session2-handover.md`
> first, then the design, plan, and `.superpowers/sdd/2026-07-29-api-v1-authz/progress.md`
> ledger. Start with Task 3 (system-path resources); its brief is already
> extracted at `.superpowers/sdd/2026-07-29-api-v1-authz/task-3-brief.md`.
> Note the two binding human decisions (403 on foreign map_id create; 404 not 403
> on foreign PATCH/DELETE) and the hard-won facts about filter checks vs
> SimpleChecks — they are in the handover.
