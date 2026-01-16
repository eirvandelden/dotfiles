#!/usr/bin/env bash
# install/tasks/10_update_os.sh
#
# Per-OS update task script.
#
# Purpose:
# - Run the OS update step(s) manually, without running the full installer.
# - Keep the logic readable and consistent with the main installer strategy.
#
# Usage:
#   ./install/tasks/10_update_os.sh
#
# Notes:
# - This task loads `install/utils.sh` and `packages.conf` via `00_common.sh`.
# - It detects the OS and runs the appropriate update routine.
# - This task is intentionally focused on OS updating only (no package installation).
#
# Supported OS:
# - macOS
# - SteamOS (Arch)
# - Debian-based Linux

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_common.sh"

update_os__macos() {
  log "os: update: macOS (softwareupdate)…"

  require_cmd sudo softwareupdate

  # Refresh catalog and install all updates. Reboot may be required for some updates.
  sudo softwareupdate --install --all || warn "softwareupdate returned non-zero; some updates may require manual intervention."
}

update_os__steamos() {
  log "os: update: SteamOS/Arch (pacman)…"

  require_cmd sudo pacman

  # SteamOS can be read-only. Reuse the existing helper from utils if available.
  # `with_steamos_readonly_disabled` is provided by install/utils.sh.
  with_steamos_readonly_disabled bash -c '
    set -euo pipefail
    sudo pacman -Syu --noconfirm
  '
}

update_os__debian() {
  log "os: update: Debian-based (apt/apt-get)…"

  require_cmd sudo

  if need_cmd apt-get; then
    sudo apt-get update -y
    # Use dist-upgrade to handle dependency changes; keep it non-interactive.
    sudo DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y
  elif need_cmd apt; then
    sudo apt update -y
    sudo DEBIAN_FRONTEND=noninteractive apt full-upgrade -y
  else
    die "apt/apt-get not found; cannot update Debian-based system."
  fi
}

main() {
  task_bootstrap
  determine_os

  log "os: detected: ${OS:-Unknown}${OS_PRETTY:+ (${OS_PRETTY})}"

  case "${OS:-Unknown}" in
    macOS)
      update_os__macos
      ;;
    SteamOS)
      update_os__steamos
      ;;
    Debian)
      update_os__debian
      ;;
    *)
      die "Unsupported OS for update task: ${OS:-Unknown}"
      ;;
  esac

  log "os: update complete."
}

main "$@"
