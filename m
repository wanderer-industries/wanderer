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
    source .env && MIX_ENV=dev iex -S mix phx.server
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
    echo "Usage: $0 {e|env|i|install|dg|deps|depsf|d|deploy|c|cleanup|y|yarn|s|server|start|m|migrate|f|format|t|test|cover|coverage|co|v|versions|watch|seeds}"
    exit 1
    ;;
esac
