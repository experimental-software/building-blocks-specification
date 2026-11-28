---
name: ifml-to-building-blocks
description: Convert an IFML diagram in a .drawio file into minimal YAML for the current Building Block Specification.
---

# Convert IFML diagrams to Building Blocks YAML

Use only a `.drawio` file or draw.io XML supplied in the user's conversation as the diagram input. Do not search this repository for a diagram or substitute a repository example. If no diagram is supplied, ask the user to upload one and wait for it before proceeding.

Read supplied diagram text from the conversation itself; an uploaded file is often absent from the filesystem, which is not a reason to stop. If the file is accessible on disk, passing its path is fine. Otherwise write the supplied XML verbatim to a temporary `.drawio` file. If several diagrams are supplied and the intended one is unclear, ask the user which to use.

1. Run `python3 .github/skills/ifml-to-building-blocks/scripts/convert_ifml.py "<path-to-diagram.drawio>" "<path-to-temporary-output.yaml>"`. The input and output must be separate regular files. Keep omission diagnostics on standard error.
2. Check that the complete output file parses as YAML and validates against the JSON Schema URL in its `yaml-language-server` directive, using a validator that supports JSON Schema Draft 2020-12. If validation fails, do not present the output as valid; explain the error. If validation cannot be performed, state that explicitly.
3. Return the entire output file verbatim in one fenced `yaml` code block. Put the opening fence ` ```yaml ` on its own line, followed on the next line by the schema directive and the rest of the YAML; put the closing fence ` ``` ` on its own line after the final YAML line. Do not put introductory text on the opening fence line or omit the directive, indentation, or any part of the output. The block must be a complete, copyable YAML file.
4. If the script reports omissions on standard error, report those after the closed YAML code block, outside the YAML. Never imply that an omitted element was converted.
5. Do not create or modify repository files while converting a user's diagram. The script reads the input and current schema, and, for snapshots, the repository README version; it writes YAML to the specified output file and reports omissions on standard error. Remove temporary files when they are no longer needed.

The converter reads `buildingblocks_schema.json` relative to the script directory and uses its `$id` as the schema URL. If the `$id` contains a tag, it uses that tag as the `buildingblocks` version. Otherwise, it increments the patch version in the first repository `README.md` usage example and adds the `-SNAPSHOT` suffix. Do not look up or use the latest published schema URL. It maps view containers, view components, and actions when their required information can be inferred. An explicit stereotype inside `«...»` becomes the component type without substitution; components without a stereotype get no `type` property. IFML events, flows, component parts, and other unsupported or ambiguous elements are reported as omissions.

Run the focused dependency-free tests with:

```sh
python3 -m unittest discover -s .github/skills/ifml-to-building-blocks/tests
```
