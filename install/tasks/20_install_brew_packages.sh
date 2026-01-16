#!/usr/bin/env bash
# install/tasks/20_install_brew_packages.sh
#
# Homebrew package install task script.
#
# Purpose:
# - Install Homebrew (if missing) and then install Brew packages from `packages.conf`.
# - This is a standalone task you can run while debugging a specific platform.
# - Uses the same underlying functions as `install.sh` (from `install/utils.sh`).
#
# Usage:
#   ./install/tasks/20_install_brew_packages.sh
#
# What it installs (from packages.conf):
# - BREW (all systems)
# - plus one of:
#   - BREW_MACOS (macOS)
#   - BREW_LINUX (Linux)
#
# Notes:
# - This task (re-)loads `packages.conf`.
# - It does not install AUR/APT/Flatpak packages.
# - It does not install Ruby/Node runtimes or language packages.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_common.sh"

main() {
  task_bootstrap

  determine_os
  log "os: detected: ${OS:-Unknown}${OS_PRETTY:+ (${OS_PRETTY})}"

  # Ensure Homebrew exists and is available in this shell.
  install_homebrew_if_missing
  require_cmd brew

  log "brew: installing packages (all systems)…"
  install_brew_packages "${BREW[@]}"

  if [[ "${OS:-Unknown}" == "macOS" ]]; then
    log "brew: installing packages (macOS)…"
    install_brew_packages "${BREW_MACOS[@]}"
  else
    log "brew: installing packages (Linux)…"
    install_brew_packages "${BREW_LINUX[@]}"
  fi

  log "brew: package install complete."
}

main "$@"
