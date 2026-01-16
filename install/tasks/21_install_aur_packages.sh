#!/usr/bin/env bash
# install/tasks/21_install_aur_packages.sh
#
# AUR (SteamOS/Arch) package install task script.
#
# Purpose:
# - Install AUR packages from `packages.conf` (AUR array) using `yay`.
# - Useful for debugging SteamOS/Arch installs without running the full installer.
# - Uses the same underlying functions as `install.sh` (from `install/utils.sh`).
#
# Usage:
#   ./install/tasks/21_install_aur_packages.sh
#
# Notes:
# - This task (re-)loads `packages.conf`.
# - This task detects the OS and will no-op on non-SteamOS systems.
# - SteamOS can be read-only; we rely on `with_steamos_readonly_disabled` from utils.
# - Assumes `install/utils.sh` provides:
#   - log, warn, die, require_cmd, need_cmd
#   - determine_os
#   - ensure_yay_installed
#   - aur_is_installed
#   - with_steamos_readonly_disabled
#
# Idempotency:
# - Skips packages already installed according to `yay -Qi`.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_common.sh"

main() {
  task_bootstrap

  determine_os
  log "os: detected: ${OS:-Unknown}${OS_PRETTY:+ (${OS_PRETTY})}"

  if [[ "${OS:-Unknown}" != "SteamOS" ]]; then
    log "aur: skipping (OS is not SteamOS/Arch)."
    return 0
  fi

  if (( ${#AUR[@]} == 0 )); then
    log "aur: no packages configured (AUR is empty)."
    return 0
  fi

  ensure_yay_installed
  require_cmd yay

  local pkg
  for pkg in "${AUR[@]}"; do
    [[ -z "$pkg" ]] && continue

    if aur_is_installed "$pkg"; then
      log "aur: already installed: $pkg"
      continue
    fi

    log "aur: installing: $pkg"
    with_steamos_readonly_disabled yay -S --needed --noconfirm "$pkg"
  done

  log "aur: package install complete."
}

main "$@"
