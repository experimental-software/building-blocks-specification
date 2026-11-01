#!/usr/bin/env bash
# Usage: add-changelog.sh <new> <Added|Changed|Removed|Fixed> <breaking|non-breaking> <description>
# Inserts an entry above the newest release section, in the existing format.
source "$(dirname "$0")/common.sh"
new="$1"; section="$2"; kind="$3"; text="$4"
[[ "$kind" == breaking ]] && text="**BREAKING:** $text"
f="$ROOT/CHANGELOG.md"
grep -q "^## \[$new\]" "$f" && { echo "entry for $new exists" >&2; exit 1; }
entry="$(mktemp)"; trap 'rm -f "$entry"' EXIT
printf '## [%s] - %s\n\n### %s\n\n- %s\n\n' "$new" "$(date -u +%F)" "$section" "$text" > "$entry"
first="$(grep -n '^## \[' "$f" | head -n1 | cut -d: -f1)"
if [[ -n "$first" ]]; then
  sed -i "$((first-1))r $entry" "$f"
else
  { echo; cat "$entry"; } >> "$f"
fi
