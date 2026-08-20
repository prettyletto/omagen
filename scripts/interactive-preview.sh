#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
image_path="${1:-$repo_root/dev/palette-preview/corpus/11-user-audi-quattro.png}"
cache_dir="${TMPDIR:-/tmp}/omagen-go-cache-interactive"
binary_path="${TMPDIR:-/tmp}/omagen-interactive-$$"
session_id=""
cleaned=0

cleanup() {
    local exit_code=$?
    if (( cleaned == 1 )); then
        exit "$exit_code"
    fi
    cleaned=1

    if [[ -n "$session_id" ]]; then
        printf '\nCleaning up Omagen session %s...\n' "$session_id"
        if ! "$binary_path" session cancel "$session_id"; then
            printf 'Session cancellation failed; attempting preview alias cleanup.\n' >&2
            "$binary_path" preview cleanup "$session_id" || true
        fi
    fi
    rm -f -- "$binary_path"
    exit "$exit_code"
}

trap 'exit 130' INT
trap 'exit 143' TERM
trap cleanup EXIT

if [[ ! -f "$image_path" ]]; then
    printf 'Image not found: %s\n' "$image_path" >&2
    exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
    printf 'jq is required. Install it, then run this script again.\n' >&2
    exit 2
fi

printf 'Building current Omagen binary...\n'
GOCACHE="$cache_dir" go -C "$repo_root/backend" build -o "$binary_path" ./cmd/omagen

printf 'Starting session for:\n  %s\n' "$image_path"
begin_json="$($binary_path session begin)"
session_id="$(jq -r '.session_id' <<<"$begin_json")"
if [[ -z "$session_id" || "$session_id" == "null" ]]; then
    printf 'Could not read session id from: %s\n' "$begin_json" >&2
    exit 1
fi
printf 'Session: %s\n' "$session_id"

generation_json="$($binary_path generate "$session_id" "$image_path")"
generation_id="$(jq -r '.generation_id' <<<"$generation_json")"
if [[ -z "$generation_id" || "$generation_id" == "null" ]]; then
    printf 'Could not read generation id from: %s\n' "$generation_json" >&2
    exit 1
fi
printf 'Generation: %s\n' "$generation_id"

while true; do
    printf '\nChoose a preview:\n'
    printf '  1) source\n  2) deep\n  3) vibrant\n  4) run all\n  q) quit and restore\n'
    read -r -p '> ' choice
    case "$choice" in
        1) variants=(source) ;;
        2) variants=(deep) ;;
        3) variants=(vibrant) ;;
        4) variants=(source deep vibrant) ;;
        q|Q) break ;;
        *) printf 'Please choose 1, 2, 3, 4, or q.\n'; continue ;;
    esac

    for variant in "${variants[@]}"; do
        printf '\nApplying %s...\n' "$variant"
        time "$binary_path" preview apply "$session_id" "$generation_id" "$variant"
    done
done

printf '\nLeaving interactive preview; the EXIT trap will restore the original theme.\n'
