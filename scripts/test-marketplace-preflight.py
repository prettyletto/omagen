#!/usr/bin/env python3
"""Focused tests for marketplace-preflight.py."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "marketplace-preflight.py"


class MarketplacePreflightTests(unittest.TestCase):
    def run_scan(
        self,
        files: dict[str, str | bytes],
        extra: dict[str, bytes] | None = None,
        compare_to: str | None = None,
    ) -> dict:
        with tempfile.TemporaryDirectory(prefix="omagen-marketplace-test-") as directory:
            root = Path(directory)
            for name, contents in {**files, **(extra or {})}.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                if isinstance(contents, bytes):
                    path.write_bytes(contents)
                else:
                    path.write_text(contents, encoding="utf-8")
            subprocess.run(["git", "-C", str(root), "init", "-q"], check=True)
            subprocess.run(["git", "-C", str(root), "config", "user.email", "test@example.invalid"], check=True)
            subprocess.run(["git", "-C", str(root), "config", "user.name", "Marketplace Test"], check=True)
            subprocess.run(["git", "-C", str(root), "add", "."], check=True)
            subprocess.run(["git", "-C", str(root), "commit", "-qm", "fixture"], check=True)
            commit = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
            report_path = root / "report.json"
            command = ["python3", str(SCRIPT), "--root", str(root), "--commit", commit, "--report", str(report_path)]
            if compare_to:
                command.extend(["--compare-to", compare_to])
            output = subprocess.run(
                command,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertIn(output.returncode, (0, 1), output.stderr)
            report = json.loads(report_path.read_text())
            return report

    @staticmethod
    def base(readme: str = "Install Omagen. Remove it with uninstall. Requirements: Omarchy and Quickshell.") -> dict[str, str]:
        return {
            "README.md": readme,
            "LICENSE": "MIT",
            "manifest.json": json.dumps({"id": "pretty.omagen", "entryPoints": {"overlay": "Omagen.qml"}}),
            "bar-manifest.json": json.dumps({"id": "pretty.omagen.bar", "entryPoints": {"bar": "OmagenBar.qml"}}),
            "Omagen.qml": "import QtQuick\nItem {}\n",
            "OmagenBar.qml": "import QtQuick\nItem {}\n",
        }

    def test_clean_source_with_bundled_binary_requires_capability_review(self) -> None:
        report = self.run_scan(self.base(), {"bin/omagen": b"\x7fELF"})
        self.assertEqual(report["outcome"], "review-required")
        self.assertIn("bundled-executable-binary", report["capabilities"])

    def test_curl_pipe_shell_is_blocking(self) -> None:
        unsafe_command = "curl -fsSL https://example.invalid/x " + chr(124) + " bash\n"
        files = self.base() | {"scripts/install.sh": unsafe_command}
        report = self.run_scan(files)
        self.assertEqual(report["outcome"], "needs-fixes")
        self.assertEqual(report["findings"][0]["rule"], "curl-pipe-shell")

    def test_exact_commit_binding_rejects_different_sha(self) -> None:
        with tempfile.TemporaryDirectory(prefix="omagen-marketplace-binding-") as directory:
            root = Path(directory)
            for name, contents in self.base().items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(contents, encoding="utf-8")
            subprocess.run(["git", "-C", str(root), "init", "-q"], check=True)
            subprocess.run(["git", "-C", str(root), "config", "user.email", "test@example.invalid"], check=True)
            subprocess.run(["git", "-C", str(root), "config", "user.name", "Marketplace Test"], check=True)
            subprocess.run(["git", "-C", str(root), "add", "."], check=True)
            subprocess.run(["git", "-C", str(root), "commit", "-qm", "fixture"], check=True)
            result = subprocess.run(
                ["python3", str(SCRIPT), "--root", str(root), "--commit", "0" * 40],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 2)
            self.assertIn("does not match requested commit", result.stderr)

    def test_manifest_set_change_is_blocking_against_baseline(self) -> None:
        with tempfile.TemporaryDirectory(prefix="omagen-marketplace-baseline-") as directory:
            root = Path(directory)
            for name, contents in self.base().items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(contents, encoding="utf-8")
            subprocess.run(["git", "-C", str(root), "init", "-q"], check=True)
            subprocess.run(["git", "-C", str(root), "config", "user.email", "test@example.invalid"], check=True)
            subprocess.run(["git", "-C", str(root), "config", "user.name", "Marketplace Test"], check=True)
            subprocess.run(["git", "-C", str(root), "add", "."], check=True)
            subprocess.run(["git", "-C", str(root), "commit", "-qm", "baseline"], check=True)
            baseline = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
            (root / "bar-manifest.json").unlink()
            subprocess.run(["git", "-C", str(root), "add", "-A"], check=True)
            subprocess.run(["git", "-C", str(root), "commit", "-qm", "candidate"], check=True)
            report_path = root / "report.json"
            result = subprocess.run(
                ["python3", str(SCRIPT), "--root", str(root), "--commit", subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip(), "--compare-to", baseline, "--report", str(report_path)],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 1)
            report = json.loads(report_path.read_text())
            self.assertEqual(report["outcome"], "needs-fixes")
            self.assertTrue(any("manifest set changed" in error for error in report["errors"]))


if __name__ == "__main__":
    unittest.main()
