#!/usr/bin/env bash
# Shared helpers. Source this file.
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
SCHEMA_FILE="$ROOT/buildingblocks_schema.json"

# Prints the latest schema version (X.Y.Z).
latest_version() {
  local id
  id="$(jq -er '."$id"' "$SCHEMA_FILE")" || {
    echo "unable to read schema \$id from $SCHEMA_FILE" >&2
    return 1
  }
  [[ "$id" =~ buildingblocks_([0-9]+)_([0-9]+)_([0-9]+)\.json$ ]] || {
    echo "schema \$id has an invalid version: $id" >&2
    return 1
  }
  printf '%s.%s.%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
}
