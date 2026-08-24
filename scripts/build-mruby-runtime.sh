#!/bin/bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
set -a
source "$repo_dir/runtime/inputs.env"
set +a
cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-ui/mruby-$MRUBY_VERSION-$MRUBY_REVISION
output_dir=$repo_dir/build/runtime
zui_source_dir=${ZUI_SOURCE_DIR:-$repo_dir/../zui}

if [[ ! -f $zui_source_dir/lib/zui.rb ]]; then
  echo "Zui source tree not found: $zui_source_dir" >&2
  exit 1
fi

if [[ ! -d $zui_source_dir/.git ]]; then
  echo "Zui source is not a Git checkout: $zui_source_dir" >&2
  exit 1
fi

actual_zui_revision=$(git -C "$zui_source_dir" rev-parse HEAD)
if [[ $actual_zui_revision != "$ZUI_REVISION" ]]; then
  echo "Zui revision mismatch: expected $ZUI_REVISION, got $actual_zui_revision" >&2
  exit 1
fi

if [[ -n ${OMARCHY_UI_SOURCE_REVISION:-} ]]; then
  actual_source_revision=$(git -C "$repo_dir" rev-parse HEAD)
  if [[ $actual_source_revision != "$OMARCHY_UI_SOURCE_REVISION" ]]; then
    echo "Omarchy UI revision mismatch: expected $OMARCHY_UI_SOURCE_REVISION, got $actual_source_revision" >&2
    exit 1
  fi
fi

if [[ ! -d $cache_dir/.git ]]; then
  mkdir -p "$(dirname -- "$cache_dir")"
  git clone --filter=blob:none https://github.com/mruby/mruby.git "$cache_dir"
fi

if [[ $(git -C "$cache_dir" rev-parse HEAD) != "$MRUBY_REVISION" ]]; then
  git -C "$cache_dir" fetch --depth 1 origin "$MRUBY_REVISION"
  git -C "$cache_dir" checkout --detach "$MRUBY_REVISION"
fi

export SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-$(git -C "$repo_dir" log -1 --format=%ct)}
export ZUI_SOURCE_DIR=$zui_source_dir
MRUBY_CONFIG="$repo_dir/runtime/build_config.rb" rake -C "$cache_dir" clean all
mkdir -p "$output_dir"
install -s -m755 "$cache_dir/build/host/bin/mruby" "$output_dir/omarchy-ui-runtime"
strip --remove-section=.note.gnu.build-id "$output_dir/omarchy-ui-runtime"
"$output_dir/omarchy-ui-runtime" -e 'puts "omarchy-ui-runtime #{OmarchyUI::VERSION}, zui #{Zui::VERSION} (mruby #{MRUBY_VERSION})"'
