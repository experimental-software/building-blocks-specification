#!/usr/bin/env bash
# Usage: comment-pr.sh <old> <new> [pr-number]
# Posts the schema diff as a PR comment inside a <details> block.
source "$(dirname "$0")/common.sh"
old="$1"; new="$2"; pr="${3:-}"
body="$(mktemp)"; trap 'rm -f "$body"' EXIT
{
  echo "<details>"
  echo "<summary>Schema diff $old → $new</summary>"
  echo
  echo '```diff'
  "$(dirname "$0")/diff-schema.sh" "$old" "$new"
  echo '```'
  echo
  echo "</details>"
} > "$body"
gh pr comment ${pr:+"$pr"} --body-file "$body"
