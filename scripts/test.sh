#!/bin/bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd -- "$repo_dir"

ruby -Ilib test/omarchy_ui_test.rb
ruby -Ilib test/cli_test.rb
ruby -Ilib test/command_test.rb
ruby test/qml_contract_test.rb
ruby -c lib/omarchy_ui.rb
ruby -e 'abort "invalid gemspec" unless Gem::Specification.load("omarchy-ui.gemspec")'

if command -v qmllint >/dev/null 2>&1 && [ -d "$HOME/.local/share/omarchy/shell" ]; then
  for qml_file in ControlNode.qml Service.qml Panel.qml BarWidget.qml App.qml Components/Builtins/*.qml; do
    qmllint -I "$HOME/.local/share/omarchy/shell" "$qml_file"
  done
fi

git diff --check 2>/dev/null || true
echo "Omarchy UI framework tests passed."
