#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "${TEST_ROOT}"' EXIT
mkdir -p "${TEST_ROOT}/repo/examples" "${TEST_ROOT}/bin"
jq '."$id" = "https://experimental-software.com/buildingblocks_0_1_7.json"' \
  "${ROOT}/buildingblocks_schema.json" > "${TEST_ROOT}/repo/buildingblocks_schema.json"
cat > "${TEST_ROOT}/repo/CHANGELOG.md" <<'EOF'
# Changelog

## [0.1.7] - 2026-11-21

### Added

- Release change.

## [0.1.6] - 2026-11-15

- Older change.
EOF
echo 'example' > "${TEST_ROOT}/repo/README.md"
echo 'example' > "${TEST_ROOT}/repo/examples/example.yml"
cat > "${TEST_ROOT}/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == api ]]; then
  [[ "${FAIL_API:-}" != true ]] || exit 1
  printf '%s\n' "${TAGS:-[]}"
elif [[ "$1 $2" == "release create" ]]; then
  printf '%s\n' "$@" > "${TEST_ROOT}/args"
  cp buildingblocks_schema.json "${TEST_ROOT}/asset.json"
else
  exit 1
fi
EOF
chmod +x "${TEST_ROOT}/bin/gh"
export TEST_ROOT
export PATH="${TEST_ROOT}/bin:${PATH}"
git -C "${TEST_ROOT}/repo" init -q
git -C "${TEST_ROOT}/repo" -c user.name=Test -c user.email=test@example.com \
  add buildingblocks_schema.json CHANGELOG.md README.md examples/
commit_fixture() {
  git -C "${TEST_ROOT}/repo" -c user.name=Test -c user.email=test@example.com \
    -c commit.gpgsign=false commit -q -m "$1" \
    -m 'Co-authored-by: copilot-swe-agent[bot] <198982749+Copilot@users.noreply.github.com>'
}
commit_fixture 'Prepare release'

publish() {
  RELEASE_ROOT="${TEST_ROOT}/repo" bash "${ROOT}/.github/skills/release/scripts/publish-release.sh"
}
expect_failure() {
  if publish; then
    echo "ERROR: publishing unexpectedly succeeded" >&2
    exit 1
  fi
}

publish
grep -Fxq '0.1.7' "${TEST_ROOT}/args"
grep -Fxq "$(git -C "${TEST_ROOT}/repo" rev-parse HEAD)" "${TEST_ROOT}/args"
grep -Fxq 'buildingblocks_schema.json' "${TEST_ROOT}/args"
grep -Fxq -- '- Release change.' "${TEST_ROOT}/args"
! grep -Fq 'Older change.' "${TEST_ROOT}/args"
cmp "${TEST_ROOT}/repo/buildingblocks_schema.json" "${TEST_ROOT}/asset.json"

TAGS='[{"ref":"refs/tags/0.1.7"}]' expect_failure
FAIL_API=true expect_failure
echo 'uncommitted' >> "${TEST_ROOT}/repo/examples/example.yml"
expect_failure
git -C "${TEST_ROOT}/repo" add examples/example.yml
commit_fixture 'Commit example'
sed -i 's/## \[0.1.7\]/## [0.1.8]/' "${TEST_ROOT}/repo/CHANGELOG.md"
git -C "${TEST_ROOT}/repo" add CHANGELOG.md
commit_fixture 'Change changelog'
expect_failure

echo "Publish release checks passed"
