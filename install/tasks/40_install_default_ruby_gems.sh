#!/usr/bin/env bash
# install/tasks/40_install_default_ruby_gems.sh
#
# Default Ruby gems install task script.
#
# Purpose:
# - Install the default Ruby gems defined in `packages.conf` (RUBY_GEMS array)
# - Installs into the *current Ruby* (whatever `gem` is on PATH)
# - Useful for debugging or re-running gem installs without running the full installer
#
# Usage:
#   ./install/tasks/40_install_default_ruby_gems.sh
#
# Notes:
# - This task (re-)loads `install/utils.sh` and `packages.conf` via `00_common.sh`.
# - It does NOT install Ruby itself; run `30_install_default_ruby.sh` first if needed.
# - It does NOT switch Rubies. Ensure your shell is already using the Ruby you want.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_common.sh"

main() {
  task_bootstrap

  determine_os
  log "os: detected: ${OS:-Unknown}${OS_PRETTY:+ (${OS_PRETTY})}"

  if (( ${#RUBY_GEMS[@]} == 0 )); then
    log "gem: no default gems configured (RUBY_GEMS is empty)."
    return 0
  fi

  require_cmd gem

  local ruby_desc
  ruby_desc="$(ruby -v 2>/dev/null || echo "unknown ruby")"
  log "gem: installing default gems into current Ruby (${ruby_desc})…"

  install_ruby_gems "${RUBY_GEMS[@]}"

  log "gem: default gems install complete."
}

main "$@"
