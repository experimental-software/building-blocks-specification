#!/usr/bin/env bash
# Usage: copy-schema.sh <addition|breaking>...
# Copies the latest schema to the next version and updates $id/version strings in the copy only.
# Prints "<old> <new>" on stdout.
source "$(dirname "$0")/common.sh"
old="$(latest_version)"
new="$("$(dirname "$0")/next-version.sh" "$old" "$@")"
src="$(schema_file "$old")"; dst="$(schema_file "$new")"
[[ ! -e "$dst" ]] && cp "$src" "$dst" || { echo "target exists: $dst" >&2; exit 1; }
sed -i -e "s/${old//./\\.}/$new/g" -e "s/${old//./_}/${new//./_}/g" "$dst"
echo "$old $new"
