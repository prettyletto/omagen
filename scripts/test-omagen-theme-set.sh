#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/omagen-theme-set-test.XXXXXX")"
trap 'rm -rf -- "$TMP_DIR"' EXIT

HOME="$TMP_DIR/home"
export HOME
export XDG_CONFIG_HOME="$HOME/custom-config"
export OMARCHY_PATH="$TMP_DIR/omarchy"
export PATH="$TMP_DIR/bin:$PATH"
mkdir -p "$HOME" "$HOME/.config/omarchy/themes" "$OMARCHY_PATH/shell" "$OMARCHY_PATH/themes/ordinary-theme" \
  "$OMARCHY_PATH/themes/advanced-theme" \
  "$XDG_CONFIG_HOME/omarchy/plugins/pretty.omagen/bin" "$XDG_CONFIG_HOME/omarchy/hooks/theme-set.d" \
  "$HOME/.config/omarchy/hooks/theme-set.d" "$TMP_DIR/bin"
touch "$OMARCHY_PATH/shell/shell.qml"
printf '%s\n' '{"schema_version":1,"mode":"advanced","runtime":"pretty.omagen","requires_runtime":true,"features":["shell"]}' \
  >"$OMARCHY_PATH/themes/advanced-theme/omagen.runtime.json"

cat >"$TMP_DIR/bin/omarchy" <<'EOF'
#!/usr/bin/env bash
printf 'native:'
printf '<%s>' "$@"
printf '\n'
EOF
chmod +x "$TMP_DIR/bin/omarchy"

cat >"$XDG_CONFIG_HOME/omarchy/plugins/pretty.omagen/bin/studio-theme-set" <<'EOF'
#!/usr/bin/env bash
printf 'studio:'
printf '<%s>' "$@"
printf '\n'
EOF
chmod +x "$XDG_CONFIG_HOME/omarchy/plugins/pretty.omagen/bin/studio-theme-set"
export OMAGEN_STUDIO_THEME_SET="$XDG_CONFIG_HOME/omarchy/plugins/pretty.omagen/bin/studio-theme-set"
printf '#!/bin/sh\n# Omagen Advanced Runtime hook\n' >"$HOME/.config/omarchy/hooks/theme-set.d/omagen-theme-set"
chmod +x "$HOME/.config/omarchy/hooks/theme-set.d/omagen-theme-set"
cat >"$XDG_CONFIG_HOME/omarchy/plugins/pretty.omagen/bin/omagen" <<'EOF'
#!/usr/bin/env bash
printf 'runtime:' >>"$OMAGEN_RUNTIME_CALL_LOG"
printf '<%s>' "$@" >>"$OMAGEN_RUNTIME_CALL_LOG"
printf '\n' >>"$OMAGEN_RUNTIME_CALL_LOG"
EOF
chmod +x "$XDG_CONFIG_HOME/omarchy/plugins/pretty.omagen/bin/omagen"
export OMAGEN_RUNTIME_CALL_LOG="$TMP_DIR/runtime.log"

assert_log() {
  local expected="$1"
  local actual
  actual="$(tail -n 1 "$TMP_DIR/calls.log" 2>/dev/null || true)"
  [[ "$actual" == "$expected" ]] || {
    printf 'expected %s, got %s\n' "$expected" "$actual" >&2
    exit 1
  }
}

"$ROOT_DIR/bin/omagen-theme-set" 'Advanced Theme' --wait full >"$TMP_DIR/calls.log"
assert_log 'studio:<apply><advanced-theme><--no-hooks><--wait><full>'

"$ROOT_DIR/bin/omagen-theme-set" 'Ordinary Theme' >"$TMP_DIR/calls.log"
assert_log 'native:<theme><set><Ordinary Theme>'

if "$ROOT_DIR/bin/omagen-theme-set" 'Ordinary Theme' --wait full >"$TMP_DIR/calls.log" 2>&1; then
  printf 'native theme unexpectedly accepted Studio options\n' >&2
  exit 1
fi

