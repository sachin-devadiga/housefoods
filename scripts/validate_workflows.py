#!/usr/bin/env python3
"""Strict-validate the GitHub Actions workflows.

PyYAML and most other parsers silently keep only the last of a set of duplicate
mapping keys. GitHub's parser does not: it rejects the whole workflow, which
shows up as a run that fails in 0s with "This run likely failed because of a
workflow file issue" and no logs to explain it.

That is not hypothetical. build-android.yml had two `push:` keys -- one for tags,
one for branch pushes with paths -- and PyYAML reported it as valid for the whole
time it sat in main.

So this walks the mapping nodes explicitly and fails on any duplicate key at any
depth. Run in CI; also runnable locally before pushing.

Usage:  python3 scripts/validate_workflows.py [workflows_dir]
Exit:   0 = all valid, 1 = at least one invalid.
"""

from __future__ import annotations

import sys
from pathlib import Path

import yaml


class StrictLoader(yaml.SafeLoader):
    """SafeLoader that refuses duplicate mapping keys at any depth."""


def _no_duplicate_keys(loader, node, deep=False):
    mapping: dict = {}
    first_line: dict = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in mapping:
            raise yaml.constructor.ConstructorError(
                None,
                None,
                f"duplicate key {key!r}: first at line {first_line[key]}, "
                f"repeated at line {key_node.start_mark.line + 1}",
                key_node.start_mark,
            )
        mapping[key] = loader.construct_object(value_node, deep=deep)
        first_line[key] = key_node.start_mark.line + 1
    return mapping


StrictLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _no_duplicate_keys
)


def check(path: Path) -> list[str]:
    """Return a list of problems for one file. Empty means valid."""
    try:
        yaml.load(path.read_text(), Loader=StrictLoader)
    except yaml.YAMLError as exc:
        return [str(exc).replace("\n", " ").strip()]
    except OSError as exc:
        return [f"unreadable: {exc}"]
    return []


def main(argv: list[str]) -> int:
    root = Path(argv[1]) if len(argv) > 1 else Path(".github/workflows")
    if not root.is_dir():
        print(f"ERROR: {root} is not a directory", file=sys.stderr)
        return 1

    files = sorted(root.glob("*.yml")) + sorted(root.glob("*.yaml"))
    if not files:
        print(f"ERROR: no workflows found in {root}", file=sys.stderr)
        return 1

    failed = 0
    for path in files:
        problems = check(path)
        if problems:
            failed += 1
            print(f"FAIL {path}")
            for problem in problems:
                print(f"       {problem}")
        else:
            print(f"ok   {path}")

    if failed:
        print(f"\n{failed} workflow(s) invalid.", file=sys.stderr)
        return 1
    print(f"\nAll {len(files)} workflow(s) valid.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
