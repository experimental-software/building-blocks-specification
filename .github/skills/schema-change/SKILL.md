---
name: schema-change
description: Use ONLY when asked to change the structure of the building blocks JSON schema (add, remove or rename properties, change types, change required). Do NOT use for documentation-only changes.
---

# Schema structure change

Scripts live in `.github/skills/schema-change/scripts/`. Run them instead of doing their work by hand; the agent only classifies the change and writes prose/JSON edits.

## Steps

1. **Classify** each change: `addition` (new optional property, loosened constraint) or `breaking` (remove/rename property, type change, newly required, tightened constraint). Breaking → minor bump, addition → patch bump; the higher one wins.
2. **Copy**: `scripts/copy-schema.sh <class>...` copies the latest `schema/buildingblocks_X_Y_Z.json` to the new version, updates `$id`/version strings, and prints `<old> <new>`. Edit **only the new copy**, never older schemas. (`latest-version.sh` / `next-version.sh` are used internally.)
3. **README**: `scripts/update-readme.sh <old> <new>`, then edit the usage example by hand for affected properties.
4. **Changelog**: `scripts/add-changelog.sh <new> <Added|Changed|Removed|Fixed> <breaking|non-breaking> "<description>"` (breaking entries get a `**BREAKING:**` prefix). Run once per section needed; edit the file by hand if merging sections.
5. **Validate**: `scripts/validate.sh <old> <new>` must print `OK`.
