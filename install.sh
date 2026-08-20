#!/usr/bin/env bash
set -Eeuo pipefail

PLUGIN_ID="pretty.omagen"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$PLUGIN_ID"
MODE="dev"

usage() {
    cat <<EOF
Usage: $0 [--dev|--copy]

  --dev   Build and fast-sync the checkout into the Omarchy plugin directory (default).
  --copy  Build and copy a self-contained plugin installation.
EOF
}

for arg in "$@"; do
    case "$arg" in
        --dev) MODE="dev" ;;
        --copy) MODE="copy" ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done

echo "Building Omagen backend..."
mkdir -p "$SRC_DIR/bin"
go -C "$SRC_DIR/backend" build -o "$SRC_DIR/bin/omagen" ./cmd/omagen
chmod +x "$SRC_DIR/bin/omagen"

echo "Installing Omagen ($MODE mode)..."
mkdir -p "$DEST_DIR"

if [[ -L "$DEST_DIR" ]]; then
    rm -f "$DEST_DIR"
    mkdir -p "$DEST_DIR"
fi

cp "$SRC_DIR/manifest.json" "$DEST_DIR/manifest.json"
cp "$SRC_DIR/Omagen.qml" "$DEST_DIR/Omagen.qml"
cp "$SRC_DIR/OmagenBarWidget.qml" "$DEST_DIR/OmagenBarWidget.qml"
rm -f "$DEST_DIR/BarWidget.qml" "$DEST_DIR/Widget.qml"
rm -rf "$DEST_DIR/demo"
cp -a "$SRC_DIR/demo" "$DEST_DIR/demo"
mkdir -p "$DEST_DIR/qml" "$DEST_DIR/bin"
rsync -a --delete "$SRC_DIR/qml/" "$DEST_DIR/qml/"
cp "$SRC_DIR/bin/omagen" "$DEST_DIR/bin/omagen"
chmod +x "$DEST_DIR/bin/omagen"

echo "Installed $PLUGIN_ID -> $DEST_DIR"

if omarchy-shell shell rescanPlugins; then
    echo "Omarchy shell rescanned plugins."
else
    echo "Omarchy shell is not running; rescan later with:"
    echo "  omarchy-shell shell rescanPlugins"
fi

if omarchy plugin enable "$PLUGIN_ID" >/dev/null 2>&1; then
    echo "Enabled $PLUGIN_ID."
else
    echo "Plugin not enabled automatically; enable later with:"
    echo "  omarchy plugin enable $PLUGIN_ID"
fi
