#!/usr/bin/env python3
"""Validate the intentionally small YAML shape used by context-map.yaml."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re
import sys


SECTIONS = ("docs", "source", "tests", "dependencies", "avoid")
PATH_PREFIXES = (
    "AGENTS.md",
    "README.md",
    "SUMMARY.md",
    "Omagen",
    "NativeBarClone.qml",
    "BarModel.js",
    "WorkspacePresentation.qml",
    "backend/",
    "bar",
    "bar/",
    "bin/",
    "docs/",
    "qml/",
    "scripts/",
    "scripts",
    "manifest.json",
    "bar-manifest.json",
    "install.sh",
    "dev-install.sh",
    ".github/",
)
EXACT_PATHS = {
    "AGENTS.md",
    "README.md",
    "SUMMARY.md",
    "NativeBarClone.qml",
    "BarModel.js",
    "WorkspacePresentation.qml",
    "manifest.json",
    "bar-manifest.json",
    "install.sh",
    "dev-install.sh",
    "bar",
    "scripts",
}


@dataclass
class Domain:
    name: str
    entries: dict[str, list[str]]


def parse_map(path: Path) -> list[Domain]:
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0].strip() != "version: 1":
        raise ValueError("context map must begin with 'version: 1'")
    if len(lines) < 2 or lines[1].strip() != "domains:":
        raise ValueError("context map must declare a top-level 'domains' mapping")

    domains: list[Domain] = []
    current: Domain | None = None
    section: str | None = None
    for number, raw in enumerate(lines[2:], start=3):
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        indent = len(raw) - len(raw.lstrip(" "))
        text = raw.strip()
        if "\t" in raw:
            raise ValueError(f"line {number}: tabs are not allowed")

        if indent == 2 and re.fullmatch(r"[a-z0-9-]+:", text):
            name = text[:-1]
            current = Domain(name, {})
            domains.append(current)
            section = None
            continue
        if indent == 4 and text.endswith(":") and current is not None:
            name = text[:-1]
            if name not in SECTIONS:
                raise ValueError(f"line {number}: unknown context-map section {name!r}")
            if name in current.entries:
                raise ValueError(f"line {number}: duplicate section {name!r}")
            current.entries[name] = []
            section = name
            continue
        if indent == 6 and text.startswith("-") and current is not None and section:
            value = text[1:].strip()
            if not value:
                raise ValueError(f"line {number}: empty {section} entry")
            current.entries[section].append(value)
            continue
        raise ValueError(f"line {number}: malformed context-map structure")

    if not domains:
        raise ValueError("context map contains no domains")
    names = [domain.name for domain in domains]
    if len(names) != len(set(names)):
        raise ValueError("context map contains duplicate domains")
    for domain in domains:
        missing = [section for section in SECTIONS if not domain.entries.get(section)]
        if missing:
            raise ValueError(f"domain {domain.name!r} is missing non-empty sections: {', '.join(missing)}")
    return domains


def matches(root: Path, value: str) -> bool:
    value = value.removeprefix("./")
    if any(character in value for character in "*?["):
        return any(root.glob(value))
    return (root / value).exists()


def is_path_like(value: str) -> bool:
    if value in EXACT_PATHS:
        return True
    if value.startswith("Omagen"):
        return True
    return any(prefix.endswith("/") and value.startswith(prefix) for prefix in PATH_PREFIXES)


def validate_paths(root: Path, domains: list[Domain]) -> list[str]:
    errors: list[str] = []
    for domain in domains:
        for section, entries in domain.entries.items():
            for value in entries:
                if not is_path_like(value):
                    errors.append(f"{domain.name}.{section}: unsupported path/command entry {value!r}")
                elif not matches(root, value):
                    errors.append(f"{domain.name}.{section}: mapped path does not exist: {value}")
    return errors


def validate_recipe_references(root: Path) -> list[str]:
    errors: list[str] = []
    token_pattern = re.compile(r"`([^`]+)`")
    for recipe in sorted((root / "docs/agents/recipes").glob("*.md")):
        for token in token_pattern.findall(recipe.read_text(encoding="utf-8")):
            value = token.strip().rstrip(".,;:")
            if not is_path_like(value):
                continue
            # Recipes sometimes show a path followed by a shell placeholder.
            value = value.split()[0]
            if not matches(root, value):
                errors.append(f"{recipe.relative_to(root)}: referenced path does not exist: {value}")
    return errors


def validate_view_processes(root: Path) -> list[str]:
    errors: list[str] = []
    for view in sorted((root / "qml/views").rglob("*.qml")):
        if re.search(r"^\s*Process\s*\{", view.read_text(encoding="utf-8"), re.MULTILINE):
            errors.append(f"{view.relative_to(root)}: views must route backend processes through qml/gateways")
    return errors


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    map_path = root / "docs/agents/context-map.yaml"
    try:
        domains = parse_map(map_path)
        errors = validate_paths(root, domains)
        errors.extend(validate_recipe_references(root))
        errors.extend(validate_view_processes(root))
    except (OSError, ValueError) as error:
        print(f"Context integrity error: {error}", file=sys.stderr)
        return 1

    if errors:
        print("Context integrity errors:", file=sys.stderr)
        print("\n".join(f"- {error}" for error in errors), file=sys.stderr)
        return 1
    print(f"Context integrity: PASS ({len(domains)} domains)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
