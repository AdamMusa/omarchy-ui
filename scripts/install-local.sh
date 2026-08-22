#!/bin/bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
plugin_id=$(jq -r '.id' "$repo_dir/manifest.json")
plugins_dir="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins"
target="$plugins_dir/$plugin_id"

if [[ -e $target ]]; then
  echo "Refusing to overwrite existing plugin: $target" >&2
  exit 1
fi

mkdir -p "$plugins_dir"
cp -a "$repo_dir" "$target"
omarchy plugin validate "$target"
omarchy-shell shell rescanPlugins
omarchy plugin enable "$plugin_id"

echo "Installed and enabled $plugin_id"
echo "Open it with: omarchy-shell shell summon $plugin_id '{\"surface\":\"counter\"}'"

