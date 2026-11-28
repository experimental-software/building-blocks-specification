#!/usr/bin/env python3
"""Convert supported IFML elements in a draw.io diagram to Building Blocks YAML."""

from __future__ import annotations

import argparse
import base64
import binascii
import html
from html.parser import HTMLParser
import json
import os
import re
import sys
import urllib.parse
import xml.etree.ElementTree as ET
import zlib
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable


SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
ROOT = Path(SCRIPT_DIR) / "../../../../"
SCHEMA = ROOT / "buildingblocks_schema.json"
README = ROOT / "README.md"
VERSION_RE = re.compile(
    r"yaml-language-server:\s*\$schema=https://raw\.githubusercontent\.com/"
    r"experimental-software/building-blocks-specification/refs/tags/"
    r"(\d+\.\d+\.\d+)/buildingblocks_schema\.json"
)
STEREOTYPE_RE = re.compile(r"«([^»]+)»")
REQUIRED_PROPERTY_TYPES = {"SplitButton"}
LEAF_COMPONENT_TYPES = {"Text", "Input", "Button", "SplitButton"}
COMPONENT_PART_STEREOTYPES = {
    "ActivationExpression",
    "DataBinding",
    "DynamicBehavior",
    "InputParameter",
    "ParamBindingGroup",
}


@dataclass
class Component:
    cell_id: str
    type: str | None
    name: str
    parent_container_id: str | None
    is_container: bool = False
    children: list[Component] = field(default_factory=list)

    def as_mapping(self) -> dict:
        result = {"name": self.name}
        if self.type:
            result = {"type": self.type, **result}
        if self.children:
            result["children"] = [child.as_mapping() for child in self.children]
        return result


class _TextExtractor(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag in {"br", "div", "p", "li"}:
            self.parts.append(" ")

    def handle_endtag(self, tag: str) -> None:
        if tag in {"div", "p", "li"}:
            self.parts.append(" ")

    def handle_data(self, data: str) -> None:
        self.parts.append(data)


def _local_name(element: ET.Element) -> str:
    return element.tag.rsplit("}", 1)[-1]


def _parse_compressed_diagram(diagram: ET.Element) -> ET.Element:
    try:
        encoded = "".join("".join(diagram.itertext()).split())
        raw = base64.b64decode(encoded, validate=True)
        try:
            decoded = zlib.decompress(raw, -zlib.MAX_WBITS)
        except zlib.error:
            decoded = zlib.decompress(raw)
        return ET.fromstring(urllib.parse.unquote(decoded.decode("utf-8")))
    except (binascii.Error, zlib.error, UnicodeDecodeError, ET.ParseError) as exc:
        raise ValueError("Could not read the compressed diagram page.") from exc


def _graph_models(root: ET.Element) -> list[ET.Element]:
    if _local_name(root) == "mxGraphModel":
        return [root]
    models: list[ET.Element] = []
    for child in root.iter():
        if _local_name(child) == "mxGraphModel":
            models.append(child)
        elif _local_name(child) == "diagram" and not any(
            _local_name(nested) == "mxGraphModel" for nested in child
        ):
            models.append(_parse_compressed_diagram(child))
    if not models:
        raise ValueError("No diagram page was found in the draw.io file.")
    return models


def _decode_xml(path: Path) -> list[ET.Element]:
    if not path.is_file():
        raise ValueError(f"Diagram input is not a regular file: {path}")
    try:
        root = ET.parse(path).getroot()
    except (ET.ParseError, OSError) as exc:
        raise ValueError(f"Could not read draw.io XML: {exc}") from exc
    return _graph_models(root)


def _style(cell: ET.Element) -> dict[str, str]:
    values: dict[str, str] = {}
    for token in cell.get("style", "").split(";"):
        if "=" in token:
            key, value = token.split("=", 1)
            values[key] = value
        elif token:
            values[token] = "1"
    return values


def _plain_text(value: str) -> str:
    decoded = value
    for _ in range(3):
        unescaped = html.unescape(decoded)
        if unescaped == decoded:
            break
        decoded = unescaped
    extractor = _TextExtractor()
    extractor.feed(decoded)
    return " ".join("".join(extractor.parts).replace("\xa0", " ").split())


def _label(value: str) -> tuple[str | None, str]:
    text = _plain_text(value)
    match = STEREOTYPE_RE.search(text)
    if not match:
        return None, text.strip()
    name = (text[: match.start()] + " " + text[match.end() :]).strip()
    return match.group(1).strip(), " ".join(name.split())


def _read_schema_info() -> tuple[str, str]:
    try:
        schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"Could not read the current Building Blocks schema: {exc}") from exc
    schema_url = schema.get("$id")
    if not isinstance(schema_url, str) or not schema_url:
        raise ValueError("The current Building Blocks schema has no valid $id.")

    try:
        readme = README.read_text(encoding="utf-8")
    except OSError as exc:
        raise ValueError(f"Could not read the repository README: {exc}") from exc
    match = VERSION_RE.search(readme)
    if not match:
        raise ValueError("Could not find the specification version in the README usage example.")
    major, minor, patch = (int(part) for part in match.group(1).split("."))
    version = f"{major}.{minor}.{patch + 1}-SNAPSHOT"
    return version, schema_url


