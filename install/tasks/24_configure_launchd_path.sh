#!/usr/bin/env bash
# install/tasks/24_configure_launchd_path.sh
#
# launchd user domain PATH task script (macOS only).
#
# Purpose:
# - Give services that launchd starts the same Homebrew PATH an interactive shell has.
# - launchd hands its services a bare PATH (/usr/bin:/bin:/usr/sbin:/sbin). Everything
#   started through `brew services` inherits it, and so does anything those services
#   spawn without going through a login shell. Herdr is the case that surfaced this:
#   its plugin panes are spawned straight from the server, so the file viewer could not
#   find glow, delta or bat, and the lazygit plugin could not find lazygit — all four
#   live in /opt/homebrew/bin. The plugins degrade quietly to plain text rather than
#   reporting a broken install, which makes this hard to spot.
#
# Usage:
#   ./install/tasks/24_configure_launchd_path.sh
#
# Notes:
# - `launchctl config user path` is the supported way to change this. macOS scopes the
#   facility to PATH and nothing else, on purpose.
# - Requires sudo, and the change only takes effect after a reboot.
# - A service that sets its own PATH still wins over this value.
# - The rv Ruby and Node paths an interactive shell gets are deliberately left out. They
#   carry a version number, so they go stale on the next runtime bump, and a stale entry
#   here fails silently at boot where nobody is watching.
#
# Idempotency:
# - Designed to be safe to run multiple times; skips when launchd already stores this
#   PATH.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_common.sh"

# Where launchd keeps its user domain configuration. `man launchctl` calls the location an
# implementation detail, so treat this as a read-only peek for the idempotency check and
# never write to it directly.
readonly LAUNCHD_CONFIG_PLIST="/var/db/com.apple.xpc.launchd/config/user.plist"

readonly LAUNCHD_USER_PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# Match on the stored value rather than a key name: the key launchd writes is part of that
# same implementation detail, while the PATH string is what we actually care about.
launchd_path_already_set() {
  [[ -f "$LAUNCHD_CONFIG_PLIST" ]] || return 1

  plutil -p "$LAUNCHD_CONFIG_PLIST" 2>/dev/null | grep -qF "$LAUNCHD_USER_PATH"
}

main() {
  task_bootstrap

  determine_os
  log "os: detected: ${OS:-Unknown}${OS_PRETTY:+ (${OS_PRETTY})}"

  if [[ "${OS:-Unknown}" != "macOS" ]]; then
    log "launchd: not macOS, skipping."
    return 0
  fi

  require_cmd sudo launchctl plutil grep

  if launchd_path_already_set; then
    log "launchd: user domain PATH already set, skipping."
    return 0
  fi

  log "launchd: setting the user domain PATH for background services…"
  sudo launchctl config user path "$LAUNCHD_USER_PATH"
  log "launchd: set. Reboot for it to take effect."
}

main "$@"
