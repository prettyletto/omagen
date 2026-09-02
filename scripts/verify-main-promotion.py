#!/usr/bin/env python3
"""Verify that a main promotion branch was generated from the current dev head."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--expected-dev-sha", required=True)
    parser.add_argument("--head-sha", required=True)
    args = parser.parse_args()
    path = args.root / ".github/release-provenance.json"

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"Missing or malformed release provenance: {exc}", file=sys.stderr)
        return 1

    source_sha = data.get("sourceSha")
    if data.get("schemaVersion") != 1 or data.get("policyVersion") != "product-docs-projection-v1":
        print("Unsupported release provenance policy", file=sys.stderr)
        return 1
    if data.get("sourceBranch") != "dev":
        print("Release provenance sourceBranch must be dev", file=sys.stderr)
        return 1
    if not isinstance(source_sha, str) or not re.fullmatch(r"[0-9a-f]{40}", source_sha):
        print("Release provenance sourceSha must be a full lowercase SHA", file=sys.stderr)
        return 1
    if source_sha != args.expected_dev_sha:
        print("Release branch was not generated from the current dev head", file=sys.stderr)
        return 1
    if not re.fullmatch(r"[0-9a-f]{40}", args.head_sha):
        print("--head-sha must be a full lowercase SHA", file=sys.stderr)
        return 1

    result = subprocess.run(
        ["git", "merge-base", "--is-ancestor", source_sha, args.head_sha],
        cwd=args.root,
        check=False,
    )
    if result.returncode != 0:
        print("Release head does not contain the recorded dev source commit", file=sys.stderr)
        return 1
    print(f"Main promotion provenance: PASS (dev {source_sha})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
