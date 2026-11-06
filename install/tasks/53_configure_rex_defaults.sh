#!/usr/bin/env bash
# install/tasks/53_configure_rex_defaults.sh
#
# Rex app defaults task script (macOS only).
#
# Purpose:
# - Make Rex draw herdr the way Ghostty does. Two Rex app defaults cause the difference:
#   - Workspace.interfaceStyle = useTheme. The default, blendTheme, blends the theme colour with the
#     window material, so herdr's default pane background turns grey-white instead of the theme cream.
#   - Workspace.terminalImproveTextContrast = false. Rex otherwise darkens faint text, such as herdr's
#     sidebar numbers, until it reads at about 4.5:1. Ghostty does not.
#
# Usage:
#   ./install/tasks/53_configure_rex_defaults.sh
#
# Notes:
# - Rex has no config file for these keys, so they stay in the app's defaults domain.
# - A running Rex overwrites its defaults on exit. The step warns and skips while Rex runs; run the
#   installer again after quitting Rex.
#
# Idempotency:
# - Designed to be safe to run multiple times; a key is written only when its value differs.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_common.sh"

readonly REX_DOMAIN="com.superlogical.rex"

# `defaults read` prints a boolean as 0 or 1, so the value to compare with is passed apart from the
# type and value that `defaults write` takes.
set_default() {
  local key="$1" type="$2" value="$3" shown="$4"

  if [[ "$(defaults read "$REX_DOMAIN" "$key" 2>/dev/null || true)" == "$shown" ]]; then
    log "rex: ${key} already ${value}, skipping."
  else
    defaults write "$REX_DOMAIN" "$key" "$type" "$value"
    log "rex: ${key} set to ${value}."
  fi
}

main() {
  task_bootstrap

  determine_os
  log "os: detected: ${OS:-Unknown}${OS_PRETTY:+ (${OS_PRETTY})}"

  if [[ "${OS:-Unknown}" != "macOS" ]]; then
    log "rex: not macOS, skipping."
    return 0
  fi

  if pgrep -x Rex >/dev/null; then
    warn "rex: Rex is running and would overwrite the defaults on exit; quit it and run this step again."
    return 0
  fi

  set_default "Workspace.interfaceStyle" -string useTheme useTheme
  set_default "Workspace.terminalImproveTextContrast" -bool false 0
}

main "$@"
