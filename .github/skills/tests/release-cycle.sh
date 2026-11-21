#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "${TEST_ROOT}"' EXIT
cp "${ROOT}/buildingblocks_schema.json" "${ROOT}/README.md" "${TEST_ROOT}/"
mkdir "${TEST_ROOT}/examples"
printf '# yaml-language-server: $schema=https://experimental-software.com/buildingblocks_0_1_6.json\nbuildingblocks: "0.1.6"\n' > "${TEST_ROOT}/examples/versioned.yml"
printf '# yaml-language-server: $schema=https://raw.githubusercontent.com/experimental-software/building-blocks-specification/refs/heads/main/buildingblocks_schema.json\nbuildingblocks: "0.1.7-SNAPSHOT"\n' > "${TEST_ROOT}/examples/snapshot.yml"

cat > "${TEST_ROOT}/CHANGELOG.md" <<'EOF'
# Changelog

Introduction.

## [Unreleased]

### Added

- First change.

## [0.1.5] - 2026-11-07

### Added

- Older change.
EOF

release() {
  RELEASE_ROOT="${TEST_ROOT}" bash "${ROOT}/.github/skills/release/scripts/release.sh" "$@"
}
change() {
  SCHEMA_CHANGE_ROOT="${TEST_ROOT}" bash "${ROOT}/.github/skills/schema-change/scripts/schema-change.sh" "$@"
}

release -v 0.1.6
grep -Fxq "## [0.1.6] - $(date -u +%F)" "${TEST_ROOT}/CHANGELOG.md"
! grep -Fq '## [Unreleased]' "${TEST_ROOT}/CHANGELOG.md"
grep -Fq 'buildingblocks_0_1_6.json' "${TEST_ROOT}/buildingblocks_schema.json"
grep -Fq 'buildingblocks_0_1_6.json' "${TEST_ROOT}/README.md"
grep -Fxq 'buildingblocks: 0.1.6' "${TEST_ROOT}/README.md"
cp "${TEST_ROOT}/README.md" "${TEST_ROOT}/released-readme.md"

change -c Added "Next change."
change -c Added "Another change."
change -c Fixed -b "Breaking fix."
cmp "${TEST_ROOT}/README.md" "${TEST_ROOT}/released-readme.md"
grep -Fq 'buildingblocks_0_1_7-SNAPSHOT.json' "${TEST_ROOT}/buildingblocks_schema.json"
awk '
  /^## / && !first { if ($0 != "## [Unreleased]") exit 1; first = 1 }
  END { if (!first) exit 1 }
' "${TEST_ROOT}/CHANGELOG.md"
grep -Fxq -- '- Next change.' "${TEST_ROOT}/CHANGELOG.md"
grep -Fxq -- '- Another change.' "${TEST_ROOT}/CHANGELOG.md"
grep -Fxq -- '- **BREAKING:** Breaking fix.' "${TEST_ROOT}/CHANGELOG.md"
grep -Fxq -- '- First change.' "${TEST_ROOT}/CHANGELOG.md"

release
grep -Fxq "## [0.1.7] - $(date -u +%F)" "${TEST_ROOT}/CHANGELOG.md"
grep -Fq 'buildingblocks_0_1_7.json' "${TEST_ROOT}/README.md"
grep -Fxq 'buildingblocks: "0.1.7"' "${TEST_ROOT}/examples/versioned.yml"
grep -Fxq 'buildingblocks: "0.1.7"' "${TEST_ROOT}/examples/snapshot.yml"
grep -Fq 'buildingblocks_0_1_7.json' "${TEST_ROOT}/examples/versioned.yml"
grep -Fq 'buildingblocks_0_1_7.json' "${TEST_ROOT}/examples/snapshot.yml"
if release -v 0.1.7; then
  echo "ERROR: release without an Unreleased section succeeded" >&2
  exit 1
fi

echo "Release cycle passed"
