#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/omagen-install-test.XXXXXX")"
trap 'rm -rf -- "$TMP_DIR"' EXIT

export HOME="$TMP_DIR/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_BIN_HOME="$HOME/.local/bin"
export OMARCHY_PATH="$TMP_DIR/omarchy"
export PATH="$TMP_DIR/bin:$PATH"
mkdir -p "$HOME" "$OMARCHY_PATH/shell" "$OMARCHY_PATH/themes" "$TMP_DIR/bin"
touch "$OMARCHY_PATH/shell/shell.qml"

cat >"$TMP_DIR/bin/omarchy" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$TMP_DIR/bin/omarchy-shell" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMP_DIR/bin/omarchy" "$TMP_DIR/bin/omarchy-shell"

run_install() {
  "$ROOT_DIR/install.sh" --skip-build >/dev/null
}

run_install
USER_THEME_SET="$XDG_BIN_HOME/omagen-theme-set"
[[ -x "$USER_THEME_SET" ]] || { printf 'user dispatcher was not installed\n' >&2; exit 1; }
[[ ! -e "$XDG_CONFIG_HOME/omarchy/plugins/pretty.omagen/qml/tests" ]] || {
  printf 'QML tests were copied into the production overlay package\n' >&2
  exit 1
}
[[ -f "$XDG_CONFIG_HOME/omarchy/plugins/pretty.omagen/manifest.json" ]] || {
  printf 'overlay manifest was not installed\n' >&2
  exit 1
}
[[ -f "$XDG_CONFIG_HOME/omarchy/plugins/pretty.omagen.bar/manifest.json" ]] || {
  printf 'full-bar manifest was not installed\n' >&2
  exit 1
}
[[ -f "$XDG_CONFIG_HOME/omarchy/plugins/pretty.omagen.bar/qml/services/BoundedOutputParser.qml" ]] || {
  printf 'full-bar QML service dependency was not installed\n' >&2
  exit 1
}
[[ "$(sed -n '1,2p' "$USER_THEME_SET")" == $'#!/usr/bin/env bash\n# Omagen user-facing theme activation adapter' ]] || {
  printf 'user dispatcher ownership marker missing\n' >&2
  exit 1
}

# Production starts with the plugin manager's clone as the overlay package.
# Verify that the documented in-place bar refresh uses that clone as a source
# without copying the overlay package onto itself or deleting its files.
PRODUCTION_HOME="$TMP_DIR/production-home"
PRODUCTION_CONFIG="$PRODUCTION_HOME/.config"
PRODUCTION_PLUGIN="$PRODUCTION_CONFIG/omarchy/plugins/pretty.omagen"
mkdir -p "$PRODUCTION_PLUGIN"
cp -a "$ROOT_DIR/." "$PRODUCTION_PLUGIN/"
HOME="$PRODUCTION_HOME" \
XDG_CONFIG_HOME="$PRODUCTION_CONFIG" \
XDG_STATE_HOME="$PRODUCTION_HOME/.local/state" \
XDG_CACHE_HOME="$PRODUCTION_HOME/.cache" \
XDG_BIN_HOME="$PRODUCTION_HOME/.local/bin" \
OMARCHY_PATH="$OMARCHY_PATH" \
"$PRODUCTION_PLUGIN/install.sh" --bar-only >/dev/null
[[ -f "$PRODUCTION_PLUGIN/manifest.json" ]] || {
  printf 'bar-only production refresh modified the overlay package\n' >&2
  exit 1
}
[[ -f "$PRODUCTION_CONFIG/omarchy/plugins/pretty.omagen.bar/manifest.json" ]] || {
  printf 'bar-only production refresh did not install the full-bar manifest\n' >&2
  exit 1
}
[[ -f "$PRODUCTION_CONFIG/omarchy/plugins/pretty.omagen.bar/qml/services/BoundedOutputParser.qml" ]] || {
  printf 'bar-only production refresh did not install the full-bar QML service dependency\n' >&2
  exit 1
}

printf 'user-owned command\n' >"$USER_THEME_SET"
run_install
[[ "$(<"$USER_THEME_SET")" == 'user-owned command' ]] || {
  printf 'existing user command was overwritten\n' >&2
  exit 1
}

rm -f "$USER_THEME_SET"
ln -s "$TMP_DIR/missing-target" "$USER_THEME_SET"
run_install
[[ -L "$USER_THEME_SET" ]] || { printf 'existing symlink was overwritten\n' >&2; exit 1; }

rm -f "$USER_THEME_SET"
cp "$ROOT_DIR/bin/omagen-theme-set" "$USER_THEME_SET"
run_install
cmp -s "$ROOT_DIR/bin/omagen-theme-set" "$USER_THEME_SET" || {
  printf 'Omagen-owned user command was not updated\n' >&2
  exit 1
}

"$ROOT_DIR/uninstall.sh" >/dev/null
[[ ! -e "$USER_THEME_SET" && ! -L "$USER_THEME_SET" ]] || {
  printf 'Omagen-owned user command was not removed\n' >&2
  exit 1
}

printf 'installer user-command ownership tests passed\n'
