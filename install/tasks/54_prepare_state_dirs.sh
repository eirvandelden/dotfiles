#!/usr/bin/env bash
# install/tasks/54_prepare_state_dirs.sh
#
# State directories task script.
#
# Purpose:
# - Create the XDG state directories that ssh, irb and mysql write to. ssh cannot record a host in a
#   known_hosts file whose directory is missing, and the other two lose their history silently.
# - Copy the old history files into them, so the history survives the move.
#
# Usage:
#   ./install/tasks/54_prepare_state_dirs.sh
#
# Notes:
# - The directories are private (mode 700): a history file can hold secrets typed on a command line.
# - ssh, irb and mysql read their paths from ssh/.ssh/config, ruby/.irbrc and zsh environment.zsh.
# - known_hosts is not copied here: it can hold hashed host names Etienne reviews by hand.
#
# Idempotency:
# - Designed to be safe to run multiple times; a copy happens only when the target is absent.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_common.sh"

readonly STATE_HOME="${HOME}/.local/state"

# Copies an old history file to its new place, unless the new one exists or the old one is missing.
copy_history() {
  local old="$1" new="$2"

  if [[ ! -f "$old" ]]; then
    log "state: ${old} not found, skipping."
  elif [[ -e "$new" ]]; then
    log "state: ${new} exists, skipping."
  else
    cp "$old" "$new"
    log "state: copied ${old} to ${new}."
  fi
}

main() {
  task_bootstrap

  local name
  for name in ssh irb mysql; do
    mkdir -p "${STATE_HOME}/${name}"
    chmod 700 "${STATE_HOME}/${name}"
  done

  copy_history "${HOME}/.irb_history" "${STATE_HOME}/irb/history"
  copy_history "${HOME}/.mysql_history" "${STATE_HOME}/mysql/history"
}

main "$@"
