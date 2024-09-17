#!/bin/sh
set -e

if [ "$1" = 'run' ]; then
      exec /app/bin/wanderer_app start

elif [ "$1" = 'db' ]; then
      exec /app/bin/"$2".sh
 else
      exec "$@"

fi

exec "$@"
