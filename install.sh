#!/usr/bin/env bash
set -Eeuo pipefail

PLUGIN_ID="pretty.omagen"
BAR_PLUGIN_ID="pretty.omagen.bar"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$PLUGIN_ID"
BAR_DEST_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$BAR_PLUGIN_ID"

# Omarchy's shell may be installed in the user's checkout rather than the
# system path. Prefer a valid existing OMARCHY_PATH, then resolve the paths
# used by the supported Omarchy layouts before making shell IPC calls.
# OMARCHY_PATH is Omarchy's session-level source of truth. The user-local and
# packaged paths are fallbacks for callers launched without that environment.
for candidate in "${OMARCHY_PATH:-}" "$HOME/.local/share/omarchy" "/usr/share/omarchy"; do
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
# Replace executables atomically. The running shell can still have the old
# helper mapped, and copying over that inode returns ETXTBSY (Text file busy).
cp "$SRC_DIR/bin/omagen-studio" "$DEST_DIR/bin/.omagen-studio.new"
mv -f "$DEST_DIR/bin/.omagen-studio.new" "$DEST_DIR/bin/omagen-studio"
chmod +x "$DEST_DIR/bin/omagen-studio"
cp "$SRC_DIR/bin/studio-theme-set" "$DEST_DIR/bin/.studio-theme-set.new"
mv -f "$DEST_DIR/bin/.studio-theme-set.new" "$DEST_DIR/bin/studio-theme-set"
chmod +x "$DEST_DIR/bin/studio-theme-set"
cp "$SRC_DIR/bin/omagen-file-select" "$DEST_DIR/bin/.omagen-file-select.new"
mv -f "$DEST_DIR/bin/.omagen-file-select.new" "$DEST_DIR/bin/omagen-file-select"
chmod +x "$DEST_DIR/bin/omagen-file-select"

# The full bar is a separate plugin kind. Keeping it separate from the
# bar-widget manifest is required by Quattro's registry: a manifest selected
# as the active bar is not also treated as a layout widget.
echo "Installing $BAR_PLUGIN_ID..."
mkdir -p "$BAR_DEST_DIR"
if [[ -L "$BAR_DEST_DIR" ]]; then
    rm -f "$BAR_DEST_DIR"
    mkdir -p "$BAR_DEST_DIR"
fi
cp "$SRC_DIR/bar-manifest.json" "$BAR_DEST_DIR/manifest.json"
cp "$SRC_DIR/OmagenBar.qml" "$BAR_DEST_DIR/OmagenBar.qml"
cp "$SRC_DIR/BarSurface.qml" "$BAR_DEST_DIR/BarSurface.qml"
cp "$SRC_DIR/BarMoveGhostPanel.qml" "$BAR_DEST_DIR/BarMoveGhostPanel.qml"
cp "$SRC_DIR/CyberpunkBarSignal.qml" "$BAR_DEST_DIR/CyberpunkBarSignal.qml"
cp "$SRC_DIR/NativeBarClone.qml" "$BAR_DEST_DIR/NativeBarClone.qml"
cp "$SRC_DIR/WorkspacePresentation.qml" "$BAR_DEST_DIR/WorkspacePresentation.qml"
cp "$SRC_DIR/BarModel.js" "$BAR_DEST_DIR/BarModel.js"
rm -rf "$BAR_DEST_DIR/bar"
cp -a "$SRC_DIR/bar" "$BAR_DEST_DIR/bar"
cp "$SRC_DIR/qml/components/glitch.frag.qsb" "$BAR_DEST_DIR/glitch.frag.qsb"
cp "$SRC_DIR/qml/components/glitch.vert.qsb" "$BAR_DEST_DIR/glitch.vert.qsb"

echo "Installed $PLUGIN_ID -> $DEST_DIR"
echo "Installed $BAR_PLUGIN_ID -> $BAR_DEST_DIR"

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
