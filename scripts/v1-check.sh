#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND="$ROOT/backend"
BIN="$ROOT/bin/omagen"
MANIFEST="$ROOT/manifest.json"
BAR_MANIFEST="$ROOT/bar-manifest.json"

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

section "Architecture routing"
"$ROOT/scripts/architecture-check.sh"

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
"$BIN" look-feel list | python3 -m json.tool >/dev/null || fail "look-feel catalog failed"
"$ROOT/bin/omagen-studio" --help >/dev/null
"$ROOT/scripts/test-omagen-theme-set.sh" || fail "theme-set dispatch tests failed"
"$ROOT/scripts/test-install-command.sh" || fail "installer command ownership tests failed"
"$ROOT/scripts/test-lazy-studio-contract.sh" || fail "lazy Studio lifecycle contract failed"

section "Marketplace preflight"
marketplace_report="$(mktemp "${TMPDIR:-/tmp}/omagen-marketplace-report.XXXXXX.json")"
trap 'rm -f -- "$marketplace_report"' EXIT
python3 "$ROOT/scripts/marketplace-preflight.py" \
    --commit "$(git -C "$ROOT" rev-parse HEAD)" \
    --report "$marketplace_report" || fail "marketplace preflight failed"

section "Shader source/QSB provenance"
python3 "$ROOT/scripts/verify-shader-provenance.py" || fail "shader provenance check failed"

section "Fresh package validation"
"$ROOT/scripts/test-fresh-package.sh" || fail "fresh package validation failed"

capabilities="$($BIN demo capabilities)" || fail "demo capabilities failed"
OMAGEN_CAPABILITIES_JSON="$capabilities" python3 - <<'PY'
import json
import os
import sys

data = json.loads(os.environ["OMAGEN_CAPABILITIES_JSON"])
for key in ("terminal", "editor", "monitor", "file_manager"):
    if key not in data:
        raise SystemExit(f"missing capability: {key}")
if not isinstance(data["terminal"], dict):
    raise SystemExit("invalid terminal capability")
if not data["terminal"].get("command"):
    if os.environ.get("OMAGEN_HEADLESS_CI") == "1":
        print("WARNING: no terminal capability available in headless CI; resolver contract was validated", file=sys.stderr)
    else:
        raise SystemExit("no terminal capability available")
PY

section "Manifest"
[[ -f "$MANIFEST" ]] || fail "manifest.json missing"
[[ -f "$BAR_MANIFEST" ]] || fail "bar-manifest.json missing"
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
python3 - "$MANIFEST" "$BAR_MANIFEST" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    overlay = json.load(stream)
with open(sys.argv[2], encoding="utf-8") as stream:
    bar = json.load(stream)

if bar.get("id") != "pretty.omagen.bar":
    raise SystemExit(f"unexpected bar plugin id: {bar.get('id')!r}")
if bar.get("version") != overlay.get("version"):
    raise SystemExit(f"bar manifest version {bar.get('version')!r} does not match overlay version {overlay.get('version')!r}")
if bar.get("kinds") != ["bar"]:
    raise SystemExit(f"bar manifest kinds must be ['bar']: {bar.get('kinds')!r}")
if bar.get("entryPoints", {}).get("bar") != "OmagenBar.qml":
    raise SystemExit("bar manifest must point at OmagenBar.qml")
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
    "OmagenBar.qml"
    "NativeBarClone.qml"
    "WorkspacePresentation.qml"
    "BarModel.js"
    "manifest.json"
    "bar-manifest.json"
    "bin/omagen"
    "bin/omagen-theme-set"
    "bin/omagen-studio"
    "scripts/marketplace-preflight.py"
    "scripts/test-marketplace-preflight.py"
    "scripts/verify-shader-provenance.py"
    "scripts/test-fresh-package.sh"
    "docs/shader-provenance.json"
    "NOTICE.md"
    "qml/services/BackendService.qml"
    "qml/gateways/BackendCommand.qml"
    "qml/gateways/SessionGateway.qml"
    "qml/gateways/GenerationGateway.qml"
    "qml/gateways/PreviewGateway.qml"
    "qml/gateways/ApplyGateway.qml"
    "qml/gateways/DemoGateway.qml"
    "qml/gateways/LookFeelGateway.qml"
    "qml/gateways/RuntimeGateway.qml"
    "qml/gateways/ConfigurationArgs.js"
    "qml/state/SessionState.qml"
    "qml/views/SetupWindow.qml"
    "qml/views/AdvancedRuntimeSetupWindow.qml"
    "qml/views/LiveCanvasPanel.qml"
    "qml/views/ShellDemoPanel.qml"
    "qml/views/BarDemoPanel.qml"
    "qml/components/ShellLab.qml"
    "qml/components/ShellRangeField.qml"
    "qml/components/BarDockControls.qml"
    "qml/components/BarWorkspaceControls.qml"
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