def _is_container(cell: ET.Element, children: dict[str, list[ET.Element]]) -> bool:
    if _style(cell).get("childLayout") != "stackLayout":
        return False
    child_cells = children.get(cell.get("id", ""), [])
    return any("swimlane" in _style(child) for child in child_cells)


def _header_and_body(
    cell: ET.Element, children: dict[str, list[ET.Element]]
) -> tuple[ET.Element | None, ET.Element | None]:
    header = None
    body = None
    for child in children.get(cell.get("id", ""), []):
        style = _style(child)
        if "swimlane" in style:
            body = child
        elif style.get("shape") != "component" and child.get("value", "").strip():
            if header is None:
                header = child
    return header, body


def _diagram_cells(model: ET.Element) -> tuple[list[ET.Element], dict[str, list[ET.Element]]]:
    cells = [element for element in model.iter() if _local_name(element) == "mxCell"]
    children: dict[str, list[ET.Element]] = {}
    for cell in cells:
        children.setdefault(cell.get("parent", ""), []).append(cell)
    return cells, children


def _report(cell_id: str, label: str, reason: str) -> dict[str, str]:
    return {"cell": cell_id or "(no id)", "label": label or "(empty label)", "reason": reason}


def _nearest_container(
    parent_id: str,
    body_to_container: dict[str, str],
    cells_by_id: dict[str, ET.Element],
    known_container_ids: set[str],
) -> str | None:
    current = parent_id
    while current and current not in {"0", "1"}:
        if current in body_to_container and body_to_container[current] in known_container_ids:
            return body_to_container[current]
        parent = cells_by_id.get(current)
        if parent is None:
            break
        current = parent.get("parent", "")
    return None


def _position(cell: ET.Element) -> tuple[float, float]:
    geometry = next(
        (child for child in cell if _local_name(child) == "mxGeometry"),
        None,
    )
    if geometry is None:
        return (0.0, 0.0)
    try:
        y = float(geometry.get("y", "0"))
        x = float(geometry.get("x", "0"))
    except ValueError:
        return (0.0, 0.0)
    return (y, x)




