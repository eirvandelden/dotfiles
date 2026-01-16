#!/usr/bin/env bash
# install/tasks/31_install_default_node.sh
#
# Default Node runtime install task script.
#
# Purpose:
# - Install the default Node runtime defined by `node/.node-version`.
# - Useful for running this step manually while debugging on SteamOS/Debian/macOS.
# - Reuses the same underlying installer functions as `install.sh` (from `install/utils.sh`).
#

# Usage:
#   ./install/tasks/31_install_default_node.sh
#
# Notes:
# - This task (re-)loads `packages.conf` via `00_common.sh` to keep tasks consistent.
# - Requires `node-build` to be available on PATH (typically installed via the Brew step).
# - This task does not install global npm packages. Use the dedicated npm task for that.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_common.sh"

main() {
  task_bootstrap

  determine_os
  log "os: detected: ${OS:-Unknown}${OS_PRETTY:+ (${OS_PRETTY})}"

  local root version_file
  root="$(task__repo_root)"
  version_file="${root}/node/.node-version"

  [[ -f "$version_file" ]] || die "node version file not found: ${version_file}"

  log "node: installing default runtime (from node/.node-version)…"
  install_node_runtime "node/.node-version"

  log "node: default runtime install complete."
}

main "$@"
