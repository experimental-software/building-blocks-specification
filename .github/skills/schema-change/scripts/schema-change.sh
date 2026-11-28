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

Adds the entry to the first section of CHANGELOG.md, creating "## [Unreleased]"
if needed, then sets the schema \$id to
"https://github.com/experimental-software/building-blocks-specification/blob/main/buildingblocks_schema.json".
README.md is not changed. No release, tag or branch is created.

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
  sed -E -i "s|(\"\\\$id\"[[:space:]]*:[[:space:]]*\")[^\"]*(\")|\1${new_id}\2|" "${SCHEMA_FILE}"
  if [[ "$(jq -er '."$id"' "${SCHEMA_FILE}")" != "${new_id}" ]]; then
    echo "ERROR: failed to update schema \$id in ${SCHEMA_FILE}" >&2
    exit 1
  fi
}

update_draft_id() {
  local id
  id=$(jq -er '."$id"' "${SCHEMA_FILE}") || {
    echo "ERROR: unable to read \$id from ${SCHEMA_FILE}" >&2
    exit 1
  }

  local new_id="https://github.com/experimental-software/building-blocks-specification/blob/main/buildingblocks_schema.json"
  if [[ "${id}" == "${new_id}" ]]; then
    echo "Schema \$id is already a draft: ${id}"
  else
    set_schema_id "${new_id}"
    echo "Schema \$id: ${id} -> ${new_id}"
  fi
}

add_changelog_entry() {
  local text=$DESCRIPTION
  [[ "${BREAKING}" == "true" ]] && text="**BREAKING:** ${text}"

  if ! awk '
    /^## / {
      if ($0 == "## [Unreleased]" && seen_section) exit 1
      seen_section = 1
    }
  ' "${CHANGELOG_FILE}"; then
    echo "ERROR: '## [Unreleased]' must be the first section in ${CHANGELOG_FILE}" >&2
    exit 1
  fi

  local tmp
  tmp=$(mktemp)
  if ! grep -Fxq '## [Unreleased]' "${CHANGELOG_FILE}"; then
    awk '
      /^## / && !inserted {
        print "## [Unreleased]"; print ""; inserted = 1
      }
      { print }
      END {
        if (!inserted) { print ""; print "## [Unreleased]"; print "" }
      }
    ' "${CHANGELOG_FILE}" > "${tmp}"
    cat "${tmp}" > "${CHANGELOG_FILE}"
  fi
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
      in_unreleased = ($0 == "## [Unreleased]")
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
update_draft_id
