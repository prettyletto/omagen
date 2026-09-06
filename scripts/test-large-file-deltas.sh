#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/omagen-large-file-policy.XXXXXXXX")"
trap 'rm -rf -- "$TEMP_ROOT"' EXIT

git -C "$TEMP_ROOT" init -q
git -C "$TEMP_ROOT" config user.email test@example.invalid
git -C "$TEMP_ROOT" config user.name "Omagen Large File Policy"

printf 'small\n' >"$TEMP_ROOT/README.md"
git -C "$TEMP_ROOT" add README.md
git -C "$TEMP_ROOT" commit -qm baseline
base="$(git -C "$TEMP_ROOT" rev-parse HEAD)"

dd if=/dev/zero of="$TEMP_ROOT/oversized.dat" bs=1M count=6 status=none
git -C "$TEMP_ROOT" add oversized.dat
git -C "$TEMP_ROOT" commit -qm oversized
head="$(git -C "$TEMP_ROOT" rev-parse HEAD)"
if OMAGEN_POLICY_REPOSITORY_ROOT="$TEMP_ROOT" "$ROOT/scripts/check-large-file-deltas.sh" "$base" "$head"; then
    printf 'FAIL: oversized non-runtime file was accepted\n' >&2
    exit 1
fi

git -C "$TEMP_ROOT" rm -q oversized.dat
git -C "$TEMP_ROOT" commit -qm "remove oversized fixture"
base="$(git -C "$TEMP_ROOT" rev-parse HEAD)"
mkdir -p "$TEMP_ROOT/bin"
dd if=/dev/zero of="$TEMP_ROOT/bin/omagen" bs=1M count=6 status=none
git -C "$TEMP_ROOT" add bin/omagen
git -C "$TEMP_ROOT" commit -qm "add allowed runtime fixture"
head="$(git -C "$TEMP_ROOT" rev-parse HEAD)"
OMAGEN_POLICY_REPOSITORY_ROOT="$TEMP_ROOT" "$ROOT/scripts/check-large-file-deltas.sh" "$base" "$head"

printf 'Large-file policy tests passed.\n'
