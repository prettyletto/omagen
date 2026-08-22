#!/usr/bin/env bash

# Report whether the installed Omarchy theme pipeline still matches the N1
# compatibility snapshot. This command is intentionally read-only: it does
# not set a theme, reload a compositor, invoke shell IPC, or run hooks.

set -u

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
LOCK_FILE="$ROOT_DIR/docs/omarchy-theme-pipeline.lock"
drift=0

lock_value() {
  local key="$1"
  awk -F= -v wanted="$key" '$1 == wanted { print substr($0, index($0, "=") + 1); exit }' "$LOCK_FILE"
}

resolve_path() {
  local candidate="$1"
  readlink -f -- "$candidate" 2>/dev/null || true
}

command_path() {
  local command_name="$1"
  local found

  found=$(command -v "$command_name" 2>/dev/null || true)
  [[ -n $found ]] || return 0
  resolve_path "$found"
}

file_sha256() {
  local path="$1"
  [[ -f $path ]] || return 0
  sha256sum "$path" | awk '{print $1}'
}

compare_value() {
  local label="$1"
  local expected="$2"
  local actual="$3"

  if [[ -n $actual && $actual == "$expected" ]]; then
    printf '[PASS] %s: %s\n' "$label" "$actual"
  else
    printf '[DRIFT] %s: expected=%s actual=%s\n' "$label" "${expected:-<missing>}" "${actual:-<missing>}"
    drift=1
  fi
}

if [[ ! -f $LOCK_FILE ]]; then
  printf '[DRIFT] lock file missing: %s\n' "$LOCK_FILE"
  exit 1
fi

omarchy_root=""
for candidate in "${OMARCHY_PATH:-}" "$HOME/.local/share/omarchy" "/usr/share/omarchy"; do
  [[ -n $candidate ]] || continue
  resolved=$(resolve_path "$candidate")
  if [[ -f "$resolved/shell/shell.qml" ]]; then
    omarchy_root="$resolved"
    break
  fi
done

theme_set_path=$(command_path omarchy-theme-set)
templates_path=$(command_path omarchy-theme-set-templates)
hook_path=$(command_path omarchy-hook)

omarchy_version=""
if command -v omarchy >/dev/null 2>&1; then
  omarchy_version=$(omarchy version 2>/dev/null | head -n 1)
fi

theme_name_file="$HOME/.local/state/omarchy/current/theme.name"
current_theme_name="<missing>"
[[ -f $theme_name_file ]] && current_theme_name=$(<"$theme_name_file")

background_link="$HOME/.local/state/omarchy/current/background"
background_target="<missing>"
[[ -e $background_link || -L $background_link ]] && background_target=$(resolve_path "$background_link")

template_count=0
if [[ -d "$omarchy_root/default/themed" ]]; then
  template_count=$(find "$omarchy_root/default/themed" -maxdepth 1 -type f -name '*.tpl' -printf '.' 2>/dev/null | wc -c)
fi

printf '%s\n' 'Omarchy theme pipeline drift report'
printf 'root=%s\n' "${omarchy_root:-<missing>}"
printf 'theme=%s\n' "$current_theme_name"
printf 'background=%s\n' "$background_target"
printf 'builtin_templates=%s\n' "$template_count"
printf 'theme_set=%s\n' "${theme_set_path:-<missing>}"
printf 'theme_set_templates=%s\n' "${templates_path:-<missing>}"
printf 'hook_runner=%s\n' "${hook_path:-<missing>}"

compare_value 'omarchy version' "$(lock_value omarchy_version)" "$omarchy_version"
compare_value 'omarchy-theme-set sha256' "$(lock_value theme_set_sha256)" "$(file_sha256 "$theme_set_path")"
compare_value 'omarchy-theme-set-templates sha256' "$(lock_value theme_set_templates_sha256)" "$(file_sha256 "$templates_path")"
compare_value 'omarchy-hook sha256' "$(lock_value hook_sha256)" "$(file_sha256 "$hook_path")"

if (( drift == 0 )); then
  printf '%s\n' 'result=PASS'
else
  printf '%s\n' 'result=DRIFT'
fi

exit "$drift"
