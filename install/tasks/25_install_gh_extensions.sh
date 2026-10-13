#!/usr/bin/env bash
# install/tasks/25_install_gh_extensions.sh
#
# GitHub CLI extension install task script.
#
# Purpose:
# - Install `gh` CLI extensions listed in `packages.conf` (GH_EXTENSIONS).
# - This is a standalone task you can run while debugging a specific platform.
# - Uses the same underlying functions as `install.sh` (from `install/utils.sh`).
#
# Usage:
#   ./install/tasks/25_install_gh_extensions.sh
#
# Notes:
# - Requires `gh` to already be installed (see 20_install_brew_packages.sh).
# - This task (re-)loads `packages.conf`.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_common.sh"

main() {
  task_bootstrap

  require_cmd gh

  log "gh: installing extensions…"
  install_gh_extensions "${GH_EXTENSIONS[@]}"

  log "gh: extension install complete."
}

main "$@"
