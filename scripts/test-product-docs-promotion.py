#!/usr/bin/env python3
"""Tests for the branch-specific product README projection."""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/promote-product-docs.py"
VERIFY_SCRIPT = ROOT / "scripts/verify-main-promotion.py"


def run(*args: str, cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["python3", str(SCRIPT), "--root", str(cwd), *args],
        text=True,
        capture_output=True,
        check=False,
    )


def run_verify(*args: str, cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["python3", str(VERIFY_SCRIPT), "--root", str(cwd), *args],
        text=True,
        capture_output=True,
        check=False,
    )


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="omagen-product-docs-") as temporary:
        root = Path(temporary)
        product = root / "docs/product"
        for directory in (product / "assets", product / "demos", product / "examples", product / "release-notes"):
            directory.mkdir(parents=True)
            (directory / "README.md").write_text("# Placeholder\n", encoding="utf-8")
        (root / "CONTRIBUTING.md").write_text("# Contributing\n", encoding="utf-8")
        (product / "README.md").write_text(
            "<!-- omagen-product-readme: canonical-source -->\n"
            "# Product\n\n"
            "<!-- omagen-product-source-only:start -->\n"
            "> authoring note\n"
            "<!-- omagen-product-source-only:end -->\n\n"
            "[Install](installation.md) [Asset](assets/README.md) "
            "[Contribute](../../CONTRIBUTING.md) [External](https://example.com)\n"
            "<img src=\"../../assets/examples/example.webp\" alt=\"Example\">\n",
            encoding="utf-8",
        )
        (product / "installation.md").write_text("# Install\n", encoding="utf-8")
        (root / "assets/examples").mkdir(parents=True)
        (root / "assets/examples/example.webp").write_bytes(b"example")
        (root / "README.md").write_text("# Developer README\n", encoding="utf-8")

        checked = run("--check-source", cwd=root)
        if checked.returncode != 0:
            print(checked.stderr, end="")
            return 1
        written = run("--write", cwd=root)
        if written.returncode != 0:
            print(written.stderr, end="")
            return 1
        expected = (
            "<!-- omagen-product-readme: canonical-source -->\n"
            "# Product\n\n"
            "[Install](docs/product/installation.md) [Asset](docs/product/assets/README.md) "
            "[Contribute](CONTRIBUTING.md) [External](https://example.com)\n"
            "<img src=\"assets/examples/example.webp\" alt=\"Example\">\n"
        )
        if (root / "README.md").read_text(encoding="utf-8") != expected:
            print("unexpected projected README", file=sys.stderr)
            return 1
        verified = run("--check", cwd=root)
        if verified.returncode != 0:
            print(verified.stderr, end="")
            return 1

        (root / ".github").mkdir()
        subprocess.run(["git", "init", "-q"], cwd=root, check=True)
        subprocess.run(["git", "config", "user.email", "test@example.invalid"], cwd=root, check=True)
        subprocess.run(["git", "config", "user.name", "Product Docs Test"], cwd=root, check=True)
        subprocess.run(["git", "add", "-A"], cwd=root, check=True)
        subprocess.run(["git", "commit", "-qm", "test"], cwd=root, check=True)
        source_sha = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
        provenance_written = run(
            "--write",
            "--source-sha",
            source_sha,
            "--release-version",
            "v2.0.0",
            cwd=root,
        )
        if provenance_written.returncode != 0:
            print(provenance_written.stderr, end="")
            return 1
        provenance = run_verify(
            "--expected-dev-sha",
            source_sha,
            "--head-sha",
            source_sha,
            cwd=root,
        )
        if provenance.returncode != 0:
            print(provenance.stderr, end="")
            return 1
    print("Product documentation projection tests: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