def _convert_model(model: ET.Element) -> tuple[list[Component], list[dict[str, str]], list[dict[str, str]]]:
    cells, children = _diagram_cells(model)
    cells_by_id = {cell.get("id", ""): cell for cell in cells}
    components_by_id: dict[str, Component] = {}
    actions: list[dict[str, str]] = []
    omissions: list[dict[str, str]] = []
    body_to_container: dict[str, str] = {}
    consumed: set[str] = set()

    for cell in cells:
        cell_id = cell.get("id", "")
        if not _is_container(cell, children):
            continue
        header, body = _header_and_body(cell, children)
        if header is None or body is None:
            omissions.append(_report(cell_id, _plain_text(cell.get("value", "")),
                                     "View container title or body could not be inferred."))
            consumed.add(cell_id)
            continue
        stereotype, name = _label(header.get("value", ""))
        component_type = stereotype or None
        if not name:
            omissions.append(_report(cell_id, _plain_text(header.get("value", "")),
                                     "View container requires a non-empty name."))
            consumed.update({cell_id, header.get("id", ""), body.get("id", "")})
            continue
        component = Component(
            cell_id=cell_id,
            type=component_type,
            name=name,
            parent_container_id=None,
            is_container=True,
        )
        components_by_id[cell_id] = component
        body_to_container[body.get("id", "")] = cell_id
        consumed.update({cell_id, header.get("id", ""), body.get("id", "")})
        for candidate in children.get(header.get("id", ""), []):
            if _style(candidate).get("shape") == "component":
                consumed.add(candidate.get("id", ""))

    container_ids = set(components_by_id)
    for cell_id, component in components_by_id.items():
        if component.is_container:
            component.parent_container_id = _nearest_container(
                cells_by_id[cell_id].get("parent", ""),
                body_to_container,
                cells_by_id,
                container_ids,
            )

    for cell in cells:
        cell_id = cell.get("id", "")
        if cell_id in consumed or cell_id in {"0", "1"}:
            continue
        if cell.get("edge") == "1":
            attached_labels = [
                _plain_text(child.get("value", ""))
                for child in children.get(cell_id, [])
                if _style(child).get("edgeLabel") == "1"
            ]
            label = _plain_text(cell.get("value", ""))
            if attached_labels:
                label = " ".join(filter(None, [label, *attached_labels]))
            omissions.append(_report(
                cell_id,
                label,
                "IFML flow/relationship is not represented by the Building Block schema.",
            ))
            consumed.update(child.get("id", "") for child in children.get(cell_id, []))
            continue

        style = _style(cell)
        shape = style.get("shape", "text" if "text" in style else "")
        value = cell.get("value", "")
        text = _plain_text(value)
        stereotype, name = _label(value)
        if shape == "component" or "swimlane" in style or style.get("edgeLabel") == "1":
            consumed.add(cell_id)
            continue
        if shape == "hexagon":
            if text:
                actions.append({"name": text})
            else:
                omissions.append(_report(cell_id, text, "Action name is missing."))
            continue
        if shape in {"note"}:
            omissions.append(_report(cell_id, text, "IFML annotation is not represented by the Building Block schema."))
            continue
        if shape == "parallelogram":
            omissions.append(_report(cell_id, text, "Parameter binding is not represented by the Building Block schema."))
            continue
        if shape == "mxgraph.bpmn.event":
            omissions.append(_report(cell_id, text, "IFML event is not represented by the Building Block schema."))
            continue

        component_type: str | None = None
        if shape == "mxgraph.bpmn.task2":
            component_type = stereotype
            if component_type in REQUIRED_PROPERTY_TYPES:
                omissions.append(_report(
                    cell_id, text,
                    f"{component_type} requires schema properties that cannot be inferred from this diagram.",
                ))
                continue
        elif shape in {"text", ""}:
            if stereotype:
                if stereotype in COMPONENT_PART_STEREOTYPES:
                    omissions.append(_report(
                        cell_id, text,
                        "IFML component part has no schema mapping.",
                    ))
                    continue
                component_type = stereotype
                if component_type in REQUIRED_PROPERTY_TYPES:
                    omissions.append(_report(
                        cell_id, text,
                        f"{component_type} requires schema properties that cannot be inferred from this diagram.",
                    ))
                    continue
            elif shape == "text" and text:
                name = text
            elif stereotype is None and text:
                omissions.append(_report(cell_id, text, "IFML component part or label has no schema mapping."))
                continue
        elif shape:
            omissions.append(_report(cell_id, text, "This diagram element has an unsupported shape."))
            continue

        if not name:
            omissions.append(_report(cell_id, text, "Component name could not be inferred."))
            continue
        parent_container_id = _nearest_container(
            cell.get("parent", ""), body_to_container, cells_by_id, container_ids
        )
        components_by_id[cell_id] = Component(
            cell_id=cell_id,
            type=component_type,
            name=name,
            parent_container_id=parent_container_id,
        )

    for component in components_by_id.values():
        if component.is_container and component.type in LEAF_COMPONENT_TYPES:
            nested = [
                child for child in components_by_id.values()
                if child.parent_container_id == component.cell_id
            ]
            if nested:
                omissions.append(_report(
                    component.cell_id,
                    component.name,
                    f"Schema component type '{component.type}' cannot contain child components; "
                    "nested elements were promoted to the enclosing container.",
                ))
                for child in nested:
                    child.parent_container_id = component.parent_container_id

    for component in components_by_id.values():
        if component.parent_container_id:
            components_by_id[component.parent_container_id].children.append(component)

    for component in components_by_id.values():
        component.children.sort(key=lambda child: _position(cells_by_id[child.cell_id]))
    top_level = [
        component for component in components_by_id.values()
        if component.parent_container_id is None
    ]
    top_level.sort(key=lambda component: _position(cells_by_id[component.cell_id]))
    return top_level, actions, omissions


