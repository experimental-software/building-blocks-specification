---
name: ifml-to-building-blocks
description: Convert an IFML diagram in a .drawio file into minimal YAML for the latest published Building Block Specification.
---

# Convert IFML diagrams to Building Blocks YAML

Use only a `.drawio` file attached to the user's conversation as the diagram input. Locate the attachment in the environment's attachment storage; do not search this repository for a diagram or substitute a repository example. If no `.drawio` file is attached, ask the user to upload one and wait for it before proceeding. If several are attached and the intended file is unclear, ask the user which to use.

1. Run `python3 .github/skills/ifml-to-building-blocks/scripts/convert_ifml.py "<path-to-attached-drawio>"`, keeping standard output separate from standard error.
2. Check that the complete output parses as YAML and validates against the JSON Schema URL in its `yaml-language-server` directive, using a validator that supports JSON Schema Draft 2020-12. If validation fails, do not present the output as valid; explain the error. If validation cannot be performed, state that explicitly.
3. Return the entire standard output verbatim in one fenced `yaml` code block. Put the opening fence ` ```yaml ` on its own line, followed on the next line by the schema directive and the rest of the YAML; put the closing fence ` ``` ` on its own line after the final YAML line. Do not put introductory text on the opening fence line or omit the directive, indentation, or any part of the output. The block must be a complete, copyable YAML file.
4. If the script reports omissions on standard error, report those after the closed YAML code block, outside the YAML. Never imply that an omitted element was converted.
5. Do not create or modify repository files while converting a user's diagram. The script only reads the input and repository README and writes YAML to standard output and omission diagnostics to standard error.

The converter reads the published version and schema URL from the usage example in the repository `README.md`. It maps view containers, view components, and actions when their required information can be inferred. IFML events, flows, component parts, and other unsupported or ambiguous cells are reported as omissions.

Run the focused dependency-free tests with:

```sh
python3 -m unittest discover -s .github/skills/ifml-to-building-blocks/tests
```
