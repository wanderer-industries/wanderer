#!/usr/bin/env bash
set -e

echo "→ ensuring build dirs are writable"
# deps/ and _build/ come from the /app bind mount (see docker-compose.yml), so
# they carry host ownership. When the host uid differs from the container user's,
# mix cannot write to them. Best-effort fix; harmless when uids already match.
sudo chown -R "$(id -u):$(id -g)" /app/deps /app/_build 2>/dev/null || true

echo "→ fetching & compiling deps"
mix deps.get
mix compile

# only run Ecto if the project actually has those tasks
if mix help | grep -q "ecto.create"; then
  echo "→ waiting for database to be ready..."

  # Wait for database to be ready
  DB_HOST=${DB_HOST:-db}
  timeout=60
  while ! nc -z $DB_HOST 5432 2>/dev/null; do
    if [ $timeout -eq 0 ]; then
      echo "❌ Database connection timeout"
      exit 1
    fi
    echo "Waiting for database... ($timeout seconds remaining)"
    sleep 1
    timeout=$((timeout - 1))
  done

  # Give the database a bit more time to fully initialize
  echo "→ giving database 2 more seconds to fully initialize..."
  sleep 2

  echo "→ database is ready, running ecto.create && ecto.migrate"
  mix ecto.create --quiet
  mix ecto.migrate

  # Seed the EVE SDE reference data (solar systems, jumps, ship types) only when
  # it is missing. `mix ecto.setup` would run priv/repo/seeds.exs unconditionally,
  # but that downloads and bulk-imports the SDE (~23k rows) every time — slow and
  # pointless when the database volume already has it. Checking the table is the
  # cheap way to tell a fresh volume from a warm one.
  #
  # --no-start matters: a bare `mix run` boots the whole supervision tree
  # (TheraDataFetcher, TurnurDataFetcher, Map.Reconciler, TrackerManager, ...),
  # which starts outbound pollers just to count rows and would report "not
  # seeded" if any of them failed to start. Start ecto_sql and the Repo alone
  # instead — --no-start also skips :db_connection, so ensure_all_started is
  # required or Repo.start_link exits with "no process".
  echo "→ checking EVE SDE reference data"
  if mix run --no-start -e '
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    {:ok, _} = WandererApp.Repo.start_link(pool_size: 2)
    count =
      case Ecto.Adapters.SQL.query(WandererApp.Repo, "select count(*) from map_solar_system_v2", []) do
        {:ok, %{rows: [[n]]}} -> n
        _ -> 0
      end
    System.halt(if count > 0, do: 0, else: 1)' >/dev/null 2>&1; then
    echo "→ SDE data already present, skipping seeds"
  else
    echo "→ seeding EVE SDE data (downloads the SDE, may take a few minutes)"
    mix run priv/repo/seeds.exs || echo "⚠️  SDE seeding failed — run 'mix run priv/repo/seeds.exs' manually"
  fi
fi

echo "→ installing JS & CSS dependencies"
cd assets
yarn install --frozen-lockfile

echo "→ building assets"
yarn build

echo "✅ setup complete"
