"""Exercise coverage decisions against locally extracted Graphify fixtures."""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from status import status


class CoverageTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name).resolve()
        self.source = self.root / "service.py"
        self.source.write_text("def submit_order():\n    return 1\n")

    def build(self):
        subprocess.run(
            ["graphify", "extract", str(self.root), "--code-only", "--no-cluster"],
            check=True,
            capture_output=True,
            timeout=30,
        )

    def test_missing_graph(self):
        self.assertEqual(status(self.root)["status"], "missing")

    def test_current_code_and_unindexed_document_are_separate(self):
        (self.root / "README.md").write_text("# Order service\n")
        self.build()
        result = status(self.root)
        self.assertEqual(result["code_coverage"], "current")
        self.assertEqual(result["pending_semantic_files"], {"document": 1})

    def test_change_and_new_file_invalidate_code_coverage(self):
        self.build()
        self.assertEqual(status(self.root)["code_coverage"], "current")
        self.source.write_text("def submit_order():\n    return 42\n")
        (self.root / "store.py").write_text("def save_order():\n    return True\n")
        result = status(self.root)
        self.assertEqual(result["code_coverage"], "stale")
        self.assertEqual(result["pending_code_files"], 2)

    def test_deleted_source_invalidates_graph(self):
        self.build()
        self.source.unlink()
        result = status(self.root)
        self.assertEqual(result["code_coverage"], "stale")
        self.assertEqual(result["deleted_indexed_files"], 1)

    def test_missing_manifest_is_unknown(self):
        self.build()
        (self.root / "graphify-out/manifest.json").unlink()
        self.assertEqual(status(self.root)["status"], "unknown")

    def test_different_checkout_is_unknown(self):
        self.build()
        (self.root / "graphify-out/.graphify_root").write_text("/elsewhere")
        self.assertEqual(status(self.root)["status"], "unknown")

    def test_corrupt_manifest_cli_reports_unknown(self):
        self.build()
        (self.root / "graphify-out/manifest.json").write_text("{")
        result = subprocess.run(
            [
                sys.executable,
                str(Path(__file__).with_name("status.py")),
                str(self.root),
            ],
            check=True,
            capture_output=True,
            text=True,
            timeout=10,
        )
        self.assertEqual(json.loads(result.stdout)["status"], "unknown")

    def test_check_preserves_graph_and_manifest(self):
        self.build()
        files = list((self.root / "graphify-out").iterdir())
        before = {
            path: (path.read_bytes(), path.stat().st_mtime_ns)
            for path in files
            if path.is_file()
        }
        status(self.root)
        after = {path: (path.read_bytes(), path.stat().st_mtime_ns) for path in before}
        self.assertEqual(before, after)


if __name__ == "__main__":
    unittest.main()
