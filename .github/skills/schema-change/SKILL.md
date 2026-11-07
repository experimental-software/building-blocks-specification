---
name: schema-change
description: Use ONLY when asked to change the structure of the building blocks JSON schema (add, remove or rename properties, change types, change required). Do NOT use for documentation-only changes.
---

# Schema structure change

Scripts live in `.github/skills/schema-change/scripts/`. Run them instead of doing their work by hand; the agent only classifies the change and writes prose/JSON edits.

## Steps

1. **Classify** each change: `addition` (new optional property, loosened constraint) or `breaking` (remove/rename property, type change, newly required, tightened constraint). Breaking → minor bump, addition → patch bump; the higher one wins.
2. **Update schema**: `scripts/update-schema-id.sh <class>...` updates the `$id` in the root `buildingblocks_schema.json` to the next version and prints `<old> <new>`. Edit the root schema for the structural change; do not create or edit versioned schema copies. (`latest-version.sh` / `next-version.sh` are used internally.)
3. **README**: `scripts/update-readme.sh <old> <new>`, then edit the usage example by hand for affected properties.
4. **Changelog**: `scripts/add-changelog.sh <new> <Added|Changed|Removed|Fixed> <breaking|non-breaking> "<description>"` (breaking entries get a `**BREAKING:**` prefix). Run once per section needed; edit the file by hand if merging sections.
5. **Validate**: `scripts/validate.sh <old> <new>` must print `OK` for the root schema and its README/changelog references.
