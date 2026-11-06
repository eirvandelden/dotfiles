#!/usr/bin/env bash
# install/tasks/52_install_herdr_plugins.sh
#
# herdr plugin install task script.
#
# Purpose:
# - Install and enable the herdr plugins listed in `packages.conf` (HERDR_PLUGINS).
# - This is a standalone task you can run while debugging a specific platform.
# - Uses the same underlying functions as `install.sh` (from `install/utils.sh`).
#
# Usage:
#   ./install/tasks/52_install_herdr_plugins.sh
#
# Notes:
# - Requires `herdr`, `go` and `jq` to already be installed (see 20_install_brew_packages.sh).
# - Runs after stow, so the stowed plugin config is in place before a plugin first runs.
# - Idempotent: an enabled plugin is left alone, a disabled one is enabled.
# - This task (re-)loads `packages.conf`.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_common.sh"

main() {
  task_bootstrap

  require_cmd herdr go jq

  log "herdr: installing plugins…"
  install_herdr_plugins "${HERDR_PLUGINS[@]}"

  log "herdr: plugin install complete."
}

main "$@"
