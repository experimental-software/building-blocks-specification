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
README.md and examples/ to the release version, and renames the first
"## [Unreleased]" section in CHANGELOG.md to the dated release version. No tag,
release or branch is created.

dependencies:
  - jq
  - ruby
  - check-jsonschema (optional; enables full schema and example validation)
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
CHANGELOG_FILE="${ROOT}/CHANGELOG.md"
EXAMPLES_DIR="${ROOT}/examples"

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

update_examples() {
  local file
  while IFS= read -r -d '' file; do
    sed -i -E \
      -e "s/(buildingblocks_)[0-9]+_[0-9]+_[0-9]+(-SNAPSHOT)?\.json/\1${VERSION//./_}.json/g" \
      -e "s|(https://raw\\.githubusercontent\\.com/experimental-software/building-blocks-specification/refs/heads/main/)buildingblocks_schema\\.json|https://experimental-software.com/buildingblocks_${VERSION//./_}.json|g" \
      -e "s/^buildingblocks: \"?[0-9]+\.[0-9]+\.[0-9]+(-SNAPSHOT)?\"?/buildingblocks: \"${VERSION}\"/" \
      "${file}"
  done < <(find "${EXAMPLES_DIR}" -type f \( -name '*.yml' -o -name '*.yaml' \) -print0)
  echo "Examples updated to ${VERSION}"
}

validate_schema_and_examples() {
  local -a example_files=()
  mapfile -d '' -t example_files < <(find "${EXAMPLES_DIR}" -type f \( -name '*.yml' -o -name '*.yaml' \) -print0)

  if command -v check-jsonschema >/dev/null 2>&1; then
    check-jsonschema --schemafile "${SCHEMA_FILE}" "${example_files[@]}" 2>/dev/null
  else
    ruby -e 'require "json"; require "yaml"; JSON.parse(File.read(ARGV.shift)); ARGV.each { |file| YAML.load_file(file, aliases: true) }' "${SCHEMA_FILE}" "${example_files[@]}"
  fi
}

migrate_examples_if_needed() {
  local migration_script="${SCRIPT_DIR}/migrate-example-properties.rb"
  if ruby "${migration_script}" check "${CHANGELOG_FILE}" "${EXAMPLES_DIR}" >/dev/null 2>&1; then
    return
  fi

  echo "Examples do not match the changelog migration; applying property migrations."
  ruby "${migration_script}" migrate "${CHANGELOG_FILE}" "${EXAMPLES_DIR}"
}

validate_and_migrate_examples() {
  if validate_schema_and_examples; then
    migration_script="${SCRIPT_DIR}/migrate-example-properties.rb"
    if ! ruby "${migration_script}" check "${CHANGELOG_FILE}" "${EXAMPLES_DIR}" >/dev/null 2>&1; then
      migrate_examples_if_needed
      validate_schema_and_examples || {
        echo "ERROR: schema validation still fails after applying changelog migrations." >&2
        exit 1
      }
    fi
    echo "Schema and examples validated"
  else
    migrate_examples_if_needed
    validate_schema_and_examples || {
      echo "ERROR: schema validation still fails after applying changelog migrations." >&2
      exit 1
    }
    echo "Schema and examples validated"
  fi
}

validate_changelog() {
  if ! awk -v version="${VERSION}" '
    /^## / {
      if (!seen && $0 != "## [Unreleased]") exit 1
      seen = 1
      if ($0 == "## [Unreleased]" && ++unreleased > 1) exit 1
      if (index($0, "## [" version "]") == 1) exit 1
    }
    END { if (!seen) exit 1 }
  ' "${CHANGELOG_FILE}"; then
    echo "ERROR: ${CHANGELOG_FILE} must start with an Unreleased section and must not already contain version ${VERSION}." >&2
    exit 1
  fi
}

release_changelog() {
  local tmp
  tmp=$(mktemp)
  awk -v version="${VERSION}" -v date="$(date -u +%F)" '
    $0 == "## [Unreleased]" { print "## [" version "] - " date; next }
    { print }
  ' "${CHANGELOG_FILE}" > "${tmp}"
  cat "${tmp}" > "${CHANGELOG_FILE}"
  rm -f "${tmp}"
  echo "Changelog: released ${VERSION}"
}

# ==============================================================================
# MAIN SCRIPT EXECUTION
# ==============================================================================

determine_version
validate_changelog
update_schema_id
update_readme
update_examples
validate_and_migrate_examples
release_changelog
