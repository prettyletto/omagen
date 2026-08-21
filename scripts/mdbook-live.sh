#!/usr/bin/env zsh

set -euo pipefail

repo_dir=${0:A:h:h}
source_dir=/tmp/omagen-mdbook-src
build_dir=/tmp/omagen-mdbook
mdbook_bin=${MDBOOK_BIN:-$(command -v mdbook || true)}
if [[ -z "$mdbook_bin" && -x /home/prettyletto/.cargo/bin/mdbook ]]; then
  mdbook_bin=/home/prettyletto/.cargo/bin/mdbook
fi

if [[ -z "$mdbook_bin" ]]; then
  print -u2 "mdbook is not installed or is not on PATH"
  exit 1
fi

rm -rf "$source_dir"
mkdir -p "$source_dir/docs"
mkdir -p "$source_dir/assets"

sync_sources() {
  rsync -a --delete "$repo_dir/README.md" "$repo_dir/SUMMARY.md" "$source_dir/"
  rsync -a --delete "$repo_dir/docs/" "$source_dir/docs/"
  rsync -a --delete "$repo_dir/assets/" "$source_dir/assets/"
}

sync_sources

cat > "$source_dir/book.toml" <<EOF
[book]
title = "Omagen"
authors = ["Prettyletto"]
language = "en"
src = "."

[build]
build-dir = "$build_dir"
EOF

cleanup() {
  kill "$mdbook_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

"$mdbook_bin" serve --hostname 127.0.0.1 --port 3000 "$source_dir" &
mdbook_pid=$!

while kill -0 "$mdbook_pid" 2>/dev/null; do
  sync_sources
  sleep 1
done

wait "$mdbook_pid"
