---
name: ifml-to-building-blocks
description: Convert an IFML diagram in a .drawio file into minimal YAML for the latest published Building Block Specification.
---

# Convert IFML diagrams to Building Blocks YAML

When the user provides a `.drawio` file:

1. Run `python3 .github/skills/ifml-to-building-blocks/scripts/convert_ifml.py <path-to-drawio>`.
2. Return the script's standard output verbatim inside a `yaml` code block. It is the complete, copyable YAML snippet and includes a `yaml-language-server` schema directive.
3. If the script reports omissions on standard error, report those after the YAML code block, outside the YAML. Never imply that an omitted element was converted.
4. Do not create or modify files while converting a user's diagram. The script only reads the input and repository README and writes YAML to standard output and omission diagnostics to standard error.

The converter reads the published version and schema URL from the usage example in the repository `README.md`. It maps view containers, view components, and actions when their required information can be inferred. IFML events, flows, component parts, and other unsupported or ambiguous cells are reported as omissions.

Run the focused dependency-free tests with:

```sh
python3 -m unittest discover -s .github/skills/ifml-to-building-blocks/tests
```
