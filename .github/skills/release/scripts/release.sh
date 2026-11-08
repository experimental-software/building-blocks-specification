#!/usr/bin/env bash

set -e # exit script if there is any error in any command

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# ==============================================================================
# SCRIPT PARAMETERS
# ==============================================================================

USAGE=$(cat <<EOF
usage: $(basename -- "${BASH_SOURCE[0]}") [-v VERSION] [-h]

optional arguments:
  -v    The release version (X.Y.Z). Defaults to the version of the current
        snapshot \$id in buildingblocks_schema.json without the -SNAPSHOT suffix.
  -h    Show this help message and exit.

Updates the \$id in buildingblocks_schema.json and all versioned examples in
README.md to the release version. No tag, release or branch is created.

dependencies:
  - jq
EOF
)

while getopts "v:h" flag; do
  case "$flag" in
      v) VERSION=$OPTARG;;
      h) HELP="true";;
      \?)
          echo "Invalid flag: ${OPTARG}" >&2
          exit 1
          ;;
  esac
done

if [[ ${HELP} == 'true' ]]; then
  echo "${USAGE}"
  exit 0
fi

if [[ -n "${VERSION}" && ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: Invalid version '${VERSION}', expected X.Y.Z." >&2
  exit 1
fi

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

ROOT=${RELEASE_ROOT:-$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel)}
SCHEMA_FILE="${ROOT}/buildingblocks_schema.json"
README_FILE="${ROOT}/README.md"

determine_version() {
  [[ -n "${VERSION}" ]] && return

  local id
  id=$(jq -er '."$id"' "${SCHEMA_FILE}") || {
    echo "ERROR: unable to read \$id from ${SCHEMA_FILE}" >&2
    exit 1
  }
  if [[ ! "${id}" =~ buildingblocks_([0-9]+)_([0-9]+)_([0-9]+)-SNAPSHOT\.json$ ]]; then
    echo "ERROR: cannot determine the snapshot version from \$id '${id}'. Pass the version with -v." >&2
    exit 1
  fi
  VERSION="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
}

update_schema_id() {
  local old_id new_id
  old_id=$(jq -er '."$id"' "${SCHEMA_FILE}")
  if [[ ! "${old_id}" =~ ^(.*buildingblocks_)[0-9]+_[0-9]+_[0-9]+(-SNAPSHOT)?\.json$ ]]; then
    echo "ERROR: schema \$id has an invalid version: ${old_id}" >&2
    exit 1
  fi
  new_id="${BASH_REMATCH[1]}${VERSION//./_}.json"
  sed -i "s|\"\\\$id\": \"${old_id}\"|\"\$id\": \"${new_id}\"|" "${SCHEMA_FILE}"
  echo "Schema \$id: ${old_id} -> ${new_id}"
}

update_readme() {
  sed -i -E \
    -e "s/(buildingblocks_)[0-9]+_[0-9]+_[0-9]+(-SNAPSHOT)?\.json/\1${VERSION//./_}.json/g" \
    -e "s/^(buildingblocks: )[0-9]+\.[0-9]+\.[0-9]+(-SNAPSHOT)?/\1${VERSION}/" \
    "${README_FILE}"
  echo "README examples updated to ${VERSION}"
}

# ==============================================================================
# MAIN SCRIPT EXECUTION
# ==============================================================================

determine_version
update_schema_id
update_readme
