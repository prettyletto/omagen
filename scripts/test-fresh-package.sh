#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/omagen-fresh-package.XXXXXXXX")"
cleanup() {
    if ! rm -rf -- "$TEMP_ROOT"; then
        # The fixture has already passed its checks. Do not turn a runner
        # cleanup race into a false validation failure or hide the real result.
        printf 'fresh package: cleanup warning: could not remove %s\n' "$TEMP_ROOT" >&2
    fi
}
trap cleanup EXIT

# Make a clean package fixture from the current checkout, including staged,
# unstaged, and newly created files. This models the source tree a fresh clone
# receives without installing or executing any plugin code.
PACKAGE="$TEMP_ROOT/package"
mkdir -p "$PACKAGE"
cp -a "$ROOT"/. "$PACKAGE"/
rm -rf -- "$PACKAGE/.git" "$PACKAGE/.tmp" "$PACKAGE/target"

git -C "$PACKAGE" init -q
git -C "$PACKAGE" config user.email "fresh-package@example.invalid"
git -C "$PACKAGE" config user.name "Omagen Fresh Package"
git -C "$PACKAGE" add -A
git -C "$PACKAGE" commit -qm "fresh package fixture"
commit="$(git -C "$PACKAGE" rev-parse HEAD)"

while IFS= read -r -d '' link; do
    printf 'fresh package: symlink is not allowed: %s\n' "${link#"$PACKAGE"/}" >&2
    exit 1
done < <(find "$PACKAGE" -type l -print0)

python3 "$PACKAGE/scripts/marketplace-preflight.py" \
    --root "$PACKAGE" \
    --commit "$commit" \
    --report "$TEMP_ROOT/marketplace-preflight.json"
python3 "$PACKAGE/scripts/verify-shader-provenance.py"

if command -v omarchy >/dev/null 2>&1; then
    omarchy plugin validate "$PACKAGE"
fi

printf 'fresh package validation: PASS (%s)\n' "$commit"
