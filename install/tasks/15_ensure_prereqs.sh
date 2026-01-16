#!/usr/bin/env bash
# install/tasks/15_ensure_prereqs.sh
#
# Prerequisites task script (OS dependent).
#
# Purpose:
# - Run just the OS prerequisite installation step(s) manually.
# - Useful while debugging installs on SteamOS/Debian without running the full installer.
# - Reuses the same underlying functions as `install.sh` (from `install/utils.sh`).
#
# Usage:
#   ./install/tasks/15_ensure_prereqs.sh
#
# Notes:
# - This task (re-)loads `install/utils.sh` and `packages.conf` via `00_common.sh`.
# - Prereqs are OS-dependent and are installed using the appropriate native mechanism:
#   - macOS: Xcode Command Line Tools prompt (if missing)
#   - SteamOS/Arch: pacman (with steamos-readonly disable/enable if available)
#   - Debian-based: apt/apt-get
#
# Idempotency:
# - Designed to be safe to run multiple times.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_common.sh"

main() {
  task_bootstrap

  determine_os
  log "os: detected: ${OS:-Unknown}${OS_PRETTY:+ (${OS_PRETTY})}"

  log "prereqs: ensuring prerequisites…"
  ensure_prereqs
  log "prereqs: complete."
}

main "$@"