printf '{"schema_version":1,"mode":"advanced","runtime":"wrong","requires_runtime":true,"features":["shell"]}\n' \
  >"$OMARCHY_PATH/themes/ordinary-theme/omagen.runtime.json"
"$ROOT_DIR/bin/omagen-theme-set" 'Ordinary Theme' >"$TMP_DIR/calls.log"
assert_log 'native:<theme><set><Ordinary Theme>'

for invalid_feature in 1foo _foo foo_bar; do
  printf '{"schema_version":1,"mode":"advanced","runtime":"pretty.omagen","requires_runtime":true,"features":["%s"]}\n' "$invalid_feature" \
    >"$OMARCHY_PATH/themes/ordinary-theme/omagen.runtime.json"
  "$ROOT_DIR/bin/omagen-theme-set" 'Ordinary Theme' >"$TMP_DIR/calls.log"
  assert_log 'native:<theme><set><Ordinary Theme>'
done
long_feature=$(printf 'a%.0s' {1..65})
printf '{"schema_version":1,"mode":"advanced","runtime":"pretty.omagen","requires_runtime":true,"features":["%s"]}\n' "$long_feature" \
  >"$OMARCHY_PATH/themes/ordinary-theme/omagen.runtime.json"
"$ROOT_DIR/bin/omagen-theme-set" 'Ordinary Theme' >"$TMP_DIR/calls.log"
assert_log 'native:<theme><set><Ordinary Theme>'

rm -f "$HOME/.config/omarchy/hooks/theme-set.d/omagen-theme-set"
"$ROOT_DIR/bin/omagen-theme-set" 'Ordinary Theme' >"$TMP_DIR/calls.log"
[[ "$(tail -n 1 "$OMAGEN_RUNTIME_CALL_LOG")" == 'runtime:<runtime><theme-set><ordinary-theme>' ]] || {
  printf 'runtime cleanup was not requested after native promotion\n' >&2
  exit 1
}

printf '#!/bin/sh\n# another tool\n' >"$HOME/.config/omarchy/hooks/theme-set.d/omagen-theme-set"
"$ROOT_DIR/bin/omagen-theme-set" 'Ordinary Theme' >"$TMP_DIR/calls.log"
[[ "$(wc -l <"$OMAGEN_RUNTIME_CALL_LOG")" -eq 2 ]] || {
  printf 'non-Omagen canonical hook incorrectly suppressed cleanup\n' >&2
  exit 1
}

rm -f "$HOME/.config/omarchy/hooks/theme-set.d/omagen-theme-set"
printf '#!/bin/sh\n# Omagen Advanced Runtime hook\n' >"$XDG_CONFIG_HOME/omarchy/hooks/theme-set.d/omagen-theme-set"
"$ROOT_DIR/bin/omagen-theme-set" 'Ordinary Theme' >"$TMP_DIR/calls.log"
[[ "$(wc -l <"$OMAGEN_RUNTIME_CALL_LOG")" -eq 3 ]] || {
  printf 'XDG-only hook incorrectly suppressed native cleanup\n' >&2
  exit 1
}
grep -q '^native:<theme><set><Ordinary Theme>$' "$TMP_DIR/calls.log" || {
  printf 'native theme was not promoted before runtime fallback\n' >&2
  exit 1
}

mkdir -p "$HOME/.config/omarchy/themes/user-advanced-theme"
printf '%s\n' '{"schema_version":1,"mode":"advanced","runtime":"pretty.omagen","requires_runtime":true,"features":["bar"]}' \
  >"$HOME/.config/omarchy/themes/user-advanced-theme/omagen.runtime.json"
"$ROOT_DIR/bin/omagen-theme-set" 'User Advanced Theme' >"$TMP_DIR/calls.log"
assert_log 'studio:<apply><user-advanced-theme><--no-hooks>'

rm -f "$OMAGEN_STUDIO_THEME_SET"
if "$ROOT_DIR/bin/omagen-theme-set" advanced-theme >"$TMP_DIR/calls.log" 2>&1; then
  printf 'advanced theme unexpectedly succeeded without its driver\n' >&2
  exit 1
fi

printf 'omagen-theme-set dispatch tests passed\n'
