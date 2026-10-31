# Building Blocks Specification

This repository contains a JSON schema for describing the building blocks of user interfaces.

## Usage

The intended use is to create a YAML file that is structured according to the referred `buildingblocks` JSON schema:

```yml
# yaml-language-server: $schema=https://experimental-software.github.io/building-blocks-specification/schema/buildingblocks_0_1_1.json
buildingblocks: 0.1.1
info:
  title: Product Search
components:
  - name: Product Catalog
    type: Window
    children:
      - type: Text
        name: Product Search
      - type: Input
        name: Product
        properties:
          minLength: 1
          maxLength: 255
          placeholder: What is the searched product name?
          pattern: '[\s\S]*\S[\s\S]*'
      - type: Button
        name: Search
  - name: Search Results
    type: Alert Dialog
    children:
      - type: Text
        name: Found Article Names
      - type: Button
        name: Close
```

## Alternatives

- https://github.com/gcsebas99/web-ui-component-spec-mcp
- https://nathanacurtis.substack.com/p/spec-driven-ui-component-development

## References

- https://json-schema.org/
- https://en.wikipedia.org/wiki/Interaction_Flow_Modeling_Language
- https://en.wikipedia.org/wiki/OpenAPI_Specification
- https://m3.material.io/
- https://www.qt.io/software-insights/atomic-design-systems-why-the-labels-dont-matter
