import json
import unittest
from pathlib import Path

import jsonschema
import yaml


ROOT = Path(__file__).resolve().parents[1]
SCHEMA = json.loads((ROOT / "buildingblocks_schema.json").read_text())


class ComponentTypeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        jsonschema.Draft202012Validator.check_schema(SCHEMA)
        cls.validator = jsonschema.Draft202012Validator(SCHEMA)

    def assert_component_valid(self, component, expected):
        document = {
            "buildingblocks": "0.2.1",
            "info": {"title": "Test"},
            "components": [component],
        }
        self.assertEqual(self.validator.is_valid(document), expected)

    def test_inventory_example_without_types(self):
        fixture = ROOT / "tests/fixtures/optional-component-type.yml"
        document = yaml.safe_load(fixture.read_text())
        self.validator.validate(document)

    def test_untyped_component_can_have_generic_properties_and_children(self):
        self.assert_component_valid({
            "name": "Container",
            "properties": {"custom": True},
            "children": [{"name": "Child"}],
        }, True)

    def test_type_specific_properties_remain_enforced(self):
        for component_type, properties in (
            ("Select", {"options": ["one"]}),
            ("List", {"items": ["one"]}),
            ("RadioGroup", {"options": ["one"]}),
            ("SplitButton", {"options": [{"textLabel": "one"}]}),
        ):
            with self.subTest(component_type=component_type):
                component = {"name": "Test", "type": component_type}
                self.assert_component_valid(component, False)
                self.assert_component_valid({**component, "properties": {}}, False)
                self.assert_component_valid({**component, "properties": properties}, True)

        self.assert_component_valid(
            {"name": "Test", "type": "Input", "properties": {"minLength": -1}},
            False,
        )

    def test_leaf_and_custom_component_types(self):
        for component_type in (
            "Text", "Input", "Button", "Select", "List", "RadioGroup", "SplitButton"
        ):
            properties = {
                "Select": {"options": ["one"]},
                "List": {"items": ["one"]},
                "RadioGroup": {"options": ["one"]},
                "SplitButton": {"options": [{"textLabel": "one"}]},
            }
            component = {
                "name": "Test",
                "type": component_type,
                "children": [{"name": "Child"}],
            }
            if component_type in properties:
                component["properties"] = properties[component_type]
            with self.subTest(component_type=component_type):
                self.assert_component_valid(component, False)

        self.assert_component_valid(
            {"name": "Test", "type": "Custom", "children": [{"name": "Child"}]},
            True,
        )
        self.assert_component_valid({"name": "Test", "type": None}, False)


if __name__ == "__main__":
    unittest.main()
