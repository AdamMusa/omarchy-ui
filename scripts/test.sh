#!/bin/bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd -- "$repo_dir"

ruby -Ilib test/omarchy_ui_test.rb
ruby -Ilib test/cli_test.rb
ruby -Ilib test/command_test.rb
ruby test/qml_contract_test.rb
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
  while IFS= read -r -d '' qml_file; do
    qmlformat "$qml_file" >/dev/null
  done < <(find . -path './.git' -prune -o -name '*.qml' -type f -print0)
fi

if command -v qmllint >/dev/null 2>&1 && [ -d "$HOME/.local/share/omarchy/shell" ]; then
  quick3d_available=false
  quick3d_paths=(/usr/lib/qt6/qml)
  if [[ -n ${QML_IMPORT_PATH:-} ]]; then
    IFS=: read -r -a configured_qml_paths <<<"$QML_IMPORT_PATH"
    quick3d_paths+=("${configured_qml_paths[@]}")
  fi
  for qml_path in "${quick3d_paths[@]}"; do
    if [[ -f $qml_path/QtQuick3D/qmldir ]]; then
      quick3d_available=true
      break
    fi
  done
  while IFS= read -r -d '' qml_file; do
    if [[ $qml_file == */Support/ModelView3dScene.qml && $quick3d_available == false ]]; then
      echo "Skipping optional Qt Quick 3D lint (install qt6-quick3d to enable): $qml_file"
      continue
    fi
    qmllint -I "$HOME/.local/share/omarchy/shell" "$qml_file"
  done < <(find . -path './.git' -prune -o -name '*.qml' -type f -print0)
fi

if [ -x /usr/lib/qt6/bin/qsb ]; then
  while IFS= read -r -d '' shader_file; do
    /usr/lib/qt6/bin/qsb --silent --dump "$shader_file" >/dev/null
  done < <(find Components examples -name '*.qsb' -type f -print0)
fi

git diff --check
echo "Omarchy UI framework tests passed."
