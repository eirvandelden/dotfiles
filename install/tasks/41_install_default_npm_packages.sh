#!/usr/bin/env bash
# install/tasks/41_install_default_npm_packages.sh
#
# Default global npm packages install task script.
#
# Purpose:
# - Install the default global npm packages defined in `packages.conf` (NPM_PACKAGES array)
# - Installs into the *current Node/npm* (whatever `npm` is on PATH)
# - Useful for debugging or re-running npm installs without running the full installer
#
# Usage:
#   ./install/tasks/41_install_default_npm_packages.sh
#
# Notes:
# - This task (re-)loads `install/utils.sh` and `packages.conf` via `00_common.sh`.
# - It does NOT install Node itself; run `31_install_default_node.sh` first if needed.
# - It does NOT switch Node versions. Ensure your shell is already using the Node you want.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_common.sh"

main() {
  task_bootstrap

  determine_os
  log "os: detected: ${OS:-Unknown}${OS_PRETTY:+ (${OS_PRETTY})}"

  if (( ${#NPM_PACKAGES[@]} == 0 )); then
    log "npm: no default packages configured (NPM_PACKAGES is empty)."
    return 0
  fi

  require_cmd npm

  local node_desc npm_desc
  node_desc="$(node --version 2>/dev/null || echo "unknown node")"
  npm_desc="$(npm --version 2>/dev/null || echo "unknown npm")"

  log "npm: installing default global packages (node: ${node_desc}, npm: ${npm_desc})…"
  install_npm_packages "${NPM_PACKAGES[@]}"
  log "npm: default packages install complete."
}

main "$@"
