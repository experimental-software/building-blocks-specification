#!/usr/bin/env bash
# Usage: validate.sh <old> <new>
source "$(dirname "$0")/common.sh"
old="$1"; new="$2"; err=0
fail() { echo "FAIL: $*" >&2; err=1; }
f="$(schema_file "$new")"
[[ -f "$f" ]] || { echo "missing $f" >&2; exit 1; }
jq empty "$f" || fail "invalid JSON"
[[ "$(jq -r '."$id"' "$f")" == *"buildingblocks_${new//./_}.json" ]] || fail "\$id does not match $new"
grep -q "${old//./\\.}\|${old//./_}" "$f" && fail "old version still referenced in new schema"
[[ "$(latest_version)" == "$new" ]] || fail "$new is not the latest schema"
cmp -s "$f" "$(schema_file "$old")" && fail "new schema identical to old"
grep -q "buildingblocks_${new//./_}.json" "$ROOT/README.md" && grep -q "^buildingblocks: $new" "$ROOT/README.md" || fail "README version not updated"
grep -q "^## \[$new\]" "$ROOT/CHANGELOG.md" || fail "CHANGELOG entry missing"
[[ $err -eq 0 ]] && echo "OK"
exit $err
