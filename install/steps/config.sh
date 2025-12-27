#!/usr/bin/env bash
# Configuration restore steps (dotfiles) for the installer.
#
# This file is intended to be sourced (not executed).
#
# Goal:
# - Restore dotfiles into $HOME using GNU Stow.
#
# Design:
# - The list of packages to stow is driven by stow.conf (CONFIG_PACKAGES array).
# - The actual stow implementation lives in a separate script (install/steps/stow.sh).
#   This file orchestrates loading config and calling into that implementation.
#
# Expected usage from install.sh:
#   source install/steps/config.sh
#   restore_all_configs

set -euo pipefail

: "${DOTFILES_ROOT:=$(pwd)}"

# Where your stow "packages" live (each subdirectory is a stow package)
CONFIG_STOW_DIR="${CONFIG_STOW_DIR:-${DOTFILES_ROOT}/home}"

# Optional file that defines CONFIG_PACKAGES=(...)
STOW_CONF="${STOW_CONF:-${DOTFILES_ROOT}/stow.conf}"

# Load stow implementation (kept separate from orchestration).
# shellcheck disable=SC1091
source "${DOTFILES_ROOT}/install/steps/stow.sh"

load_stow_conf_if_present() {
  if [[ -f "$STOW_CONF" ]]; then
    # shellcheck disable=SC1090
    source "$STOW_CONF"
  fi
}

restore_all_configs() {
  load_stow_conf_if_present

  # CONFIG_PACKAGES is expected to be defined in stow.conf as a bash array.
  if ! declare -p CONFIG_PACKAGES >/dev/null 2>&1; then
    abort "CONFIG_PACKAGES is not defined. Create stow.conf with CONFIG_PACKAGES=(...)"
  fi

  stow_restore_packages "${CONFIG_STOW_DIR}" "${CONFIG_PACKAGES[@]}"
}
