#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=${RELEASE_ROOT:-$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel)}
cd "${ROOT}"

for dependency in git jq gh; do
  if ! command -v "${dependency}" >/dev/null 2>&1; then
    echo "ERROR: ${dependency} not installed" >&2
    exit 1
  fi
done

if [[ -n "$(git status --porcelain -- buildingblocks_schema.json README.md CHANGELOG.md examples/)" ]]; then
  echo "ERROR: commit the release files before publishing." >&2
  exit 1
fi

id=$(jq -er '."$id"' buildingblocks_schema.json)
if [[ ! "${id}" =~ buildingblocks_([0-9]+)_([0-9]+)_([0-9]+)\.json$ ]]; then
  echo "ERROR: schema \$id is not a release version: ${id}" >&2
  exit 1
fi
version="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"

notes=$(awk -v version="${version}" '
  /^## / {
    if (!seen) {
      if (index($0, "## [" version "] - ") != 1) exit 1
      seen = 1
      next
    }
    exit
  }
  seen { print }
  END { if (!seen) exit 1 }
' CHANGELOG.md) || {
  echo "ERROR: the latest changelog section must be release ${version}." >&2
  exit 1
}

commit=$(git rev-parse HEAD)
tags=$(gh api "repos/{owner}/{repo}/git/matching-refs/tags/${version}")
if jq -e --arg ref "refs/tags/${version}" 'any(.[]; .ref == $ref)' <<<"${tags}" >/dev/null; then
  echo "ERROR: tag ${version} already exists on GitHub." >&2
  exit 1
fi

gh release create "${version}" buildingblocks_schema.json \
  --target "${commit}" --title "${version}" --notes "${notes}"
