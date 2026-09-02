#!/usr/bin/env python3
"""Run a deterministic, read-only marketplace security preflight.

This is intentionally a local release gate, not a security audit.  It mirrors
the documented Omarchy marketplace baseline categories so a release can be
reviewed before an exact commit is submitted to the marketplace.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from datetime import datetime, timezone


POLICY_VERSION = "omarchy-marketplace-baseline-v1"
MAX_RELEVANT_FILES = 1_000
MAX_TOTAL_TEXT_BYTES = 8 * 1024 * 1024
MAX_TEXT_FILE_BYTES = 512 * 1024
MAX_PREVIEW_BYTES = 50 * 1024 * 1024
MAX_PREVIEW_PIXELS = 40_000_000

TEXT_SUFFIXES = {
    ".bash",
    ".conf",
    ".go",
    ".ini",
    ".js",
    ".json",
    ".lua",
    ".mjs",
    ".md",
    ".py",
    ".qml",
    ".service",
    ".sh",
    ".toml",
    ".yaml",
    ".yml",
    ".zsh",
}
IMAGE_SUFFIXES = {".avif", ".gif", ".jpeg", ".jpg", ".png", ".webp"}
SETUP_NAMES = re.compile(r"(?:^|/)(?:install|installer|setup|uninstall)(?:[-_.]|$)", re.I)
SHELL_PIPE = re.compile(
    r"\b(?:curl|wget)\b[^\n|]*\|\s*(?:/usr/bin/)?(?:ba)?sh\b|"
    r"\b(?:curl|wget)\b[^\n|]*\|\s*(?:zsh|python(?:3)?|perl|ruby)\b",
    re.I,
)
GIT_CLONE = re.compile(r"\bgit\s+clone\b", re.I)
DETACHED_FULL_SHA = re.compile(
    r"(?:git\s+checkout\s+(?:--detach\s+)?|git\s+reset\s+--hard\s+)[\"']?(?:[0-9a-f]{40}|\$\{?[A-Za-z_][A-Za-z0-9_]*\}?)[\"']?\b",
    re.I,
)
EXACT_COMMIT_REFERENCE = re.compile(r"\bOMAGEN_TEST_COMMIT\b|full[- ]40[- ]character", re.I)
REMOTE_EXECUTION = re.compile(
    r"(?:\b(?:bash|sh|zsh|python(?:3)?|ruby|perl|go\s+run|npm\s+(?:run|exec)|make)\b|\./[A-Za-z0-9_.-]+)",
    re.I,
)
SUDOERS_DANGEROUS = re.compile(
    r"NOPASSWD\s*:\s*(?:ALL|[^\n]*\b(?:kill|systemctl|pkill|rm|mv|cp|dd|mount|umount)\b[^\n]*\*)",
    re.I,
)
TEMP_PATH = r"(?:/tmp|\$TMPDIR)"
PID_PATH = r"(?:pid|\.pid)"
PRIVILEGED_CONTROL = r"(?:sudo|pkexec|systemctl|kill|pkill)"
SHARED_TEMP_PRIVILEGE = re.compile(
    TEMP_PATH + r"[^\n]*" + PID_PATH + r"[^\n]*" + PRIVILEGED_CONTROL + r"|"
    + PRIVILEGED_CONTROL + r"[^\n]*" + TEMP_PATH + r"[^\n]*" + PID_PATH,
    re.I,
)


class ScanFailure(Exception):
    pass


def git(root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(root), *args],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode:
        raise ScanFailure(result.stderr.strip() or f"git {' '.join(args)} failed")
    return result.stdout.strip()


def tracked_files(root: Path) -> list[str]:
    result = subprocess.run(
        ["git", "-C", str(root), "ls-files", "-z"],
        check=False,
        capture_output=True,
    )
    if result.returncode:
        raise ScanFailure(result.stderr.decode(errors="replace").strip() or "git ls-files failed")
    return [item.decode("utf-8") for item in result.stdout.split(b"\0") if item]


def manifests_at_commit(root: Path, commit: str) -> tuple[set[str], list[str], list[str]]:
    paths: set[str] = set()
    plugin_ids: list[str] = []
    errors: list[str] = []
    try:
        names = git(root, "ls-tree", "-r", "--name-only", commit).splitlines()
    except ScanFailure as exc:
        return set(), [], [f"baseline {commit}: {exc}"]
    for name in ("manifest.json", "bar-manifest.json"):
        if name not in names:
            continue
        paths.add(name)
        try:
            encoded = git(root, "show", f"{commit}:{name}")
            manifest = json.loads(encoded)
        except (ScanFailure, json.JSONDecodeError) as exc:
            errors.append(f"baseline {commit} {name}: invalid JSON: {exc}")
            continue
        plugin_id = manifest.get("id") if isinstance(manifest, dict) else None
        if isinstance(plugin_id, str):
            plugin_ids.append(plugin_id)
    return paths, plugin_ids, errors


def is_binary(data: bytes) -> bool:
    return b"\0" in data[:8192]


def image_dimensions(data: bytes) -> tuple[int, int] | None:
    if data.startswith(b"\x89PNG\r\n\x1a\n") and len(data) >= 24:
        return int.from_bytes(data[16:20], "big"), int.from_bytes(data[20:24], "big")
    if data.startswith((b"GIF87a", b"GIF89a")) and len(data) >= 10:
        return int.from_bytes(data[6:8], "little"), int.from_bytes(data[8:10], "little")
    if data.startswith(b"RIFF") and data[8:12] == b"WEBP" and len(data) >= 30:
        if data[12:16] == b"VP8X":
            width = 1 + int.from_bytes(data[24:27], "little")
            height = 1 + int.from_bytes(data[27:30], "little")
            return width, height
        if data[12:16] == b"VP8 " and len(data) >= 30 and data[23:26] == b"\x9d\x01\x2a":
            return int.from_bytes(data[26:28], "little") & 0x3FFF, int.from_bytes(data[28:30], "little") & 0x3FFF
    if data.startswith(b"\xff\xd8"):
        index = 2
        while index + 9 < len(data):
            if data[index] != 0xFF:
                index += 1
                continue
            marker = data[index + 1]
            index += 2
            if marker in {0xD8, 0xD9}:
                continue
            if index + 2 > len(data):
                break
            length = int.from_bytes(data[index:index + 2], "big")
            if length < 2 or index + length > len(data):
                break
            if marker in set(range(0xC0, 0xC4)) | set(range(0xC5, 0xC8)) | set(range(0xC9, 0xCC)) | set(range(0xCD, 0xD0)):
                if length >= 7:
                    return int.from_bytes(data[index + 3:index + 5], "big"), int.from_bytes(data[index + 5:index + 7], "big")
            index += length
    return None


def manifest_entrypoints(manifest: dict, path: str) -> tuple[list[str], list[str]]:
    entrypoints: list[str] = []
    errors: list[str] = []
    declared = manifest.get("entryPoints")
    if not isinstance(declared, dict) or not declared:
        return [], [f"{path}: entryPoints must be a non-empty object"]
    for value in declared.values():
        if not isinstance(value, str) or not value or Path(value).is_absolute() or ".." in Path(value).parts:
            errors.append(f"{path}: invalid entry point {value!r}")
            continue
        entrypoints.append(value)
    return entrypoints, errors


def selected_file(path: str, executable: bool, entrypoints: set[str]) -> bool:
    name = Path(path).name
    return (
        path in {"README.md", "manifest.json", "bar-manifest.json"}
        or path in entrypoints
        or executable
        or Path(path).suffix.lower() in TEXT_SUFFIXES
        or bool(SETUP_NAMES.search(path))
        or name.upper().startswith("LICENSE")
    )


def add_finding(findings: list[dict], rule: str, path: str, line: int, evidence: str) -> None:
    findings.append({"rule": rule, "path": path, "line": line, "evidence": evidence[:240]})


def scan(root: Path, expected_commit: str | None, baseline_commit: str | None) -> dict:
    root = root.resolve()
    if not (root / ".git").exists():
        raise ScanFailure("root is not a Git checkout")

    commit = git(root, "rev-parse", "HEAD")
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ScanFailure(f"repository HEAD is not a full commit SHA: {commit}")
    if expected_commit and commit != expected_commit:
        raise ScanFailure(f"checked-out commit {commit} does not match requested commit {expected_commit}")

    files = tracked_files(root)
    file_set = set(files)
    manifests: list[tuple[str, dict]] = []
    entrypoints: set[str] = set()
    errors: list[str] = []
    plugin_ids: list[str] = []
    for manifest_path in ("manifest.json", "bar-manifest.json"):
        if manifest_path not in file_set:
            errors.append(f"missing repository-root {manifest_path}")
            continue
        try:
            manifest = json.loads((root / manifest_path).read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            errors.append(f"{manifest_path}: invalid JSON: {exc}")
            continue
        if not isinstance(manifest, dict):
            errors.append(f"{manifest_path}: manifest must be an object")
            continue
        manifests.append((manifest_path, manifest))
        plugin_id = manifest.get("id")
        if not isinstance(plugin_id, str) or not plugin_id or plugin_id.startswith("omarchy."):
            errors.append(f"{manifest_path}: invalid or reserved plugin id {plugin_id!r}")
        else:
            plugin_ids.append(plugin_id)
        paths, path_errors = manifest_entrypoints(manifest, manifest_path)
        entrypoints.update(paths)
        errors.extend(path_errors)
        for entrypoint in paths:
            if entrypoint not in file_set:
                errors.append(f"{manifest_path}: missing entry point {entrypoint}")

    if not (root / "README.md").is_file():
        errors.append("missing repository-root README.md")
    else:
        readme = (root / "README.md").read_text(encoding="utf-8", errors="replace").lower()
        if "install" not in readme or not any(token in readme for token in ("remove", "uninstall")):
            errors.append("README.md must document installation and removal")
        if not any(token in readme for token in ("dependency", "requirement", "omarchy", "quickshell", "hyprland")):
            errors.append("README.md must document runtime requirements or dependencies")
    if not any(Path(name).parent == Path(".") and Path(name).name.upper().startswith("LICENSE") for name in files):
        errors.append("missing repository-root license file")
    if len(plugin_ids) != len(set(plugin_ids)):
        errors.append("plugin IDs must be unique across the source-wide manifest set")
    versions = {manifest.get("version") for _, manifest in manifests if manifest.get("version") is not None}
    if len(versions) > 1:
        errors.append("all source-wide plugin manifests must use the same version")

    if baseline_commit:
        baseline_paths, baseline_ids, baseline_errors = manifests_at_commit(root, baseline_commit)
        errors.extend(baseline_errors)
        current_paths = {path for path, _ in manifests}
        if current_paths != baseline_paths:
            errors.append(
                "manifest set changed from baseline "
                f"{baseline_commit}: {sorted(baseline_paths)} -> {sorted(current_paths)}"
            )
        if plugin_ids != baseline_ids:
            errors.append(
                "plugin IDs changed from baseline "
                f"{baseline_commit}: {baseline_ids} -> {plugin_ids}"
            )

    relevant = []
    total_text_bytes = 0
    findings: list[dict] = []
    capabilities: set[str] = set()
    for path in files:
        full_path = root / path
        try:
            stat = full_path.stat()
            data = full_path.read_bytes()
        except OSError as exc:
            errors.append(f"{path}: cannot read tracked file: {exc}")
            continue
        if full_path.is_symlink():
            errors.append(f"tracked symlink is unsupported: {path}")
            continue
        executable = bool(stat.st_mode & 0o111)
        binary = is_binary(data)
        if data.startswith((b"\x7fELF", b"MZ")) or data[:4] in {b"\xfe\xed\xfa\xce", b"\xfe\xed\xfa\xcf", b"\xca\xfe\xba\xbe"}:
            capabilities.add("bundled-executable-binary")
        if not selected_file(path, executable, entrypoints):
            continue
        relevant.append(path)
        if len(relevant) > MAX_RELEVANT_FILES:
            errors.append(f"relevant file limit exceeded: {MAX_RELEVANT_FILES}")
            break
        if binary:
            if SETUP_NAMES.search(path) and Path(path).suffix.lower() not in IMAGE_SUFFIXES:
                errors.append(f"setup-related binary cannot be excluded from scan: {path}")
            continue
        if len(data) > MAX_TEXT_FILE_BYTES:
            errors.append(f"text file exceeds {MAX_TEXT_FILE_BYTES} bytes: {path}")
            continue
        total_text_bytes += len(data)
        if total_text_bytes > MAX_TOTAL_TEXT_BYTES:
            errors.append(f"total relevant text exceeds {MAX_TOTAL_TEXT_BYTES} bytes")
            break
        try:
            text = data.decode("utf-8", errors="strict")
        except UnicodeDecodeError as exc:
            errors.append(f"unsupported non-UTF-8 text content: {path}: {exc}")
            continue
        lower_path = path.lower()
        if SETUP_NAMES.search(path):
            capabilities.add("installer")
        if re.search(r"\b(?:apt|dnf|pacman|apk|brew|flatpak|snap)\s+(?:install|remove|add)\b", text, re.I):
            capabilities.add("package-manager")
        for capability_line in text.splitlines():
            if re.search(r"\b(?:sudo|pkexec)\b", capability_line, re.I) and not re.search(
                r"\b(?:no|without|never|does\s+not\s+require|do(?:es)?\s+not\s+use|not\s+use)\s+(?:the\s+)?(?:sudo|pkexec)\b",
                capability_line,
                re.I,
            ):
                capabilities.add("privilege")
            if re.search(r"\b(?:systemctl|systemd-run)\b", capability_line, re.I):
                capabilities.add("service-management")
            if re.search(r"\b(?:sudoers|/etc/sudoers)\b", capability_line, re.I):
                capabilities.add("sudoers-modification")
        if GIT_CLONE.search(text):
            capabilities.add("remote-build")
            if REMOTE_EXECUTION.search(text) and not (DETACHED_FULL_SHA.search(text) or EXACT_COMMIT_REFERENCE.search(text)):
                for line_number, line in enumerate(text.splitlines(), 1):
                    if GIT_CLONE.search(line) or REMOTE_EXECUTION.search(line):
                        add_finding(findings, "remote-git-execution-unpinned", path, line_number, line.strip())
                        break
        for line_number, line in enumerate(text.splitlines(), 1):
            if SHELL_PIPE.search(line):
                add_finding(findings, "curl-pipe-shell", path, line_number, line.strip())
            if SUDOERS_DANGEROUS.search(line):
                add_finding(findings, "sudoers-dangerous-passwordless-command", path, line_number, line.strip())
            if SHARED_TEMP_PRIVILEGE.search(line):
                add_finding(findings, "privileged-process-control-from-shared-temp", path, line_number, line.strip())

    previews = []
    for path in files:
        if Path(path).name.lower() not in {"preview.png", "preview.jpg", "preview.jpeg", "preview.webp", "preview.avif"}:
            continue
        data = (root / path).read_bytes()
        preview = {"path": path, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
        if len(data) > MAX_PREVIEW_BYTES:
            errors.append(f"preview exceeds {MAX_PREVIEW_BYTES} bytes: {path}")
        dimensions = image_dimensions(data)
        if dimensions:
            preview["width"], preview["height"] = dimensions
            if dimensions[0] * dimensions[1] > MAX_PREVIEW_PIXELS:
                errors.append(f"preview exceeds {MAX_PREVIEW_PIXELS} pixels: {path}")
        else:
            errors.append(f"preview dimensions could not be validated: {path}")
        previews.append(preview)

    if errors:
        outcome = "needs-fixes"
    elif findings:
        outcome = "needs-fixes"
    elif capabilities:
        outcome = "review-required"
    else:
        outcome = "passed"

    try:
        origin = git(root, "config", "--get", "remote.origin.url") or "unknown"
    except ScanFailure:
        origin = "unknown"
    return {
        "schema_version": 1,
        "policy_version": POLICY_VERSION,
        "repository": origin,
        "commit": commit,
        "comparison_baseline": baseline_commit,
        "scanned_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "plugin_ids": plugin_ids,
        "manifests": [path for path, _ in manifests],
        "entry_points": sorted(entrypoints),
        "limits": {
            "relevant_files": MAX_RELEVANT_FILES,
            "total_text_bytes": MAX_TOTAL_TEXT_BYTES,
            "text_file_bytes": MAX_TEXT_FILE_BYTES,
            "preview_bytes": MAX_PREVIEW_BYTES,
            "preview_pixels": MAX_PREVIEW_PIXELS,
        },
        "relevant_file_count": len(relevant),
        "total_text_bytes": total_text_bytes,
        "previews": previews,
        "outcome": outcome,
        "findings": sorted(findings, key=lambda item: (item["rule"], item["path"], item["line"])),
        "capabilities": sorted(capabilities),
        "errors": sorted(errors),
        "disclaimer": "This deterministic preflight is not a security audit, certification, endorsement, or guarantee.",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--commit", help="require the checkout to be this full 40-character SHA")
    parser.add_argument("--compare-to", help="compare manifest paths and plugin IDs with this Git baseline")
    parser.add_argument("--report", type=Path, help="write the JSON report to this path")
    args = parser.parse_args()
    if args.commit and not re.fullmatch(r"[0-9a-f]{40}", args.commit):
        parser.error("--commit must be a full 40-character lowercase SHA")
    try:
        report = scan(args.root, args.commit, args.compare_to)
    except ScanFailure as exc:
        print(f"marketplace-preflight: needs-fixes: {exc}", file=sys.stderr)
        return 2
    encoded = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(encoded, encoding="utf-8")
    print(
        f"marketplace-preflight: {report['outcome']} "
        f"commit={report['commit']} plugins={','.join(report['plugin_ids']) or '<none>'} "
        f"findings={len(report['findings'])} capabilities={','.join(report['capabilities']) or '<none>'}"
    )
    if report["errors"]:
        for error in report["errors"]:
            print(f"  error: {error}", file=sys.stderr)
    for finding in report["findings"]:
        print(f"  finding: {finding['rule']} {finding['path']}:{finding['line']}: {finding['evidence']}", file=sys.stderr)
    if args.report:
        print(f"  report: {args.report}")
    return 1 if report["outcome"] == "needs-fixes" else 0


if __name__ == "__main__":
    raise SystemExit(main())
