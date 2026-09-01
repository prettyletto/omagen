#!/usr/bin/env bash
set -Eeuo pipefail

# This script installs a tester-selected, exact commit. It deliberately refuses
# to execute a mutable branch head, so the caller can inspect the commit before
# running the installer.
REPOSITORY="${OMAGEN_TEST_REPOSITORY:-https://github.com/prettyletto/omagen.git}"
BRANCH="${OMAGEN_TEST_BRANCH:-nightly}"
COMMIT="${OMAGEN_TEST_COMMIT:-}"

usage() {
    cat <<EOF
Usage: OMAGEN_TEST_COMMIT=<full-sha> $0

The exact commit is required before any checked-out code is executed:
  OMAGEN_TEST_COMMIT=<40-character-sha>
  OMAGEN_TEST_BRANCH=<branch> OMAGEN_TEST_REPOSITORY=<url> $0
EOF
}

for arg in "$@"; do
    case "$arg" in
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done

command -v git >/dev/null 2>&1 || {
    echo "git is required to install a branch checkout." >&2
    exit 1
}

if [[ ! "$COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
    echo "OMAGEN_TEST_COMMIT must be a full 40-character commit SHA." >&2
    echo "Refusing to execute mutable branch '$BRANCH'." >&2
    exit 2
fi

checkout_root="$(mktemp -d "${TMPDIR:-/tmp}/omagen-branch.XXXXXX")"
cleanup() {
    rm -rf -- "$checkout_root"
}
trap cleanup EXIT

checkout="$checkout_root/source"
echo "Fetching Omagen branch '$BRANCH' for commit $COMMIT..."
git clone --no-checkout --filter=blob:none --single-branch --branch "$BRANCH" "$REPOSITORY" "$checkout"
git -C "$checkout" fetch --depth 1 origin "$COMMIT"
git -C "$checkout" checkout --detach "$COMMIT"
actual_commit="$(git -C "$checkout" rev-parse HEAD)"
[[ "$actual_commit" == "$COMMIT" ]] || {
    echo "Fetched commit does not match requested commit." >&2
    exit 1
}
echo "Testing exact commit $actual_commit."

echo "Installing Omagen branch '$BRANCH'..."
"$checkout/dev-install.sh" --skip-build

echo "Omagen branch '$BRANCH' is installed."
