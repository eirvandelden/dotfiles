#!/usr/bin/env bash
# install/tasks/22_install_apt_packages.sh
#
# APT (Debian-based) package install task script.
#
# Purpose:
# - Install Debian packages from `packages.conf` (APT array) using apt/apt-get.
# - Useful for debugging Debian installs without running the full installer.
# - Uses the same underlying functions as `install.sh` (from `install/utils.sh`).
#
# Usage:
#   ./install/tasks/22_install_apt_packages.sh
#
# Notes:
# - This task (re-)loads `packages.conf`.
# - It detects the OS and will no-op on non-Debian systems.
# - Assumes `install/utils.sh` provides:
#   - log, warn, die, require_cmd, need_cmd
#   - determine_os
#   - apt_is_installed
#
# Idempotency:
# - Skips packages already installed according to `dpkg -s`.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_common.sh"

main() {
  task_bootstrap

  determine_os
  log "os: detected: ${OS:-Unknown}${OS_PRETTY:+ (${OS_PRETTY})}"

  if [[ "${OS:-Unknown}" != "Debian" ]]; then
    log "apt: skipping (OS is not Debian-based)."
    return 0
  fi

  if (( ${#APT[@]} == 0 )); then
    log "apt: no packages configured (APT is empty)."
    return 0
  fi

  require_cmd sudo

  if need_cmd apt-get; then
    sudo apt-get update -y

    local pkg
    for pkg in "${APT[@]}"; do
      [[ -z "$pkg" ]] && continue

      if apt_is_installed "$pkg"; then
        log "apt: already installed: $pkg"
      else
        log "apt: installing: $pkg"
        sudo apt-get install -y --no-install-recommends "$pkg"
      fi
    done
  elif need_cmd apt; then
    sudo apt update -y

    local pkg
    for pkg in "${APT[@]}"; do
      [[ -z "$pkg" ]] && continue

      if apt_is_installed "$pkg"; then
        log "apt: already installed: $pkg"
      else
        log "apt: installing: $pkg"
        sudo apt install -y "$pkg"
      fi
    done
  else
    die "apt/apt-get not found; cannot install APT packages."
  fi

  log "apt: package install complete."
}

main "$@"
