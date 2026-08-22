#!/usr/bin/env bash
set -Eeuo pipefail

PLUGIN_ID="pretty.omagen"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$PLUGIN_ID"

# Omarchy's shell may be installed in the user's checkout rather than the
# system path. Prefer a valid existing OMARCHY_PATH, then resolve the paths
# used by the supported Omarchy layouts before making shell IPC calls.
# The running Omarchy checkout is the per-user install on this machine. It
# must win over a stale system-path value inherited from zshrc, otherwise the
# IPC calls below target the wrong shell instance and report "not running".
for candidate in "$HOME/.local/share/omarchy" "${OMARCHY_PATH:-}" "/usr/share/omarchy"; do
    if [[ -n "$candidate" && -f "$candidate/shell/shell.qml" ]]; then
        export OMARCHY_PATH="$candidate"
        break
    fi
done

usage() {
    cat <<EOF
Usage: $0
EOF
}

for arg in "$@"; do
    case "$arg" in
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done

echo "Building Omagen backend..."
mkdir -p "$SRC_DIR/bin"
"$SRC_DIR/scripts/build-backend.sh" "$SRC_DIR/bin/omagen"

echo "Installing Omagen..."
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
cp "$SRC_DIR/bin/studio-theme-set" "$DEST_DIR/bin/studio-theme-set"
chmod +x "$DEST_DIR/bin/studio-theme-set"

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
