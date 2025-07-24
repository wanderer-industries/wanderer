#!/usr/bin/env bash
set -e

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
fi

  cd assets
  echo "→ installing JS & CSS dependencies"
  yarn install --frozen-lockfile
  echo "→ building assets"

echo "✅ setup complete"
