#!/usr/bin/env bash
set -Eeuo pipefail

# This script is intended to be fetched from a branch and piped to a shell.
# It clones that branch first, so install.sh still resolves all package files
# relative to a real checkout.
REPOSITORY="${OMAGEN_TEST_REPOSITORY:-https://github.com/prettyletto/omagen.git}"
BRANCH="${OMAGEN_TEST_BRANCH:-dev}"

usage() {
    cat <<EOF
Usage: bash -c 'set -o pipefail; curl -fsSL https://raw.githubusercontent.com/prettyletto/omagen/dev/scripts/install-branch.sh | bash'

The default installs the dev branch. Override the source when needed:
  OMAGEN_TEST_BRANCH=<branch> OMAGEN_TEST_REPOSITORY=<url> bash
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

checkout_root="$(mktemp -d "${TMPDIR:-/tmp}/omagen-branch.XXXXXX")"
cleanup() {
    rm -rf -- "$checkout_root"
}
trap cleanup EXIT

checkout="$checkout_root/source"
echo "Cloning Omagen branch '$BRANCH'..."
git clone --depth 1 --single-branch --branch "$BRANCH" "$REPOSITORY" "$checkout"
commit="$(git -C "$checkout" rev-parse --short=12 HEAD)"
echo "Testing commit $commit."

echo "Installing Omagen branch '$BRANCH'..."
"$checkout/dev-install.sh" --skip-build

echo "Omagen branch '$BRANCH' is installed."
