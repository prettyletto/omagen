#!/usr/bin/env bash
set -Eeuo pipefail

PLUGIN_ID="pretty.omagen"
BAR_PLUGIN_ID="pretty.omagen.bar"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
PLUGIN_ROOT="$CONFIG_HOME/omarchy/plugins"
STATE_ROOT="$STATE_HOME/omagen"
CACHE_ROOT="$CACHE_HOME/omagen"
SETTINGS_ROOT="$CONFIG_HOME/omagen"
DEFAULT_HOOK="$CONFIG_HOME/omarchy/hooks/theme-set.d/omagen-theme-set"
RUNTIME_BIN="$PLUGIN_ROOT/$PLUGIN_ID/bin/omagen"
USER_THEME_SET="${XDG_BIN_HOME:-$HOME/.local/bin}/omagen-theme-set"

usage() {
    cat <<EOF
Usage: $0

Removes the Omagen overlay and bar plugins, Omagen-owned runtime hook and
user state. Permanent themes and non-Omagen hooks are preserved.
EOF
}

for arg in "$@"; do
    case "$arg" in
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done

die() {
    printf 'Uninstall stopped: %s\n' "$*" >&2
    exit 1
}

path_exists() {
    [[ -e "$1" || -L "$1" ]]
}

remove_owned_hook() {
    local hook_path="$1"
    [[ -f "$hook_path" && ! -L "$hook_path" ]] || return 0

    # Never remove a hook merely because it has an Omagen-looking filename.
    # The header is the ownership marker written by runtime.Install.
    if [[ "$(sed -n '1,2p' "$hook_path")" == $'#!/bin/sh\n# Omagen Advanced Runtime hook' ]]; then
        rm -f -- "$hook_path"
        printf 'Removed Omagen runtime hook: %s\n' "$hook_path"
    else
        printf 'Preserved non-Omagen hook: %s\n' "$hook_path" >&2
    fi
}

recover_active_session() {
    local active_marker="$STATE_ROOT/active-session.json"
    if ! path_exists "$active_marker"; then
        return 0
    fi

    [[ -f "$RUNTIME_BIN" && ! -L "$RUNTIME_BIN" && -x "$RUNTIME_BIN" ]] || die "an active Omagen session exists but its backend is unavailable or untrusted; cancel or recover the session before uninstalling"

    printf 'Recovering the active Omagen session before removal...\n'
    "$RUNTIME_BIN" session recover || die "active session recovery failed; no plugin or state was removed"
    path_exists "$active_marker" && die "active session remains after recovery; no plugin or state was removed"
}

cleanup_inactive_state() {
    [[ -f "$RUNTIME_BIN" && ! -L "$RUNTIME_BIN" && -x "$RUNTIME_BIN" ]] || return 0

    printf 'Cleaning inactive Omagen previews and sessions...\n'
    "$RUNTIME_BIN" cleanup || die "Omagen cleanup failed; no plugin or state was removed"
}

read_recorded_hook() {
    local state_file="$STATE_ROOT/advanced-runtime.json"
    [[ -f "$state_file" ]] || return 0
    command -v python3 >/dev/null 2>&1 || return 0

    python3 - "$state_file" <<'PY'
import json
import os
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as stream:
        value = json.load(stream).get("hook_path", "")
except (OSError, ValueError, TypeError, AttributeError):
    value = ""

if isinstance(value, str) and os.path.isabs(value):
    print(value)
PY
}

remove_plugin() {
    local plugin_id="$1"
    local plugin_path="$PLUGIN_ROOT/$plugin_id"

    if ! path_exists "$plugin_path"; then
        printf 'Plugin already absent: %s\n' "$plugin_id"
        return 0
    fi

    if command -v omarchy >/dev/null 2>&1; then
        omarchy plugin remove "$plugin_id" --yes >/dev/null 2>&1 || true
    fi
    # The plugin manager may not know about an older/manual installation.
    # The path is exact and package-owned, so remove it if it remains.
    if path_exists "$plugin_path"; then
        rm -rf -- "$plugin_path"
    fi
    path_exists "$plugin_path" && die "could not remove plugin directory: $plugin_path"
    printf 'Removed plugin: %s\n' "$plugin_id"
}

remove_owned_theme_set_command() {
    [[ -f "$USER_THEME_SET" && ! -L "$USER_THEME_SET" ]] || return 0
    if [[ "$(sed -n '1,2p' "$USER_THEME_SET")" == $'#!/usr/bin/env bash\n# Omagen user-facing theme activation adapter' ]]; then
        rm -f -- "$USER_THEME_SET"
        printf 'Removed Omagen user command: %s\n' "$USER_THEME_SET"
    else
        printf 'Preserved non-Omagen user command: %s\n' "$USER_THEME_SET" >&2
    fi
}

printf 'Removing Omagen while preserving user themes and unrelated hooks...\n'
recover_active_session
cleanup_inactive_state

recorded_hook="$(read_recorded_hook)"
remove_owned_hook "$DEFAULT_HOOK"
[[ -n "$recorded_hook" && "$recorded_hook" != "$DEFAULT_HOOK" ]] && remove_owned_hook "$recorded_hook"
[[ -n "${OMAGEN_RUNTIME_HOOK:-}" && "$OMAGEN_RUNTIME_HOOK" != "$DEFAULT_HOOK" && "$OMAGEN_RUNTIME_HOOK" != "$recorded_hook" ]] && remove_owned_hook "$OMAGEN_RUNTIME_HOOK"

remove_plugin "$PLUGIN_ID"
remove_plugin "$BAR_PLUGIN_ID"
remove_owned_theme_set_command

if path_exists "$SETTINGS_ROOT/settings.json"; then
    rm -f -- "$SETTINGS_ROOT/settings.json"
    printf 'Removed Omagen settings.\n'
fi
if [[ -d "$SETTINGS_ROOT" ]] && [[ -z "$(find "$SETTINGS_ROOT" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    rmdir -- "$SETTINGS_ROOT"
fi

if path_exists "$STATE_ROOT"; then
    rm -rf -- "$STATE_ROOT"
    printf 'Removed Omagen state: %s\n' "$STATE_ROOT"
fi
if path_exists "$CACHE_ROOT"; then
    rm -rf -- "$CACHE_ROOT"
    printf 'Removed Omagen cache: %s\n' "$CACHE_ROOT"
fi

if command -v omarchy-shell >/dev/null 2>&1; then
    if omarchy-shell shell rescanPlugins >/dev/null 2>&1; then
        printf 'Omarchy shell rescanned plugins.\n'
    else
        printf 'Warning: Omarchy shell rescan failed; rescan after restarting the shell.\n' >&2
    fi
fi
if command -v omarchy >/dev/null 2>&1; then
    if omarchy restart shell >/dev/null 2>&1; then
        printf 'Omarchy shell restarted.\n'
    else
        printf 'Warning: Omarchy shell restart failed; restart it manually.\n' >&2
    fi
fi

printf '\nOmagen uninstall complete. Permanent Omarchy themes were not removed.\n'
