#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="${1:-$ROOT/bin/omagen}"
TOOLCHAIN_VERSION="$(awk '$1 == "go" { print $2; exit }' "$ROOT/backend/go.mod")"

if [[ -z "$TOOLCHAIN_VERSION" ]]; then
    printf 'backend/go.mod does not declare a Go version\n' >&2
    exit 1
fi

if [[ "$OUTPUT" != /* ]]; then
    OUTPUT="$ROOT/$OUTPUT"
fi

mkdir -p "$(dirname -- "$OUTPUT")"

# Keep this command intentionally boring and explicit. The checked-in binary
# is part of the plugin package, so every developer and CI must use the same
# source-to-binary transformation before changing it.
(
    cd "$ROOT/backend"
    GOFLAGS= \
    GOTOOLCHAIN="go$TOOLCHAIN_VERSION" \
    GOEXPERIMENT=nodwarf5 \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64 \
    GOAMD64=v1 \
    go build \
        -mod=readonly \
        -trimpath \
        -buildvcs=false \
        -ldflags='-buildid=' \
        -o "$OUTPUT" \
        ./cmd/omagen
)

chmod +x "$OUTPUT"
