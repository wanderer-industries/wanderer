#!/usr/bin/env bash
#
# deploy_wanderer.sh
#
# This script uses the VERSION environment variable to set the WANDERER_VERSION
# for Docker Compose and then deploys the relevant container.

# Exit immediately on errors, unset variables, or errors in piped commands
set -euo pipefail

# If you want to make VERSION optional and default to "latest" if not set, uncomment:
# VERSION="${VERSION:-latest}"

# Or, if you prefer strict behavior (error if VERSION is not set), uncomment:
# : "${VERSION:?VERSION environment variable must be set.}"

echo "Deploying version ${VERSION}"

# Write the environment variable to the compose env file
cat <<EOF > /app/wanderer/.compose.env
WANDERER_VERSION=${VERSION}
EOF

# Move into the project directory
cd /app/wanderer

# Pull the updated image
docker compose \
  --env-file .compose.env \
  -f docker-compose.yml \
  -f reverse-proxy/docker-compose.caddy-gen.yml \
  pull wanderer

# Bring the service up using the updated environment
docker compose \
  --env-file .compose.env \
  -f docker-compose.yml \
  -f reverse-proxy/docker-compose.caddy-gen.yml \
  up -d --force-recreate --no-deps wanderer

echo "Deployment complete."
