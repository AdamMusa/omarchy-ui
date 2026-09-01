#!/bin/bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd -- "$repo_dir"
zui_source_dir=${ZUI_SOURCE_DIR:-$repo_dir/../zui}
zui_lib=$zui_source_dir/lib

ruby -I"$zui_lib" -Ilib test/adapter_test.rb
ruby -I"$zui_lib" -Ilib test/cli_test.rb
ruby -I"$zui_lib" -Ilib test/framework_boundary_test.rb
ruby -I"$zui_lib" -Ilib test/plugin_publisher_test.rb
scripts/sync-zui-examples.rb --check

mapfile -t showcase_apps < <(find examples -mindepth 1 -maxdepth 1 -type d -exec test -f '{}/app.rb' \; -print | sort)
for showcase_dir in "${showcase_apps[@]}"; do
  showcase_app=${showcase_dir#examples/}
  ruby -I"$zui_lib" -Ilib "$showcase_dir/test/app_test.rb"
  if find "examples/$showcase_app" -type f \( -name '*.qml' -o -name '*.qmltypes' \) -print -quit | grep -q .; then
    echo "Application-owned QML found in examples/$showcase_app" >&2
    exit 1
  fi
done
ruby -c lib/omarchy_ui.rb
ruby -e 'abort "invalid gemspec" unless Gem::Specification.load("omarchy-ui.gemspec")'

runtime=${OMARCHY_UI_RUNTIME:-vendor/runtime/x86_64-linux/omarchy-ui-runtime}
if [[ -x $runtime ]]; then
  (
    cd vendor/runtime/x86_64-linux
    sha256sum --check omarchy-ui-runtime.sha256
  )
  "$runtime" "$repo_dir/test/runtime_adapter_check.rb"
  for showcase_dir in "${showcase_apps[@]}"; do
    runtime_check="$repo_dir/$showcase_dir/test/runtime_check.rb"
    [[ -f $runtime_check ]] || continue
    OMARCHY_UI_PROJECT_DIR="$repo_dir/$showcase_dir" \
      "$runtime" "$runtime_check"
  done
fi

if command -v qmlformat >/dev/null 2>&1; then
  while IFS= read -r qml_file; do
    qmlformat "$qml_file" >/dev/null
  done < <(find . -maxdepth 1 -name '*.qml' -type f -print)
fi

if command -v qmllint >/dev/null 2>&1 && [ -d /usr/share/omarchy/shell ]; then
  lint_dir=$(mktemp -d)
  trap 'rm -rf -- "$lint_dir"' EXIT
  ruby -Ilib -e 'require "omarchy_ui"; OmarchyUI::Runtime.install_package(ARGV.fetch(0))' "$lint_dir"
  ln -s /usr/share/omarchy/shell/Commons "$lint_dir/Commons"
  ln -s /usr/share/omarchy/shell/Ui "$lint_dir/Ui"
  qmllint -I "$lint_dir" -I /usr/share/omarchy/shell \
    "$lint_dir/App.qml" "$lint_dir/Service.qml" "$lint_dir/Panel.qml" "$lint_dir/BarWidget.qml"
  rm -rf -- "$lint_dir"
  trap - EXIT
fi

git diff --check
echo "Omarchy UI adapter tests passed."
