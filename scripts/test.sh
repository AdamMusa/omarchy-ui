#!/bin/bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd -- "$repo_dir"

ruby -Ilib test/adapter_test.rb
ruby -Ilib test/cli_test.rb
ruby -Ilib test/framework_boundary_test.rb
ruby -Ilib examples/restaurant_drinks/test/app_test.rb
ruby -Ilib examples/futuristic_dashboard/test/app_test.rb
showcase_apps=(
  tesla_drive_dashboard
  shader_studio
  cardiac_health_monitor
  orbital_weather_console
  quantum_market_terminal
  smart_home_energy
  cinematic_music_studio
)
for showcase_app in "${showcase_apps[@]}"; do
  ruby -Ilib "examples/$showcase_app/test/app_test.rb"
  if find "examples/$showcase_app" -type f \( -name '*.qml' -o -name '*.qmltypes' \) -print -quit | grep -q .; then
    echo "Application-owned QML found in examples/$showcase_app" >&2
    exit 1
  fi
done
ruby -c lib/omarchy_ui.rb
ruby -e 'abort "invalid gemspec" unless Gem::Specification.load("omarchy-ui.gemspec")'

runtime=vendor/runtime/x86_64-linux/omarchy-ui-runtime
if [[ -x $runtime ]]; then
  (
    cd vendor/runtime/x86_64-linux
    sha256sum --check omarchy-ui-runtime.sha256
  )
  OMARCHY_UI_PROJECT_DIR="$repo_dir/examples/restaurant_drinks" \
    "$runtime" "$repo_dir/examples/restaurant_drinks/test/runtime_check.rb"
  OMARCHY_UI_PROJECT_DIR="$repo_dir/examples/futuristic_dashboard" \
    "$runtime" "$repo_dir/examples/futuristic_dashboard/test/runtime_check.rb"
  for showcase_app in "${showcase_apps[@]}"; do
    OMARCHY_UI_PROJECT_DIR="$repo_dir/examples/$showcase_app" \
      "$runtime" "$repo_dir/examples/$showcase_app/test/runtime_check.rb"
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
