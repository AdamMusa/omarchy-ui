#!/bin/bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd -- "$repo_dir"

ruby -Ilib test/omarchy_ui_test.rb
ruby -Ilib test/cli_test.rb
ruby -Ilib test/command_test.rb
ruby test/manifest_test.rb
ruby test/qml_contract_test.rb
ruby -c lib/omarchy_ui.rb
ruby -c main.rb
ruby -e 'abort "invalid gemspec" unless Gem::Specification.load("omarchy-ui.gemspec")'

if command -v qmllint >/dev/null 2>&1 && [ -d "$HOME/.local/share/omarchy/shell" ]; then
  qmllint -I "$HOME/.local/share/omarchy/shell" ControlNode.qml Service.qml Panel.qml BarWidget.qml Components/Sparkline.qml
fi

if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin validate "$repo_dir"
else
  echo "Omarchy CLI not present; local schema-equivalent manifest tests passed."
fi

git diff --check 2>/dev/null || true
echo "Omarchy UI framework tests passed."
