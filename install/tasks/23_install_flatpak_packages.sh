#!/usr/bin/env bash
# install/tasks/23_install_flatpak_packages.sh
#
# Flatpak package install task script.
#
# Purpose:
# - Install Flatpak apps from `packages.conf` (FLATPAK array) on Linux systems.
# - Useful for debugging Linux installs (SteamOS/Debian) without running the full installer.
# - Uses the same underlying functions as `install.sh` (from `install/utils.sh`).
#
# Usage:
#   ./install/tasks/23_install_flatpak_packages.sh
#
# Notes:
# - This task (re-)loads `packages.conf`.
# - It detects the OS and will no-op on macOS.
# - If `flatpak` is missing, it will warn and exit successfully (consistent with installer behaviour).
# - Installs as the current user (`--user`) and ensures the `flathub` remote exists.
#
# Idempotency:
# - Skips apps already installed according to `flatpak info --user <app-id>`.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_common.sh"

main() {
  task_bootstrap

  determine_os
  log "os: detected: ${OS:-Unknown}${OS_PRETTY:+ (${OS_PRETTY})}"

  if [[ "${OS:-Unknown}" == "macOS" ]]; then
    log "flatpak: skipping (OS is macOS)."
    return 0
  fi

  if (( ${#FLATPAK[@]} == 0 )); then
    log "flatpak: no packages configured (FLATPAK is empty)."
    return 0
  fi

  if ! need_cmd flatpak; then
    warn "flatpak not found; skipping FLATPAK packages."
    return 0
  fi

  ensure_flathub_remote

  local app_id
  for app_id in "${FLATPAK[@]}"; do
    [[ -z "$app_id" ]] && continue

    if flatpak_is_installed "$app_id"; then
      log "flatpak: already installed: $app_id"
      continue
    fi

    log "flatpak: installing: $app_id"
    flatpak install --user --noninteractive --or-update flathub "$app_id"
  done

  log "flatpak: package install complete."
}

main "$@"
