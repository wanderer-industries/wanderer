#!/usr/bin/env bash
# test/manual/api/run_tests.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Main entry point for all manual API tests
# Usage: ./run_tests.sh [all|create|update|delete|-v]

if [ $# -eq 0 ]; then
  echo "Running all improved API tests..."
  "$SCRIPT_DIR/improved_api_tests.sh"
  exit $?
fi

# Pass through any arguments to improved_api_tests.sh
"$SCRIPT_DIR/improved_api_tests.sh" "$@"
exit $?
