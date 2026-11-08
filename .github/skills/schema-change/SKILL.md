---
name: schema-change
description: Use ONLY when asked to change the structure of the building blocks JSON schema (add, remove or rename properties, change types, change required). Do NOT use for documentation-only changes.
---

# Schema structure change

Do **not** create or publish a release, tag or release branch. Releases are handled by the `Release` skill.

## Steps

1. Edit `buildingblocks_schema.json` for the structural change. Do not create or edit versioned schema copies and make no unrelated changes.
2. Run `.github/skills/schema-change/scripts/schema-change.sh -c <Added|Changed|Removed|Fixed> [-b] "<description>"` (`-b` for breaking changes, which prefixes the entry with `**BREAKING:**`). It:
   - adds the entry to the `## [Unreleased]` section of `CHANGELOG.md` in the matching category;
   - if the schema `$id` does not yet end in `-SNAPSHOT.json`, increments its patch version and appends the suffix (e.g. `buildingblocks_0_1_5.json` → `buildingblocks_0_1_6-SNAPSHOT.json`); otherwise leaves it unchanged.
