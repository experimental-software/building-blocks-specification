#!/usr/bin/env bash

set -e # exit script if there is any error in any command

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# ==============================================================================
# SCRIPT PARAMETERS
# ==============================================================================

USAGE=$(cat <<EOF
usage: $(basename -- "${BASH_SOURCE[0]}") -c CATEGORY [-b] [-h] <DESCRIPTION>

required arguments:
  [1]   The changelog entry text.
  -c    The changelog category: Added, Changed, Removed or Fixed.

optional arguments:
  -b    Mark the entry as breaking (prefixes it with "**BREAKING:**").
  -h    Show this help message and exit.

Adds the entry to the "## [Unreleased]" section of CHANGELOG.md and, unless the
schema \$id already ends in "-SNAPSHOT.json", bumps its patch version and adds
that suffix. No release, tag or branch is created.

dependencies:
  - jq
EOF
)

while getopts "c:bh" flag; do
  case "$flag" in
      c) CATEGORY=$OPTARG;;
      b) BREAKING="true";;
      h) HELP="true";;
      \?)
          echo "Invalid flag: ${OPTARG}" >&2
          exit 1
          ;;
  esac
done

DESCRIPTION=${*:OPTIND:1}

if [[ ${HELP} == 'true' ]]; then
  echo "${USAGE}"
  exit 0
fi

if [[ -z "${DESCRIPTION}" || -z "${CATEGORY}" ]]; then
  echo -e "ERROR: Missing required parameter.\n" >&2
  echo "${USAGE}" >&2
  exit 1
fi

case "${CATEGORY}" in
  Added|Changed|Removed|Fixed) ;;
  *)
    echo "ERROR: Invalid category '${CATEGORY}'." >&2
    exit 1
    ;;
esac

# ==============================================================================
# TEST DEPENDENCIES
# ==============================================================================

if ! command -v jq >/dev/null 2>&1 ; then
  echo "ERROR: jq not installed" >&2
  exit 1
fi

# ==============================================================================
# FUNCTIONS SECTION
# ==============================================================================

ROOT=${SCHEMA_CHANGE_ROOT:-$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel)}
SCHEMA_FILE="${ROOT}/buildingblocks_schema.json"
CHANGELOG_FILE="${ROOT}/CHANGELOG.md"

# Replaces the $id in the schema file, keeping the rest of the file untouched.
set_schema_id() {
  local new_id=$1
  local old_id
  old_id=$(jq -er '."$id"' "${SCHEMA_FILE}")
  sed -i "s|\"\\\$id\": \"${old_id}\"|\"\$id\": \"${new_id}\"|" "${SCHEMA_FILE}"
}

update_snapshot_version() {
  local id
  id=$(jq -er '."$id"' "${SCHEMA_FILE}") || {
    echo "ERROR: unable to read \$id from ${SCHEMA_FILE}" >&2
    exit 1
  }

  if [[ "${id}" == *-SNAPSHOT.json ]]; then
    echo "Schema \$id is already a snapshot: ${id}"
    return
  fi

  if [[ ! "${id}" =~ ^(.*buildingblocks_)([0-9]+)_([0-9]+)_([0-9]+)\.json$ ]]; then
    echo "ERROR: schema \$id has an invalid version: ${id}" >&2
    exit 1
  fi

  local new_id="${BASH_REMATCH[1]}${BASH_REMATCH[2]}_${BASH_REMATCH[3]}_$((BASH_REMATCH[4] + 1))-SNAPSHOT.json"
  set_schema_id "${new_id}"
  echo "Schema \$id: ${id} -> ${new_id}"
}

add_changelog_entry() {
  local text=$DESCRIPTION
  [[ "${BREAKING}" == "true" ]] && text="**BREAKING:** ${text}"

  if ! grep -q '^## \[Unreleased\]' "${CHANGELOG_FILE}"; then
    echo "ERROR: no '## [Unreleased]' section in ${CHANGELOG_FILE}" >&2
    exit 1
  fi

  local tmp
  tmp=$(mktemp)
  # Appends to an existing category of the Unreleased section or creates it.
  awk -v cat="### ${CATEGORY}" -v entry="- ${text}" '
    function flush_pending(   i) {
      if (!in_cat) return
      print entry
      for (i = 0; i < held; i++) print ""
      held = 0; in_cat = 0; done = 1
    }
    /^## / {
      if (in_unreleased) {
        flush_pending()
        if (!done) { print cat; print ""; print entry; print ""; done = 1 }
      }
      in_unreleased = ($0 ~ /^## \[Unreleased\]/)
      print; next
    }
    in_unreleased && /^### / {
      flush_pending()
      if ($0 == cat) in_cat = 1
    }
    in_unreleased && in_cat && /^$/ { held++; next }
    {
      if (held) { for (i = 0; i < held; i++) print ""; held = 0 }
      print
    }
    END {
      if (in_unreleased) {
        flush_pending()
        if (!done) { print ""; print cat; print ""; print entry }
      }
    }
  ' "${CHANGELOG_FILE}" > "${tmp}"
  cat "${tmp}" > "${CHANGELOG_FILE}"
  rm -f "${tmp}"
  echo "Changelog: added '${text}' under Unreleased/${CATEGORY}"
}

# ==============================================================================
# MAIN SCRIPT EXECUTION
# ==============================================================================

add_changelog_entry
update_snapshot_version
