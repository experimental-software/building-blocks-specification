#!/usr/bin/env bash
# Usage: update-readme.sh <old> <new>
# Updates version references in the README usage example. Property edits are done by the agent.
source "$(dirname "$0")/common.sh"
old="$1"; new="$2"
sed -i -e "s/${old//./\\.}/$new/g" -e "s/${old//./_}/${new//./_}/g" "$ROOT/README.md"
