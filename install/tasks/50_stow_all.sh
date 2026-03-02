#!/usr/bin/env bash
# install/tasks/50_stow_all.sh
#
# Stow all configured dotfiles packages.
#
# Purpose:
# - Apply all stow packages listed in `packages.conf` (STOW array).
# - Useful for running just the stow step manually while debugging installs.
# - Reuses the same underlying stow function as the main installer (`stow_configure`).
#
# Usage:
#   ./install/tasks/50_stow_all.sh
#
# Notes:
# - This task (re-)loads `install/utils.sh` and `packages.conf` via `00_common.sh`.
# - It assumes the repo root contains the stow package directories (e.g. `./zsh`, `./git`, etc.).
# - Idempotent via `stow --restow`.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_common.sh"

main() {
  task_bootstrap

  determine_os
  log "os: detected: ${OS:-Unknown}${OS_PRETTY:+ (${OS_PRETTY})}"

  if (( ${#STOW[@]} == 0 )); then
    log "stow: no packages configured (STOW is empty)."
    return 0
  fi

  local root
  root="$(task__repo_root)"

  log "stow: applying configured packages…"
  stow_configure "$root" "${STOW[@]}"

  log "stow: all configured packages applied."

  local work_conf="${HOME}/Developer/dotfiles-work/packages.conf"
  if [[ -f "$work_conf" ]]; then
    log "stow: loading work packages from ${work_conf}…"
    # shellcheck disable=SC1090
    source "$work_conf"

    if declare -p STOW_WORK >/dev/null 2>&1 && (( ${#STOW_WORK[@]} > 0 )); then
      log "stow: applying work packages…"
      stow_configure "${HOME}/Developer/dotfiles-work" "${STOW_WORK[@]}"
      log "stow: work packages applied."
    else
      log "stow: no work packages configured (STOW_WORK is empty or undefined)."
    fi
  else
    log "stow: dotfiles-work not found, skipping work packages."
  fi
}

main "$@"
