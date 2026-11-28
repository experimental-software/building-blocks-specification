---
name: schema-change
description: Use ONLY when asked to change the structure of the building blocks JSON schema (add, remove or rename properties, change types, change required). Do NOT use for documentation-only changes.
---

# Schema structure change

Do **not** create or publish a release, tag or release branch. Releases are handled by the `Release` skill.

## Steps

1. Edit `buildingblocks_schema.json` for the structural change. Do not create or edit versioned schema copies and make no unrelated changes.
2. Run `.github/skills/schema-change/scripts/schema-change.sh -c <Added|Changed|Removed|Fixed> [-b] "<description>"` (`-b` for breaking changes, which prefixes the entry with `**BREAKING:**`). It:
   - adds the entry to the `## [Unreleased]` section of `CHANGELOG.md` in the matching category, creating it as the first section after the introduction if needed;
   - sets the draft schema `$id` to `https://github.com/experimental-software/building-blocks-specification/blob/main/buildingblocks_schema.json`.

Do not include unreleased changes in `README.md`; its examples describe the latest release.

## Examples

Changes to files in `examples/` are out of scope for the changelog; do not add changelog entries for them.

3. Every new file in `examples/` must start with the line `# yaml-language-server: $schema=https://raw.githubusercontent.com/experimental-software/building-blocks-specification/refs/heads/main/buildingblocks_schema.json` and set `buildingblocks:` to the appropriate specification version. For unreleased drafts, use the patch version after incrementing the latest version in the README usage example, with the `-SNAPSHOT` suffix (e.g. `"0.1.7-SNAPSHOT"` after `"0.1.6"`). The schema's `buildingblocks` pattern allows this suffix. Use this pattern only for new examples.
4. Validate the schema and all examples, e.g. `check-jsonschema --schemafile buildingblocks_schema.json examples/*.yml`.
