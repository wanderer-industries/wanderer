#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
COMPOSE_FILE="$PROJECT_DIR/docker-compose.toxiproxy.yml"
API_URL="http://localhost:8474"
PROXY_NAME="wanderer_dev_web"
MAX_READY_ATTEMPTS=30

compose() {
  docker compose -f "$COMPOSE_FILE" "$@"
}

ensure_docker_is_running() {
  if docker info >/dev/null 2>&1; then
    return
  fi

  echo "Docker daemon is unavailable." >&2
  echo "Start Docker Desktop in Linux containers mode and wait until the engine is running." >&2
  exit 1
}

wait_until_ready() {
  local attempt

  for ((attempt = 1; attempt <= MAX_READY_ATTEMPTS; attempt++)); do
    if curl --silent --fail "$API_URL/version" >/dev/null; then
      return
    fi

    sleep 0.2
  done

  echo "Toxiproxy did not become ready. Check: docker compose -f $COMPOSE_FILE logs" >&2
  exit 1
}

start_proxy() {
  ensure_docker_is_running
  compose up -d
  wait_until_ready
}

stop_proxy() {
  if ! docker info >/dev/null 2>&1; then
    return
  fi

  compose down >/dev/null 2>&1
}

delete_toxic() {
  local toxic_name=$1

  curl --silent --output /dev/null \
    --request DELETE \
    "$API_URL/proxies/$PROXY_NAME/toxics/$toxic_name" || true
}

clear_toxics() {
  local toxic_name

  for toxic_name in \
    latency_upstream \
    latency_downstream \
    reset_peer_upstream \
    reset_peer_downstream; do
    delete_toxic "$toxic_name"
  done
}

add_toxic() {
  local payload=$1

  curl --silent --fail --output /dev/null \
    --header "Content-Type: application/json" \
    --request POST \
    --data "$payload" \
    "$API_URL/proxies/$PROXY_NAME/toxics"
}

apply_slow_profile() {
  add_toxic '{"name":"latency_upstream","type":"latency","stream":"upstream","toxicity":1,"attributes":{"latency":750,"jitter":250}}'
  add_toxic '{"name":"latency_downstream","type":"latency","stream":"downstream","toxicity":1,"attributes":{"latency":750,"jitter":250}}'
}

apply_unstable_profile() {
  add_toxic '{"name":"latency_upstream","type":"latency","stream":"upstream","toxicity":1,"attributes":{"latency":500,"jitter":500}}'
  add_toxic '{"name":"latency_downstream","type":"latency","stream":"downstream","toxicity":1,"attributes":{"latency":500,"jitter":500}}'
  add_toxic '{"name":"reset_peer_upstream","type":"reset_peer","stream":"upstream","toxicity":0.1,"attributes":{"timeout":3000}}'
  add_toxic '{"name":"reset_peer_downstream","type":"reset_peer","stream":"downstream","toxicity":0.1,"attributes":{"timeout":3000}}'
}

apply_profile() {
  local profile=$1

  start_proxy
  clear_toxics

  case "$profile" in
    fast)
      ;;
    slow)
      apply_slow_profile
      ;;
    unstable)
      apply_unstable_profile
      ;;
    *)
      echo "Unknown proxy profile: $profile" >&2
      exit 1
      ;;
  esac

  echo "Toxiproxy profile: $profile"
  echo "Open Wanderer through http://localhost:4444"
}

case "${1:-}" in
  start)
    start_proxy
    echo "Toxiproxy is ready on http://localhost:4444 (current profile is preserved)."
    ;;
  stop)
    stop_proxy
    ;;
  profile)
    apply_profile "${2:-}"
    ;;
  *)
    echo "Usage: $0 {start|stop|profile {fast|slow|unstable}}" >&2
    exit 1
    ;;
esac