def _yaml_scalar(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def _emit_yaml(document: dict) -> str:
    lines = [
        f"# yaml-language-server: $schema={document['schema']}",
        f"buildingblocks: {_yaml_scalar(document['version'])}",
        "info:",
        f"  title: {_yaml_scalar(document['title'])}",
        "components:" if document["components"] else "components: []",
    ]

    def emit_component(component: dict, indent: int) -> None:
        if component.get("type"):
            lines.append(" " * indent + f"- type: {_yaml_scalar(component['type'])}")
            lines.append(" " * (indent + 2) + f"name: {_yaml_scalar(component['name'])}")
        else:
            lines.append(" " * indent + f"- name: {_yaml_scalar(component['name'])}")
        if component.get("children"):
            lines.append(" " * (indent + 2) + "children:")
            for child in component["children"]:
                emit_component(child, indent + 4)

    for component in document["components"]:
        emit_component(component, 2)
    if document["actions"]:
        lines.append("actions:")
        for action in document["actions"]:
            lines.append(f"  - name: {_yaml_scalar(action['name'])}")
    return "\n".join(lines) + "\n"


def convert(path: Path) -> tuple[str, list[dict[str, str]]]:
    version, schema_url = _read_schema_info()
    models = _decode_xml(path)
    components: list[Component] = []
    actions: list[dict[str, str]] = []
    omissions: list[dict[str, str]] = []
    for model in models:
        model_components, model_actions, model_omissions = _convert_model(model)
        components.extend(model_components)
        actions.extend(model_actions)
        omissions.extend(model_omissions)
    title = next(
        (component.name for component in components if component.is_container),
        path.stem.replace("-", " ").replace("_", " ").title(),
    )
    yaml = _emit_yaml({
        "schema": schema_url,
        "version": version,
        "title": title,
        "components": [component.as_mapping() for component in components],
        "actions": actions,
    })
    return yaml, omissions


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("diagram", type=Path, help="path to a .drawio file")
    parser.add_argument("output", type=Path, help="path to the output YAML file")
    args = parser.parse_args(argv)
    try:
        if args.diagram.resolve() == args.output.resolve() or (
            args.diagram.exists() and args.output.exists() and args.diagram.samefile(args.output)
        ):
            raise ValueError("The input diagram and output YAML must be different files.")
        if args.output.exists() and not args.output.is_file():
            raise ValueError(f"YAML output is not a regular file: {args.output}")
        yaml, omissions = convert(args.diagram)
        args.output.write_text(yaml, encoding="utf-8")
    except (ValueError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    if omissions:
        print("\nOmissions:", file=sys.stderr)
        for omission in omissions:
            print(
                f"- Diagram element {omission['cell']} ({omission['label']}): {omission['reason']}",
                file=sys.stderr,
            )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
