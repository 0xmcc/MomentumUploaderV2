#!/bin/sh
set -eu

repo_root="$(git rev-parse --show-toplevel)"
hooks_source_dir="$repo_root/.githooks"
hooks_target_dir="$repo_root/.git/hooks"

if [ ! -d "$hooks_source_dir" ]; then
  echo "ERROR: Missing $hooks_source_dir"
  exit 1
fi

install_hook() {
  name="$1"
  src="$hooks_source_dir/$name"
  dst="$hooks_target_dir/$name"

  if [ ! -f "$src" ]; then
    echo "ERROR: Missing hook file: $src"
    exit 1
  fi

  cp "$src" "$dst"
  chmod +x "$dst"
  echo "Installed $dst"
}

install_hook pre-commit
install_hook pre-push

echo "Git hooks installed successfully."
