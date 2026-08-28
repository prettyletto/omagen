#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
warnings=0

warn_large() {
    local relative="$1" limit="$2" lines
    lines="$(wc -l < "$ROOT/$relative")"
    if (( lines > limit )); then
        printf 'WARNING: %s is %s lines (guideline: %s); review cohesion before splitting.\n' "$relative" "$lines" "$limit" >&2
        warnings=$((warnings + 1))
    fi
}

printf 'Architecture/context checks (size warnings only)\n'

canonical=(
    "AGENTS.md"
    "docs/architecture/README.md"
    "docs/architecture/frontend.md"
    "docs/architecture/backend.md"
    "docs/architecture/lifecycle.md"
    "docs/architecture/contracts/engine.md"
    "docs/architecture/contracts/qml-backend.md"
    "docs/architecture/contracts/studio-protocol.md"
    "docs/architecture/contracts/runtime.md"
    "docs/architecture/contracts/look-feel.md"
    "docs/architecture/contracts/bar-spec.md"
    "docs/agents/context-map.yaml"
)
for relative in "${canonical[@]}"; do
    if [[ ! -e "$ROOT/$relative" ]]; then
        printf 'ERROR: canonical context file is missing: %s\n' "$relative" >&2
        exit 1
    fi
done

"$ROOT/scripts/check-context-integrity.py"
"$ROOT/scripts/check-doc-links.py"

warn_large Omagen.qml 400
warn_large backend/internal/cli/cli.go 350
for file in "$ROOT"/backend/internal/cli/*_cmd.go; do
    [[ -e "$file" ]] || continue
    warn_large "${file#"$ROOT"/}" 400
done
while IFS= read -r -d '' file; do
    relative="${file#"$ROOT"/}"
    case "$relative" in
        qml/views/*) warn_large "$relative" 700 ;;
        qml/*) warn_large "$relative" 500 ;;
    esac
done < <(find "$ROOT/qml" -name '*.qml' -print0)

"$ROOT/scripts/agent-context" --list >/dev/null

if (( warnings == 0 )); then
    printf 'No size warnings.\n'
else
    printf '%s size warning(s); these are review prompts, not failures.\n' "$warnings"
fi
