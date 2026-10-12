# Repository Guidelines

## Project Structure & Module Organization
- `lib/`: core Elixir/Phoenix app code.
- `assets/`: frontend build (Vite, Tailwind, React). Mapper UI lives in `assets/js/hooks/Mapper/`.
- `config/`: runtime and environment configuration.
- `priv/`: migrations, seeds (`priv/repo/seeds.exs`), and static assets digests.
- `test/`: ExUnit tests (with `test/support/` helpers).

## Build, Test, and Development Commands
- `mix setup`: install Elixir deps, set up DB, and build assets.
- On Windows, prefer the root `./m` script; it wraps common tasks (see below).
- `./m install` (`i`): install Elixir deps and frontend packages.
- `./m start` (`s`): run Phoenix server with `.env` loaded.
- `./m migrate` (`m`): run Ash migrations for dev.
- `./m watch` (`w`): run Vite watch build in `assets/`.
- `./m deps`: update Elixir deps only; `./m yarn` (`y`) for frontend deps.
- `./m format` (`f`) and `./m test` (`t`): format and run tests.
- `./m coverage` (`cover`/`co`): coverage via `mix test --cover`.
- `cd assets && yarn build|watch|test`: Vite build/watch or Jest tests.

## Coding Style & Naming Conventions
- Elixir: follow `mix format` (see `.formatter.exs`).
- Frontend: TypeScript/React in `assets/` with ESLint + Prettier config installed.
- Naming patterns: React components are `PascalCase` (e.g., `MapRoot.tsx`); hooks are `useCamelCase` (e.g., `useMapperHandlers.ts`).
- Keep new modules colocated with existing feature folders (e.g., `assets/js/hooks/Mapper/components/`).
- Frontend JSX: for optional blocks, prefer `cond && <Component />` instead of ternaries returning `null`.

## Testing Guidelines
- Backend tests use ExUnit (`mix test`), with support modules in `test/support/`.
- Frontend tests use Jest (`cd assets && yarn test`).
- For coverage reports, use `mix test.coverage` (or `make coverage`).

## Commit & Pull Request Guidelines
- Commit messages follow Conventional Commits seen in history: `feat:`, `fix:`, `chore:`, and scoped forms like `fix(core): ...`.
- PRs should include a clear summary, linked issue (if applicable), and screenshots for UI changes in `assets/`.
- Ensure relevant tests pass before opening a PR.

## Configuration & Secrets
- Copy `.env.example` to `.env` and keep secrets out of git.
- Local DB setup is handled by `mix setup`; reset with `mix ecto.reset` when needed.
