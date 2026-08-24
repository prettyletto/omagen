#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND="$ROOT/backend"
BIN="$ROOT/bin/omagen"
MANIFEST="$ROOT/manifest.json"

fail() {
    printf '\nFAIL: %s\n' "$*" >&2
    exit 1
}

section() {
    printf '\n==> %s\n' "$1"
}

section "Go formatting"
unformatted="$(cd "$BACKEND" && gofmt -l .)"
if [[ -n "$unformatted" ]]; then
    printf '%s\n' "$unformatted" >&2
    fail "Go files are not formatted"
fi

section "Repository"
[[ -d "$BACKEND" ]] || fail "backend directory missing"
[[ -f "$BACKEND/go.mod" ]] || fail "backend/go.mod missing"

section "Go tests"
(cd "$BACKEND" && go test ./...)

section "Go race tests"
(cd "$BACKEND" && go test -race ./...)

section "Go vet"
(cd "$BACKEND" && go vet ./...)

section "Backend binary"
[[ -x "$BIN" ]] || fail "bin/omagen is missing or not executable"

section "Reproducible bundled backend"
"$ROOT/scripts/verify-bundled-backend.sh"

section "CLI smoke tests"
"$BIN" --help >/dev/null || fail "omagen --help failed"
"$BIN" help >/dev/null || fail "omagen help failed"
"$BIN" demo capabilities | python3 -m json.tool >/dev/null
"$ROOT/bin/omagen-studio" --help >/dev/null

capabilities="$($BIN demo capabilities)" || fail "demo capabilities failed"
python3 - "$capabilities" <<'PY'
import json
import sys

data = json.loads(sys.argv[1])
for key in ("terminal", "editor", "monitor", "file_manager"):
    if key not in data:
        raise SystemExit(f"missing capability: {key}")
if not isinstance(data["terminal"], dict) or not data["terminal"].get("command"):
    raise SystemExit("no terminal capability available")
PY

section "Manifest"
[[ -f "$MANIFEST" ]] || fail "manifest.json missing"
python3 - "$MANIFEST" "$BIN" <<'PY'
import json
import subprocess
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    manifest = json.load(stream)

if manifest.get("id") != "pretty.omagen":
    raise SystemExit(f"unexpected plugin id: {manifest.get('id')!r}")
if manifest.get("keepLoaded") is not True:
    raise SystemExit("manifest keepLoaded must be true")

binary = json.loads(subprocess.check_output([sys.argv[2], "ping"], text=True))
if manifest.get("version") != binary.get("version"):
    raise SystemExit(f"manifest version {manifest.get('version')!r} does not match binary version {binary.get('version')!r}")
PY

section "Omarchy plugin validator"
if command -v omarchy >/dev/null 2>&1; then
    omarchy plugin validate "$ROOT" || fail "omarchy plugin validate failed"
else
    printf 'WARNING: omarchy unavailable; skipping native plugin validation\n' >&2
fi

section "Required plugin files"
required=(
    "Omagen.qml"
    "OmagenBarWidget.qml"
    "manifest.json"
    "bin/omagen"
    "bin/omagen-studio"
    "qml/services/BackendService.qml"
    "qml/state/SessionState.qml"
    "qml/views/SetupWindow.qml"
    "qml/views/LiveCanvasPanel.qml"
    "qml/views/ShellDemoPanel.qml"
    "qml/views/BarDemoPanel.qml"
    "qml/components/ShellLab.qml"
    "qml/components/ShellValueField.qml"
    "qml/components/ShellRangeField.qml"
    "qml/components/ShellColorField.qml"
)
for relative in "${required[@]}"; do
    [[ -e "$ROOT/$relative" ]] || fail "missing required file: $relative"
done

section "Demo assets"
demo_files=(
    "demo/sample.go"
    "demo/config.json"
    "demo/assets/palette.txt"
    "demo/scripts/build.sh"
)
for relative in "${demo_files[@]}"; do
    [[ -e "$ROOT/$relative" ]] || fail "missing demo asset: $relative"
done

section "No plugin symlinks"
while IFS= read -r -d '' link; do
    fail "symlink is not allowed in V1 package: ${link#$ROOT/}"
done < <(find "$ROOT" -type l -print0)

section "QML syntax"
if command -v qmllint >/dev/null 2>&1; then
    mapfile -d '' qml_files < <(find "$ROOT" -name '*.qml' -print0)
    if ((${#qml_files[@]} > 0)); then
        qmllint "${qml_files[@]}" || fail "qmllint failed"
    fi
else
    printf 'WARNING: qmllint unavailable; skipping QML lint\n' >&2
fi

printf '\nV1 automated regression gate: PASS\n'
