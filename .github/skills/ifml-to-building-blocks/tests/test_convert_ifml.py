import base64
from pathlib import Path
import subprocess
import tempfile
import unittest
import urllib.parse
import zlib

import sys

SCRIPT_DIR = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPT_DIR))

import convert_ifml  # noqa: E402


def diagram(cells: str) -> str:
    return f"""<mxfile><diagram name="Page-1"><mxGraphModel><root>
      <mxCell id="0"/><mxCell id="1" parent="0"/>{cells}
    </root></mxGraphModel></diagram></mxfile>"""


class ConvertIfmlTests(unittest.TestCase):
    def test_maps_view_containers_and_components(self):
        source = diagram("""
          <mxCell id="10" parent="1" vertex="1" value=""
            style="childLayout=stackLayout;"><mxGeometry as="geometry"/></mxCell>
          <mxCell id="11" parent="10" vertex="1" value="Homepage"
            style="align=left;"><mxGeometry as="geometry"/></mxCell>
          <mxCell id="12" parent="10" vertex="1" value=""
            style="swimlane=1;"><mxGeometry as="geometry"/></mxCell>
          <mxCell id="13" parent="12" vertex="1"
            value="&lt;div&gt;«Text»&lt;/div&gt;&lt;span&gt;Headline&lt;/span&gt;"
            style="shape=mxgraph.bpmn.task2;"><mxGeometry as="geometry"/></mxCell>
          <mxCell id="14" parent="12" vertex="1"
            value="&lt;div&gt;«Input»&lt;/div&gt;&lt;span&gt;Name&lt;/span&gt;"
            style="shape=mxgraph.bpmn.task2;"><mxGeometry as="geometry"/></mxCell>
          <mxCell id="15" parent="12" vertex="1" value=""
            style="childLayout=stackLayout;"><mxGeometry y="200" as="geometry"/></mxCell>
          <mxCell id="18" parent="15" vertex="1" value="«Alert Dialog» Greeting"/>
          <mxCell id="16" parent="15" vertex="1" value=""
            style="swimlane=1;"><mxGeometry as="geometry"/></mxCell>
          <mxCell id="17" parent="16" vertex="1"
            value="&lt;div&gt;«Button»&lt;/div&gt;&lt;span&gt;Close&lt;/span&gt;"
            style="shape=mxgraph.bpmn.task2;"><mxGeometry as="geometry"/></mxCell>
        """)
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "desktop.ifml.drawio"
            path.write_text(source, encoding="utf-8")
            output, omissions = convert_ifml.convert(path)

        self.assertIn("refs/tags/0.2.0/buildingblocks_schema.json", output)
        self.assertIn('type: "Window"', output)
        self.assertIn('type: "Alert Dialog"', output)
        self.assertIn('name: "Headline"', output)
        self.assertIn('name: "Name"', output)
        self.assertIn('name: "Close"', output)
        self.assertEqual(omissions, [])

    def test_maps_actions_and_reports_unrepresentable_elements(self):
        source = diagram("""
          <mxCell id="20" parent="1" vertex="1" value="Send"
            style="shape=hexagon;"/><mxGeometry as="geometry"/>
          <mxCell id="21" parent="1" vertex="1" value="«DataBinding» Items"
            style="rounded=0;whiteSpace=wrap;"/>
          <mxCell id="22" parent="1" vertex="1" value="«ActivationExpression» x = 1"
            style="shape=note;"/>
          <mxCell id="23" parent="1" vertex="1" value="contact → contactID"
            style="shape=parallelogram;"/>
          <mxCell id="24" parent="1" vertex="1" value=""
            style="shape=mxgraph.bpmn.event;"/>
          <mxCell id="25" parent="1" edge="1" value=""
            style="dashed=1;endArrow=classic;"/>
        """)
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "diagram.drawio"
            path.write_text(source, encoding="utf-8")
            output, omissions = convert_ifml.convert(path)

        self.assertIn('actions:\n  - name: "Send"', output)
        self.assertEqual(len(omissions), 5)
        self.assertTrue(any("component part" in item["reason"] for item in omissions))
        self.assertTrue(any("annotation" in item["reason"] for item in omissions))
        self.assertTrue(any("Parameter binding" in item["reason"] for item in omissions))
        self.assertTrue(any("event" in item["reason"] for item in omissions))
        self.assertTrue(any("flow/relationship" in item["reason"] for item in omissions))

    def test_omits_unknown_components_and_types_with_required_properties(self):
        source = diagram("""
          <mxCell id="30" parent="1" vertex="1" value="Unknown"
            style="shape=mxgraph.bpmn.task2;"/>
          <mxCell id="31" parent="1" vertex="1" value="«SplitButton» Choose"
            style="shape=mxgraph.bpmn.task2;"/>
          <mxCell id="32" parent="1" vertex="1" value="«Button»"
            style="shape=mxgraph.bpmn.task2;"/>
        """)
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "diagram.drawio"
            path.write_text(source, encoding="utf-8")
            output, omissions = convert_ifml.convert(path)

        self.assertIn("components: []\n", output)
        self.assertNotIn("Choose", output)
        self.assertNotIn('"Button"', output)
        self.assertEqual(len(omissions), 3)
        self.assertTrue(any("schema properties" in item["reason"] for item in omissions))
        self.assertTrue(any("type or non-empty name" in item["reason"] for item in omissions))

    def test_maps_module_text_and_list_components(self):
        source = diagram("""
          <mxCell id="40" parent="1" vertex="1" value=""
            style="childLayout=stackLayout;fillColor=#f5f5f5;strokeColor=#666666;"/>
          <mxCell id="41" parent="40" vertex="1" value="PreferenceSetter"/>
          <mxCell id="42" parent="40" vertex="1" value="" style="swimlane=1;"/>
          <mxCell id="43" parent="42" vertex="1" value="Text"
            style="text;html=1;"/>
          <mxCell id="44" parent="42" vertex="1" value="«List» MessageList"
            style="text;html=1;"/>
        """)
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "module.drawio"
            path.write_text(source, encoding="utf-8")
            output, omissions = convert_ifml.convert(path)

        self.assertIn('type: "Module"', output)
        self.assertIn('name: "PreferenceSetter"', output)
        self.assertIn('type: "Text"', output)
        self.assertIn('name: "Text"', output)
        self.assertIn('type: "List"', output)
        self.assertIn('name: "MessageList"', output)
        self.assertEqual(omissions, [])

    def test_preserves_explicit_container_stereotypes(self):
        source = diagram("""
          <mxCell id="RuopQsZhlrRQ3c0LH_m9-31" parent="1" style="fontStyle=1;align=left;verticalAlign=top;childLayout=stackLayout;horizontal=1;horizontalStack=0;resizeParent=1;resizeParentMax=0;resizeLast=0;marginBottom=0;allowArrows=0;connectable=0;strokeColor=#000000;strokeWidth=1;fontSize=12;fillColor=default;shadow=0;dropTarget=0;" value="" vertex="1">
            <mxGeometry height="410" width="500" x="-770" y="-110" as="geometry" />
          </mxCell>
          <mxCell id="RuopQsZhlrRQ3c0LH_m9-32" parent="RuopQsZhlrRQ3c0LH_m9-31" style="html=1;align=left;spacingLeft=10;verticalAlign=middle;strokeColor=default;fillColor=none;fontStyle=0;strokeWidth=1;fontSize=14;" value="«Modal» Inventory item dialog" vertex="1">
            <mxGeometry height="30" width="500" as="geometry" />
          </mxCell>
          <mxCell id="RuopQsZhlrRQ3c0LH_m9-34" parent="RuopQsZhlrRQ3c0LH_m9-31" style="swimlane;swimlaneBody=1;swimlaneHead=1;horizontal=1;swimlaneLine=0;collapsible=0;fontStyle=0;strokeColor=none;strokeWidth=1;fontSize=12;fillColor=none;" value="" vertex="1">
            <mxGeometry height="380" width="500" y="30" as="geometry" />
          </mxCell>
          <mxCell id="40" parent="1" vertex="1"
            style="childLayout=stackLayout;fillColor=#f5f5f5;"/>
          <mxCell id="41" parent="40" vertex="1" value="«View Container» Settings"/>
          <mxCell id="42" parent="40" vertex="1" style="swimlane=1;"/>
        """)
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "diagram.drawio"
            path.write_text(source, encoding="utf-8")
            output, omissions = convert_ifml.convert(path)

        self.assertIn('type: "Modal"\n    name: "Inventory item dialog"', output)
        self.assertIn('type: "View Container"\n    name: "Settings"', output)
        self.assertNotIn('type: "Alert Dialog"', output)
        self.assertEqual(omissions, [])

    def test_reads_compressed_drawio_pages(self):
        inner = '<mxGraphModel><root><mxCell id="0"/><mxCell id="1" parent="0"/><mxCell id="2" parent="1" vertex="1" value="Do it" style="shape=hexagon;"/></root></mxGraphModel>'
        compressed = zlib.compressobj(wbits=-zlib.MAX_WBITS)
        payload = compressed.compress(urllib.parse.quote(inner).encode("utf-8")) + compressed.flush()
        source = f"<mxfile><diagram>{base64.b64encode(payload).decode('ascii')}</diagram></mxfile>"
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "compressed.drawio"
            path.write_text(source, encoding="utf-8")
            output, omissions = convert_ifml.convert(path)

        self.assertIn('name: "Do it"', output)
        self.assertEqual(omissions, [])

    def test_cli_writes_complete_yaml_to_file_and_keeps_omissions_on_stderr(self):
        source = diagram("""
          <mxCell id="20" parent="1" vertex="1" value="Send"
            style="shape=hexagon;"/>
          <mxCell id="21" parent="1" edge="1" value="Flow"/>
          <mxCell id="22" parent="1" vertex="1" value="Unsupported"
            style="shape=mxgraph.example.internal;"/>
        """)
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "diagram.drawio"
            output_path = Path(temp_dir) / "output.yaml"
            path.write_text(source, encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(SCRIPT_DIR / "convert_ifml.py"), str(path), str(output_path)],
                capture_output=True, text=True, check=True,
            )
            output = output_path.read_text(encoding="utf-8")

        self.assertEqual(result.stdout, "")
        self.assertEqual(output, (
            "# yaml-language-server: $schema=https://raw.githubusercontent.com/"
            "experimental-software/building-blocks-specification/refs/tags/"
            "0.2.0/buildingblocks_schema.json\n"
            'buildingblocks: "0.2.0"\n'
            'info:\n  title: "Diagram"\n'
            'components: []\n'
            'actions:\n  - name: "Send"\n'
        ))
        self.assertIn("Omissions:", result.stderr)
        self.assertIn("Flow", result.stderr)
        self.assertIn("Diagram element 22 (Unsupported)", result.stderr)
        self.assertNotIn("mxgraph.example.internal", result.stderr)

    def test_cli_rejects_non_files_and_does_not_overwrite_input(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "diagram.drawio"
            source = diagram("")
            path.write_text(source, encoding="utf-8")
            hardlink = Path(temp_dir) / "same-file.yaml"
            hardlink.hardlink_to(path)
            script = str(SCRIPT_DIR / "convert_ifml.py")
            for input_path, output_path in [
                (str(path), str(path)),
                (str(path), str(hardlink)),
                ("/dev/stdin", str(Path(temp_dir) / "output.yaml")),
                (str(path), "/dev/stdout"),
            ]:
                with self.subTest(input_path=input_path, output_path=output_path):
                    result = subprocess.run(
                        [sys.executable, script, input_path, output_path],
                        input="", capture_output=True, text=True,
                    )
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(result.stdout, "")
                    self.assertIn("ERROR:", result.stderr)
            self.assertEqual(path.read_text(encoding="utf-8"), source)

    def test_reports_missing_or_invalid_diagram_in_plain_language(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "diagram.drawio"
            for source, expected in [
                ("<mxfile/>", "No diagram page was found"),
                ("<mxfile><diagram>not a compressed page</diagram></mxfile>",
                 "Could not read the compressed diagram page"),
            ]:
                with self.subTest(source=source):
                    path.write_text(source, encoding="utf-8")
                    with self.assertRaisesRegex(ValueError, expected):
                        convert_ifml.convert(path)


if __name__ == "__main__":
    unittest.main()
