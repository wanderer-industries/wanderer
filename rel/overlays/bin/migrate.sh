#!/bin/sh
set -eu

BIN_DIR=$(dirname "$0")

"${BIN_DIR}"/wanderer_app eval WandererApp.Release.interweave_migrate
