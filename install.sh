#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ID="pretty.omagen"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"

echo "Building Omagen backend..."

mkdir -p "$SRC_DIR/bin"

go -C "$SRC_DIR/backend" build \
  -o "$SRC_DIR/bin/omagen" \
  ./cmd/omagen

echo "Installing Omagen..."

mkdir -p "$DEST_DIR/bin"

rm -rf "$DEST_DIR/qml"

cp "$SRC_DIR/manifest.json" "$DEST_DIR/"
cp "$SRC_DIR/Omagen.qml" "$DEST_DIR/"
cp -r "$SRC_DIR/qml" "$DEST_DIR/"
cp "$SRC_DIR/bin/omagen" "$DEST_DIR/bin/"

chmod +x "$DEST_DIR/bin/omagen"

omarchy-shell shell rescanPlugins
omarchy plugin enable "$PLUGIN_ID" >/dev/null 2>&1 || true

echo "Installed $PLUGIN_ID -> $DEST_DIR"
