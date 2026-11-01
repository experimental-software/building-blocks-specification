#!/usr/bin/env bash
# Shared helpers. Source this file.
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
SCHEMA_DIR="$ROOT/schema"

# Prints the latest schema version (X.Y.Z).
latest_version() {
  ls "$SCHEMA_DIR" | sed -n 's/^buildingblocks_\([0-9]*\)_\([0-9]*\)_\([0-9]*\)\.json$/\1.\2.\3/p' | sort -V | tail -n1
}
schema_file() { echo "$SCHEMA_DIR/buildingblocks_${1//./_}.json"; }
