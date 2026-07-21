#!/usr/bin/env bash
# install/tasks/42_install_uv_tools.sh
#
# uv tools install task script.
#
# Purpose:
# - Install the default uv tools defined in `packages.conf` (UV_TOOLS array)
# - Installs into the *current uv* (whatever `uv` is on PATH)
# - Useful for debugging or re-running uv installs without running the full installer
#
# Usage:
#   ./install/tasks/42_install_uv_tools.sh
#
# Notes:
# - This task (re-)loads `install/utils.sh` and `packages.conf` via `00_common.sh`.
# - It does NOT install uv itself; run `20_install_brew_packages.sh` first if needed.
# - It installs tools with --python 3.13 to ensure consistent Python version.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_common.sh"

main() {
  task_bootstrap

  determine_os
  log "os: detected: ${OS:-Unknown}${OS_PRETTY:+ (${OS_PRETTY})}"

  if (( ${#UV_TOOLS[@]} == 0 )); then
    log "uv: no default tools configured (UV_TOOLS is empty)."
    return 0
  fi

  require_cmd uv

  local uv_desc
  uv_desc="$(uv --version 2>/dev/null || echo "unknown uv")"

  log "uv: installing default tools (${uv_desc})…"

  local tool
  for tool in "${UV_TOOLS[@]}"; do
    [[ -z "$tool" ]] && continue
    log "uv: installing: $tool"
    uv tool install --python 3.13 "$tool"
  done

  log "uv: default tools install complete."
}

main "$@"
