---
name: Release
description: Use when asked to release the building blocks schema, including publishing a GitHub release with the schema asset.
---

# Release

Run `.github/skills/release/scripts/release.sh [-v VERSION]`.

- With `-v X.Y.Z` the explicitly requested version is used.
- Without `-v` the version is taken from the current snapshot `$id` (`buildingblocks_X_Y_Z-SNAPSHOT.json`) without the `-SNAPSHOT` suffix. If it cannot be determined the script fails; report this to the user and do not guess a version.

The published schema URL uses the release tag:

`https://raw.githubusercontent.com/experimental-software/building-blocks-specification/refs/tags/<VERSION>/buildingblocks_schema.json`

The script updates the `$id` in `buildingblocks_schema.json` and the schema URL and `buildingblocks:` value in every versioned example in `README.md` and `examples/`. It applies explicit property rename/remove entries in the current `## [Unreleased]` changelog section to the examples when needed, validates them, and renames the section to the release version and UTC date.
