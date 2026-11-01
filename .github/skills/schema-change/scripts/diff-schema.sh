#!/usr/bin/env bash
# Usage: diff-schema.sh <old> <new>   -> unified diff on stdout
source "$(dirname "$0")/common.sh"
cd "$SCHEMA_DIR"
diff -u "$(basename "$(schema_file "$1")")" "$(basename "$(schema_file "$2")")" || true
