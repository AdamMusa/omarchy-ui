#!/bin/bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
exec "$repo_dir/bin/omarchy_ui" push "$repo_dir" "$@"
