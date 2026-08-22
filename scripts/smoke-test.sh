#!/bin/bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
started_at=$(date --iso-8601=seconds)

"$repo_dir/bin/omarchy_ui" push "$repo_dir"
sleep 1

plugin_id=$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV.fetch(0))).fetch("id")' "$repo_dir/manifest.json")
pgrep -f "ruby.*/${plugin_id}/main.rb" >/dev/null
omarchy-shell shell summon "$plugin_id" '{"surface":"counter"}' >/dev/null
sleep 1

errors=$(journalctl --user --since "$started_at" --no-pager \
  | grep -F "$plugin_id" \
  | grep -E 'failed|TypeError|ReferenceError|Invalid property|required property|is not a type' || true)

if [[ -n "$errors" ]]; then
  echo "$errors" >&2
  exit 1
fi

echo "Live Omarchy smoke test passed for $plugin_id"
