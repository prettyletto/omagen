#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
REPOSITORY_ROOT="${OMAGEN_POLICY_REPOSITORY_ROOT:-$SCRIPT_ROOT}"
MAX_BYTES="${OMAGEN_MAX_NEW_NONRUNTIME_FILE_BYTES:-5242880}"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

usage() {
    printf 'Usage: %s <base-commit> <head-commit>\n' "${0##*/}" >&2
    exit 2
}

[[ $# -eq 2 ]] || usage
BASE="$1"
HEAD="$2"

[[ "$MAX_BYTES" =~ ^[0-9]+$ ]] || fail "OMAGEN_MAX_NEW_NONRUNTIME_FILE_BYTES must be an integer"
(( MAX_BYTES > 0 )) || fail "maximum file size must be positive"
git -C "$REPOSITORY_ROOT" rev-parse --verify "$BASE^{commit}" >/dev/null || fail "base commit is not available: $BASE"
git -C "$REPOSITORY_ROOT" rev-parse --verify "$HEAD^{commit}" >/dev/null || fail "head commit is not available: $HEAD"

is_runtime_binary() {
    case "$1" in
        bin/omagen|bin/omagen-studio)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

format_bytes() {
    numfmt --to=iec-i --suffix=B "$1" 2>/dev/null || printf '%s bytes' "$1"
}

violations=()
while IFS= read -r -d '' path; do
    is_runtime_binary "$path" && continue

    size="$(git -C "$REPOSITORY_ROOT" cat-file -s "$HEAD:$path")"
    if (( size > MAX_BYTES )); then
        violations+=("$path ($(format_bytes "$size"), limit $(format_bytes "$MAX_BYTES"))")
    fi
done < <(git -C "$REPOSITORY_ROOT" diff --no-renames --name-only --diff-filter=ACM -z "$BASE" "$HEAD" --)

if (( ${#violations[@]} > 0 )); then
    printf 'New or modified non-runtime files exceed the repository history budget:\n' >&2
    printf '  - %s\n' "${violations[@]}" >&2
    printf '\nMove large media to release/documentation hosting or reduce it before merging.\n' >&2
    exit 1
fi

printf 'Large-file policy passed (non-runtime limit: %s).\n' "$(format_bytes "$MAX_BYTES")"
