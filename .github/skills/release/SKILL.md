---
name: Release
description: Use when asked to release the building blocks schema, i.e. to set the release version in the schema `$id`, README examples, and changelog.
---

# Release

Run `.github/skills/release/scripts/release.sh [-v VERSION]`.

- With `-v X.Y.Z` the explicitly requested version is used.
- Without `-v` the version is taken from the current snapshot `$id` (`buildingblocks_X_Y_Z-SNAPSHOT.json`) without the `-SNAPSHOT` suffix. If it cannot be determined the script fails; report this to the user and do not guess a version.

The script updates the `$id` in `buildingblocks_schema.json` and every versioned example in `README.md` and `examples/` (schema URL and `buildingblocks:` value). It renames the first `## [Unreleased]` section in `CHANGELOG.md` to the release version and UTC date. It does not tag, publish or branch; do not do so unless asked.
