#!/bin/bash

set -e

COMMAND=$1

case $COMMAND in
  e|env)
    export ERL_AFLAGS="-kernel shell_history enabled"
    ;;
  i|install)
    MIX_ENV=dev mix deps.get
    cd assets && yarn install
    ;;
  deps)
    MIX_ENV=dev mix deps.get
    ;;
  deploy)
    MIX_ENV=dev mix assets.deploy
    ;;
  setup)
    MIX_ENV=dev mix setup
    ;;
  createdb)
    MIX_ENV=dev mix ecto.create
    ;;
  testdb)
    MIX_ENV=dev mix ash.codegen test111
    ;;
  depsf)
    MIX_ENV=dev mix deps.compile syslog --force
    ;;
  d|deploy)
    mix assets.build && mix assets.deploy
    ;;
  c|cleanup)
    pkill -SIGTERM -f 'tailwind' || true
    ;;
  y|yarn)
    cd assets && yarn
    ;;
  w|watch)
    cd assets && yarn watch
    ;;
  s|server|start)
    bash scripts/toxiproxy.sh stop
    source .env && MIX_ENV=dev iex -S mix phx.server
    ;;
  s:p|server:proxy|start:proxy)
    bash scripts/toxiproxy.sh start
    trap 'bash scripts/toxiproxy.sh stop' EXIT
    source .env && PORT=4446 WEB_APP_URL=http://localhost:4444 MIX_ENV=dev iex -S mix phx.server
    ;;
  s:p:f|server:proxy:fast|start:proxy:fast)
    bash scripts/toxiproxy.sh profile fast
    ;;
  s:p:s|server:proxy:slow|start:proxy:slow)
    bash scripts/toxiproxy.sh profile slow
    ;;
  s:p:u|server:proxy:unstable|start:proxy:unstable)
    bash scripts/toxiproxy.sh profile unstable
    ;;
  m|migrate)
    MIX_ENV=dev mix ash.migrate
    ;;
  r|reset)
    MIX_ENV=dev mix ecto.reset
    ;;
  si|seeds)
    MIX_ENV=dev mix run priv/repo/seeds.exs
    ;;
  f|format)
    mix format
    ;;
  t|test)
    mix test
    ;;
  cover|coverage|co)
    mix test --cover
    ;;
  v|versions)
    echo "Tool Versions"
    cat .tool-versions
    cat Aptfile
    echo
    ;;
  *)
    echo "Usage: $0 {e|env|i|install|dg|deps|depsf|d|deploy|c|cleanup|y|yarn|s|server|start|s:p|s:p:f|s:p:s|s:p:u|m|migrate|f|format|t|test|cover|coverage|co|v|versions|watch|seeds}"
    exit 1
    ;;
esac
