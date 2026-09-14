#!/bin/sh
set -e

if [ "$1" = 'run' ]; then
      # bring the schema up to date before booting - a release started against a database that is
      # behind fails later, in ways that look like application bugs
      /app/bin/wanderer_app eval WandererApp.Release.auto_migrate

      exec /app/bin/wanderer_app start

elif [ "$1" = 'db' ]; then
      exec /app/bin/"$2".sh
 else
      exec "$@"

fi

exec "$@"
