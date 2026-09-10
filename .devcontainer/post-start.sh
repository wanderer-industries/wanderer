#!/bin/bash
# Post-start script - runs every time the container starts

set -e

echo "🔄 Running post-start tasks..."

# Display helpful information
echo ""
echo "📊 Environment Info:"
echo "  Elixir version: $(elixir --version | tail -1 | awk '{print $2}' 2>/dev/null || echo 'not installed')"
echo "  Node version:   $(node --version 2>/dev/null || echo 'not installed')"
echo "  Shell:          $(basename "${SHELL}")"
echo "  Working dir:    $(pwd)"
echo ""

# Check database (Postgres)
DB_HOST=${DB_HOST:-db}
if command -v nc >/dev/null 2>&1; then
    if nc -z "$DB_HOST" 5432 2>/dev/null; then
        echo "💾 Postgres: ready (${DB_HOST}:5432)"
    else
        echo "⚠️  Postgres not yet ready at ${DB_HOST}:5432 — check docker compose logs db"
    fi
fi

echo ""
echo "🎯 Ready to code!"
echo ""
echo "Useful commands:"
echo "  make server   # Start Phoenix dev server (port 4444)"
echo "  mix test      # Run tests"
echo "  mix format    # Format code"
echo ""
