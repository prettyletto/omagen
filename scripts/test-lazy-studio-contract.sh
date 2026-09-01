#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT_DIR/Omagen.qml"

grep -q 'id: liveCanvasLoader' "$SOURCE" || { printf 'lazy Studio Loader is missing\n' >&2; exit 1; }
grep -q 'id: shellDemoLoader' "$SOURCE" || { printf 'lazy Shell Demo Loader is missing\n' >&2; exit 1; }
grep -q 'id: barDemoLoader' "$SOURCE" || { printf 'lazy Bar Demo Loader is missing\n' >&2; exit 1; }
grep -q 'active: session.active && root.liveCanvasActive && root.demoActive && root.demoMode === "shell"' "$SOURCE" || {
  printf 'Shell Demo Loader is not mode-gated\n' >&2
  exit 1
}
grep -q 'active: session.active && root.liveCanvasActive && root.demoActive && root.demoMode === "bar"' "$SOURCE" || {
  printf 'Bar Demo Loader is not mode-gated\n' >&2
  exit 1
}
grep -q 'active: session.active || root.liveCanvasActive' "$SOURCE" || { printf 'Loader does not retain active sessions\n' >&2; exit 1; }
grep -q 'liveCanvasPanel: root.liveCanvasPanel' "$SOURCE" || { printf 'Preview controller is not wired to Loader item\n' >&2; exit 1; }
grep -q 'onLoaded:' "$SOURCE" || { printf 'Loader has no deferred-action handoff\n' >&2; exit 1; }

clear_count="$(grep -c 'deferredCanvasAction = null' "$SOURCE")"
(( clear_count >= 5 )) || { printf 'canvas deferred actions are not cleared on all hide/reroute paths\n' >&2; exit 1; }
if grep -Eq 'Qt\.callLater\(function\(\) \{ root\.(enterLiveCanvas|testLive|testLiveColors)\(' "$SOURCE"; then
  printf 'canvas actions still use unbounded recursive retries\n' >&2
  exit 1
fi

printf 'lazy Studio lifecycle contract passed\n'
