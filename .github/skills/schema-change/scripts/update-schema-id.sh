#!/usr/bin/env bash
# Usage: update-schema-id.sh <addition|breaking>...
# Updates the root schema's $id to the next version.
# Prints "<old> <new>" on stdout.
source "$(dirname "$0")/common.sh"
[[ $# -ge 1 ]] || { echo "usage: $0 <addition|breaking>..." >&2; exit 2; }

old="$(latest_version)"
new="$("$(dirname "$0")/next-version.sh" "$old" "$@")"
old_id="$(jq -er '."$id"' "$SCHEMA_FILE")"
new_id="${old_id%buildingblocks_*}buildingblocks_${new//./_}.json"
tmp="$(mktemp "${SCHEMA_FILE}.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
jq --arg new_id "$new_id" '."$id" = $new_id' "$SCHEMA_FILE" > "$tmp"
last_byte="$(tail -c 1 "$SCHEMA_FILE" | od -An -t x1 | tr -d '[:space:]')"
[[ "$last_byte" == "0a" ]] || truncate -s -1 "$tmp"
chmod --reference="$SCHEMA_FILE" "$tmp"
mv "$tmp" "$SCHEMA_FILE"
echo "$old $new"
