#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/bin/omagen"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/omagen-backend-verify.XXXXXXXX")"

cleanup() {
    rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT

if [[ ! -f "$BIN" ]]; then
    printf 'FAIL: bundled backend is missing: %s\n' "$BIN" >&2
    exit 1
fi

"$ROOT/scripts/build-backend.sh" "$TEMP_ROOT/omagen"

if ! cmp -s "$BIN" "$TEMP_ROOT/omagen"; then
    printf 'FAIL: bin/omagen does not match a deterministic build of backend/\n' >&2
    printf 'tracked: '
    sha256sum "$BIN"
    printf 'rebuilt: '
    sha256sum "$TEMP_ROOT/omagen"
    exit 1
fi

printf 'Bundled backend verified: '
sha256sum "$BIN"
