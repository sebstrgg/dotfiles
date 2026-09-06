"""Report Graphify coverage without modifying the graph or indexing content."""

import argparse
import json
import os
import shlex
import shutil
import sys
from pathlib import Path


def status(root: Path) -> dict:
    output = root / "graphify-out"
    graph_path = output / "graph.json"
    manifest_path = output / "manifest.json"
    if not graph_path.is_file():
        return {"status": "missing", "reason": "No graph in this repository"}
    if not manifest_path.is_file():
        return {"status": "unknown", "reason": "Graph has no freshness manifest"}

    graph = json.loads(graph_path.read_text())
    manifest = json.loads(manifest_path.read_text())
    if not isinstance(graph, dict) or not graph.get("nodes"):
        return {"status": "unknown", "reason": "Graph has no nodes"}
    if not isinstance(manifest, dict) or not manifest:
        return {"status": "unknown", "reason": "Manifest has no indexed sources"}
    marker = output / ".graphify_root"
    if marker.exists() and Path(marker.read_text().strip()).resolve() != root:
        return {"status": "unknown", "reason": "Graph root differs from this checkout"}

    try:
        from graphify.detect import detect_incremental
    except ModuleNotFoundError as error:
        # Use the installed CLI's interpreter, avoiding package-manager locks
        # that require writes outside a read-only agent's workspace.
        if error.name != "graphify":
            raise
        executable = shutil.which("graphify")
        if executable:
            with Path(executable).open() as launcher:
                shebang = launcher.readline()
            interpreter = shlex.split(shebang[2:]) if shebang.startswith("#!") else []
            if (
                len(interpreter) == 1
                and Path(interpreter[0]).is_absolute()
                and interpreter[0] != sys.executable
            ):
                os.execv(
                    interpreter[0],
                    [interpreter[0], str(Path(__file__).resolve()), str(root)],
                )
        return {"status": "unknown", "reason": "Graphify interpreter unavailable"}

    ast = detect_incremental(root, manifest_path=str(manifest_path), kind="ast")
    semantic = detect_incremental(
        root, manifest_path=str(manifest_path), kind="semantic"
    )
    code_pending = len(ast["new_files"].get("code", []))
    semantic_pending = {
        kind: len(files)
        for kind, files in semantic["new_files"].items()
        if kind != "code" and files
    }
    removed = len(ast.get("deleted_files", []))
    excluded = len(ast.get("excluded_files", []))
    code_current = not (code_pending or removed or excluded)
    semantic_current = not (semantic_pending or removed or excluded)
    return {
        "status": "current" if code_current and semantic_current else "partial",
        "code_coverage": "current" if code_current else "stale",
        "semantic_coverage": "current" if semantic_current else "stale_or_unindexed",
        "pending_code_files": code_pending,
        "pending_semantic_files": semantic_pending,
        "deleted_indexed_files": removed,
        "excluded_indexed_files": excluded,
        "indexed_files": len(manifest),
        "corpus_files": ast["total_files"],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    args = parser.parse_args()
    try:
        result = status(args.root.resolve(strict=True))
    except (OSError, ValueError, TypeError, KeyError, ImportError) as error:
        result = {"status": "unknown", "reason": type(error).__name__}
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
