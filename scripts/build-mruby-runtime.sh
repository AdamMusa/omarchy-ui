#!/bin/bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
mruby_version=4.0.0
mruby_revision=831da26b9021de0369d17b71b5667e2941a1a32d
cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-ui/mruby-$mruby_version
output_dir=$repo_dir/build/runtime
zui_source_dir=${ZUI_SOURCE_DIR:-$repo_dir/../zui}

if [[ ! -f $zui_source_dir/lib/zui.rb ]]; then
  echo "Zui source tree not found: $zui_source_dir" >&2
  exit 1
fi

if [[ ! -d $cache_dir/.git ]]; then
  mkdir -p "$(dirname -- "$cache_dir")"
  git clone --filter=blob:none https://github.com/mruby/mruby.git "$cache_dir"
fi

if [[ $(git -C "$cache_dir" rev-parse HEAD) != "$mruby_revision" ]]; then
  git -C "$cache_dir" fetch --depth 1 origin "$mruby_revision"
  git -C "$cache_dir" checkout --detach "$mruby_revision"
fi

export SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-$(git -C "$repo_dir" log -1 --format=%ct)}
export ZUI_SOURCE_DIR=$zui_source_dir
MRUBY_CONFIG="$repo_dir/runtime/build_config.rb" rake -C "$cache_dir" clean all
mkdir -p "$output_dir"
install -s -m755 "$cache_dir/build/host/bin/mruby" "$output_dir/omarchy-ui-runtime"
"$output_dir/omarchy-ui-runtime" -e 'puts "omarchy-ui-runtime #{OmarchyUI::VERSION}, zui #{Zui::VERSION} (mruby #{MRUBY_VERSION})"'
