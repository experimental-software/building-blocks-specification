#!/usr/bin/env bash
# Usage: diff-schema.sh <old> <new>   -> unified diff on stdout
# Compares the root schema with its historical version identified by <old>.
source "$(dirname "$0")/common.sh"
[[ $# -eq 2 ]] || { echo "usage: $0 <old> <new>" >&2; exit 2; }
old_id="buildingblocks_${1//./_}.json"
schema_path="${SCHEMA_FILE#"$ROOT"/}"
baseline="$(mktemp)"
trap 'rm -f "$baseline"' EXIT

found=0
while IFS= read -r commit; do
  if git show "$commit:$schema_path" | jq -e --arg old_id "$old_id" '."$id" | endswith($old_id)' >/dev/null; then
    git show "$commit:$schema_path" > "$baseline"
    found=1
    break
  fi
done < <(git log --format=%H -- "$schema_path")

[[ "$found" -eq 1 ]] || { echo "no historical schema found for version $1" >&2; exit 1; }
diff -u --label "buildingblocks_schema.json ($1)" "$baseline" \
  --label "buildingblocks_schema.json ($2)" "$SCHEMA_FILE" || [[ $? -eq 1 ]]
