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

After the script succeeds, complete the release automatically:

1. Check that the version's Git tag and GitHub release do not already exist. Never overwrite an existing release or tag.
2. Review the script's changes and validation output. Commit the release changes on the current release branch with a message such as `Release X.Y.Z`, including the required Copilot co-author trailer when creating a commit.
3. Create and push an annotated Git tag named `X.Y.Z` at the release commit, and push the release commit to `origin`.
4. Publish the GitHub release with `buildingblocks_schema.json` attached, for example with `gh release create X.Y.Z buildingblocks_schema.json --verify-tag --title "X.Y.Z" --generate-notes`.

The script only prepares and validates the release files; it does not create commits, tags, or GitHub releases. If a commit, push, tag, or publication fails, report the exact incomplete step and do not claim the release was published.
