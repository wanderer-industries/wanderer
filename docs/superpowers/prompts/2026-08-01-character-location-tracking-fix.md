# Prompt: fix `CharacterLocationTrackingTest` (8 pre-existing failures)

Copy everything below the line into a fresh session.

---

Fix the 8 failing tests in `test/integration/map/character_location_tracking_test.exs`
(`WandererApp.Map.CharacterLocationTrackingTest`) in the repo at `/worktrees/api-v1-authz`
(or a fresh worktree off `main` — this is independent of the `/api/v1` authz work).

These failures **predate** the authz branch and were excluded from it deliberately.
A previous session diagnosed the first layer but reverted its fix as net-negative.
Start from that diagnosis rather than repeating it.

## What is already established (verified, do not re-derive)

**It is not flaky per-suite.** Same seed → same 8 failures. Only the *ordering*
varies across seeds, which is why earlier sessions mislabelled it flaky. Per-suite
runs are deterministic; treat any run-to-run difference at full-suite scope as a
separate phenomenon.

**`Map.Manager` IS running in the test env.** The error message
*"Timeout waiting for map … Check Map.Manager is running"* is actively misleading.
An earlier hypothesis that `application.ex:127` excludes it under `:test` was
**disproved** — a probe showed `Map.Manager`, `MapPoolSupervisor` and
`MapPoolDynamicSupervisor` all with live pids under `IntegrationCase`.
`test/test_helper.exs:24` (`ensure_map_supervisors_started/0`) starts them.

**Real first-layer cause — proved by temporarily instrumenting `MapRepo.get/2`:**

```
DBConnection.OwnershipError: cannot find ownership process for #PID<...>
```

The failure chain:

1. `lib/wanderer_app/map/server/map_server_impl.ex:52` runs six loaders in
   `Task.async` processes.
2. Those processes are never allowed on the Ecto sandbox connection → each fails
   with `DBConnection.OwnershipError`.
3. `lib/wanderer_app/repositories/map_repo.ex:24` **swallows** the real error into
   `{:error, :not_found}`.
4. `do_init_state/1` logs *"Failed to load map state"*, `start_map/1` aborts with
   *"map not loaded"*.
5. The test reports only the misleading timeout above.

**Underlying defect:** `test/support/integration_case.ex:84` reads

```elixir
shared_mode = tags[:async] == true
```

This is **inverted**. Ecto permits shared mode only when `async: false`, and shared
mode is exactly what suites with dynamically spawned processes need. So the suites
that need it (`async: false`, starting map servers) run with a private owner.

**Attempted fix, REVERTED — do not simply redo it.** Flipping to `!= true` fixed the
`OwnershipError` and took this suite **8 → 7** failures. But shared mode is *global
to the node*: at full-suite scope it fixed nothing and **introduced a new failure**
(`CommonAPIControllerTest` "returns system static info for valid system ID"). Net
negative. A correct fix must scope shared mode to the suites that need it rather
than flipping the global condition.

**The remaining 7 failures after that flip had a different, deeper cause** — not
`OwnershipError`, not a map-start timeout. That layer is **undiagnosed**; expect
real work there.

## Your task

1. Reproduce: `mix test test/integration/map/character_location_tracking_test.exs --include integration --seed 0` → expect 14 tests, 8 failures.
2. Fix the sandbox-access problem in a way that does **not** regress other suites.
   Per-suite scoping (e.g. an opt-in tag, or explicit allowances for the map-server
   supervision tree) is likely better than a global mode flip.
3. Then diagnose and fix the remaining layer. Instrument rather than guess — the
   error masking in step 3 above is why this took so long previously.
4. Decide honestly whether each test is worth keeping. If any assert on genuinely
   unreachable behaviour in a test env, say so and propose skipping *with a
   documented reason* rather than weakening assertions into vacuity.

## Strongly recommended side-fix

`lib/wanderer_app/repositories/map_repo.ex:24` flattens **any** error into
`{:error, :not_found}`. That masking cost most of the previous diagnosis. Preserve
the underlying error (or at least log it) — likely worth its own commit.

## Verification requirements

- **Never claim a bare failure count.** `mix test --include integration` is unstable
  at full-suite scope: **14, 15 and 25 failures observed on an unchanged tree.**
  Compare *sets*, not counts.
- **Baseline method:**
  ```bash
  git worktree add /tmp/baseline-check <merge-base>
  cd /tmp/baseline-check && ln -sfn <main-worktree>/deps deps
  MIX_ENV=test mix compile
  mix test --include integration 2>&1 | grep -E "^\s+[0-9]+\) test" \
    | sed 's/^ *[0-9]*) //' | sort > /tmp/base_fails.txt
  # then comm -13 / comm -23 against the same listing from your branch
  ```
  Merge-base for the authz branch was `b7ddbc48`; use your own.
- Prove any fix is real: confirm the failure mode is gone (no `OwnershipError`, no
  map-start timeout), not merely that the count dropped.
- Required: zero new failures at full-suite scope, verified by set-diff.

## Environment

- Integration tests are excluded by default → `mix test --include integration`.
- Always `mix compile --force` before trusting a run.
- **Never hand-delete `_build` subdirs** — that corrupts the test build
  (*"module WandererAppWeb is not loaded"*). Recover with
  `rm -rf _build/test && MIX_ENV=test mix compile --force`.
- `mix compile --warnings-as-errors` already fails at baseline (7 pre-existing
  warnings). Gate is: no NEW warnings in touched files.

## Process note

Four delegated subagents stalled on this codebase across two sessions — silent for
1–2 hours, or returning only idle pings with no findings. Prefer working in-session.
If you delegate, set a hard timeout and take over rather than re-dispatching. Check
liveness with `ps -eo pid,etime,args | grep -E "beam.smp|/mix "` plus file mtimes.
