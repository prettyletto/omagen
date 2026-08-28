#!/usr/bin/env python3
"""Check relative Markdown links without fetching external URLs."""

from pathlib import Path
import re
import sys


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    errors = []
    for source in root.rglob("*.md"):
        for target in re.findall(r"]\(([^)]+)\)", source.read_text(encoding="utf-8")):
            target = target.strip().split("#", 1)[0].split("?", 1)[0]
            if not target or target.startswith(("http://", "https://", "mailto:", "#")):
                continue
            if target.startswith("<") and target.endswith(">"):
                target = target[1:-1]
            if not (source.parent / target).resolve().exists():
                errors.append(f"{source.relative_to(root)}: {target}")

    if errors:
        print("Broken relative Markdown links:", file=sys.stderr)
        print("\n".join(f"- {error}" for error in errors), file=sys.stderr)
        return 1
    print("Relative Markdown links: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
