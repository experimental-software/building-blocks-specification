#!/usr/bin/env bash
# Usage: next-version.sh <current X.Y.Z> <addition|breaking>...
# Breaking -> minor bump (patch reset); addition -> patch bump. The higher bump wins.
set -euo pipefail
[[ $# -ge 2 ]] || { echo "usage: $0 <current> <addition|breaking>..." >&2; exit 2; }
cur="$1"; shift
[[ "$cur" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || { echo "invalid version: $cur" >&2; exit 2; }
major=${BASH_REMATCH[1]}; minor=${BASH_REMATCH[2]}; patch=${BASH_REMATCH[3]}
level=0
for c in "$@"; do
  case "$c" in
    addition) (( level < 1 )) && level=1 ;;
    breaking) level=2 ;;
    *) echo "unknown change class: $c" >&2; exit 2 ;;
  esac
done
if (( level == 2 )); then echo "$major.$((minor+1)).0"; else echo "$major.$minor.$((patch+1))"; fi
