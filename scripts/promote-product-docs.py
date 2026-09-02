#!/usr/bin/env python3
"""Validate and project the canonical product README onto the stable root.

The source document lives at ``docs/product/README.md`` so nightly and dev can
keep a developer-facing repository README. A release branch generated from an
exact dev commit runs ``--write`` to materialize the source at ``README.md``.
The transformation is deterministic for the README itself: relative links are
resolved from the source location and rewritten for the repository root.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from posixpath import relpath


POLICY_VERSION = "product-docs-projection-v1"
SOURCE_README = Path("docs/product/README.md")
ROOT_README = Path("README.md")
MARKER = "<!-- omagen-product-readme: canonical-source -->"
SOURCE_ONLY = re.compile(
    r"<!-- omagen-product-source-only:start -->.*?<!-- omagen-product-source-only:end -->[ \t]*(?:\n[ \t]*)*",
    re.DOTALL,
)
MARKDOWN_LINK = re.compile(r"\]\(([^)\n]+)\)")
EXTERNAL_PREFIXES = ("http://", "https://", "mailto:", "#")


def split_target(raw_target: str) -> tuple[str, str, str]:
    """Return path, suffix, and optional markdown title from a link target."""

    target = raw_target.strip()
    if target.startswith("<") and ">" in target:
        close = target.index(">")
        path = target[1:close]
        remainder = target[close + 1 :]
        return path, "", remainder

    match = re.match(r"([^\s]+)(\s+.*)?$", target)
    if not match:
        return target, "", ""
    path_with_suffix = match.group(1)
    title = match.group(2) or ""
    suffix_match = re.match(r"([^#?]*)(.*)$", path_with_suffix)
    assert suffix_match is not None
    return suffix_match.group(1), suffix_match.group(2), title


def is_external(path: str) -> bool:
    return not path or path.startswith(EXTERNAL_PREFIXES) or path.startswith("/")


def resolve_local(root: Path, source: Path, link_path: str) -> Path:
    resolved = (source.parent / link_path).resolve()
    root_resolved = root.resolve()
    try:
        resolved.relative_to(root_resolved)
    except ValueError as exc:
        raise ValueError(
            f"{source.relative_to(root)}: relative link escapes repository: {link_path}"
        ) from exc
    return resolved


def validate_markdown_links(root: Path, directory: Path) -> list[str]:
    errors: list[str] = []
    if not directory.is_dir():
        return [f"missing product documentation directory: {directory.relative_to(root)}"]

    for source in sorted(directory.rglob("*.md")):
        text = source.read_text(encoding="utf-8")
        for raw_target in MARKDOWN_LINK.findall(text):
            link_path, _, _ = split_target(raw_target)
            if is_external(link_path):
                continue
            try:
                resolved = resolve_local(root, source, link_path)
            except ValueError as exc:
                errors.append(str(exc))
                continue
            if not resolved.exists():
                errors.append(
                    f"{source.relative_to(root)}: missing relative link: {link_path}"
                )
    return errors


def rewrite_link(root: Path, source: Path, raw_target: str) -> str:
    link_path, suffix, title = split_target(raw_target)
    if is_external(link_path):
        return raw_target

    resolved = resolve_local(root, source, link_path)
    destination = Path(relpath(resolved, root.resolve())).as_posix()
    rewritten = f"{destination}{suffix}{title}"
    if raw_target.strip().startswith("<"):
        return f"<{destination}{suffix}>{title}"
    return rewritten


def render_readme(root: Path) -> str:
    source = root / SOURCE_README
    if not source.is_file():
        raise ValueError(f"missing canonical product README: {SOURCE_README}")
    source_text = source.read_text(encoding="utf-8")
    if MARKER not in source_text:
        raise ValueError(f"canonical README is missing marker: {MARKER}")
    source_text = SOURCE_ONLY.sub("", source_text)

    def replace(match: re.Match[str]) -> str:
        return "](" + rewrite_link(root, source, match.group(1)) + ")"

    return MARKDOWN_LINK.sub(replace, source_text)


def validate_source(root: Path) -> None:
    source = root / SOURCE_README
    if not source.is_file():
        raise ValueError(f"missing canonical product README: {SOURCE_README}")
    required = (
        root / "docs/product/assets/README.md",
        root / "docs/product/demos/README.md",
        root / "docs/product/examples/README.md",
        root / "docs/product/release-notes/README.md",
    )
    missing = [path.relative_to(root) for path in required if not path.is_file()]
    if missing:
        raise ValueError("missing product documentation files: " + ", ".join(map(str, missing)))
    errors = validate_markdown_links(root, root / "docs/product")
    if errors:
        raise ValueError("\n".join(errors))


def write_provenance(root: Path, source_sha: str, release_version: str) -> None:
    if not re.fullmatch(r"[0-9a-f]{40}", source_sha):
        raise ValueError("--source-sha must be a full lowercase 40-character commit SHA")
    if not re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?", release_version):
        raise ValueError("--release-version must be a semantic version beginning with v")

    provenance = {
        "schemaVersion": 1,
        "policyVersion": POLICY_VERSION,
        "sourceBranch": "dev",
        "sourceSha": source_sha,
        "releaseVersion": release_version,
        "generatedFiles": [str(ROOT_README)],
        "generatedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    }
    path = root / ".github/release-provenance.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(provenance, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check-source", action="store_true")
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--write", action="store_true")
    parser.add_argument("--source-sha")
    parser.add_argument("--release-version")
    args = parser.parse_args()
    root = args.root.resolve()

    try:
        validate_source(root)
        rendered = render_readme(root)
        if args.check_source:
            print("Product documentation source: PASS")
        elif args.check:
            actual = (root / ROOT_README).read_text(encoding="utf-8")
            if actual != rendered:
                print("README.md is not the projection of docs/product/README.md", file=sys.stderr)
                return 1
            print("Product documentation projection: PASS")
        else:
            if bool(args.source_sha) != bool(args.release_version):
                raise ValueError("--source-sha and --release-version must be provided together")
            (root / ROOT_README).write_text(rendered, encoding="utf-8")
            if args.source_sha:
                write_provenance(root, args.source_sha, args.release_version)
            print(f"Projected {SOURCE_README} to {ROOT_README}")
    except (OSError, ValueError) as exc:
        print(f"Product documentation projection failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
