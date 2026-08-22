#!/bin/bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
mruby_version=4.0.0
cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-ui/mruby-$mruby_version
output_dir=$repo_dir/build/runtime

if [[ ! -d $cache_dir/.git ]]; then
  mkdir -p "$(dirname -- "$cache_dir")"
  git clone --depth 1 --branch "$mruby_version" https://github.com/mruby/mruby.git "$cache_dir"
fi

MRUBY_CONFIG="$repo_dir/runtime/build_config.rb" rake -C "$cache_dir" all
mkdir -p "$output_dir"
install -s -m755 "$cache_dir/build/host/bin/mruby" "$output_dir/omarchy-ui-runtime"
"$output_dir/omarchy-ui-runtime" -e 'puts "omarchy-ui-runtime #{OmarchyUI::VERSION} (mruby #{MRUBY_VERSION})"'
