#!/usr/bin/env python3
"""Verify checked-in GLSL/QSB pairs against the repository provenance lock."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
LOCK = ROOT / "docs" / "shader-provenance.json"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> int:
    try:
        lock = json.loads(LOCK.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        print(f"shader provenance: invalid lock: {exc}", file=sys.stderr)
        return 1

    if lock.get("schema_version") != 1 or not isinstance(lock.get("artifacts"), list):
        print("shader provenance: unsupported or malformed lock", file=sys.stderr)
        return 1

    errors: list[str] = []
    seen: set[str] = set()
    for item in lock["artifacts"]:
        if not isinstance(item, dict):
            errors.append("artifact entry is not an object")
            continue
        source_name = item.get("source")
        qsb_name = item.get("qsb")
        if not isinstance(source_name, str) or not isinstance(qsb_name, str):
            errors.append(f"invalid artifact paths: {item!r}")
            continue
        for name, digest_key in ((source_name, "source_sha256"), (qsb_name, "qsb_sha256")):
            path = ROOT / name
            if path.is_symlink() or not path.is_file():
                errors.append(f"missing or symlinked artifact: {name}")
                continue
            expected = item.get(digest_key)
            if not isinstance(expected, str) or len(expected) != 64:
                errors.append(f"invalid SHA-256 in lock for {name}")
                continue
            actual = sha256(path)
            if actual != expected:
                errors.append(f"hash mismatch for {name}: expected {expected}, got {actual}")
        if qsb_name in seen:
            errors.append(f"duplicate QSB artifact: {qsb_name}")
        seen.add(qsb_name)

    if errors:
        for error in errors:
            print(f"shader provenance: {error}", file=sys.stderr)
        return 1
    print(f"shader provenance: PASS ({len(lock['artifacts'])} source/QSB pairs)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
