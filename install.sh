#!/usr/bin/env bash
# Entrypoint for Etienne's dotfiles installer.
#
# Supported OS targets:
# - macOS
# - SteamOS (Arch-based)
# - Debian-based Linux (Debian/Ubuntu/etc.)
#
# Design:
# - Keep OS-specific logic in install/lib/*.sh
# - Keep install steps in install/steps/*.sh
# - Prefer Homebrew everywhere; fall back to native package managers only when
#   Homebrew cannot install a given package.

set -euo pipefail

###############################################################################
# UI
###############################################################################

print_logo() {
  cat << "EOF"
Etienne's dev setup
EOF
}

clear
print_logo

###############################################################################
# Resolve repo root + load libs
###############################################################################

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_ROOT

# Load generic utilities first (logging, abort, OS detection, brew helpers, policy helpers).
# shellcheck disable=SC1091
source "${DOTFILES_ROOT}/install/lib/generic.sh"

# Then load OS-specific libraries (they assume generic.sh was sourced).
# shellcheck disable=SC1091
source "${DOTFILES_ROOT}/install/lib/macos.sh"
# shellcheck disable=SC1091
source "${DOTFILES_ROOT}/install/lib/steamos.sh"
# shellcheck disable=SC1091
source "${DOTFILES_ROOT}/install/lib/debian.sh"

# Load steps
# shellcheck disable=SC1091
source "${DOTFILES_ROOT}/install/steps/packages.sh"
# shellcheck disable=SC1091
source "${DOTFILES_ROOT}/install/steps/runtimes.sh"
# shellcheck disable=SC1091
source "${DOTFILES_ROOT}/install/steps/config.sh"

###############################################################################
# Load configuration
###############################################################################

PACKAGES_CONF="${PACKAGES_CONF:-${DOTFILES_ROOT}/packages.conf}"
STOW_CONF="${STOW_CONF:-${DOTFILES_ROOT}/stow.conf}"

[[ -f "$PACKAGES_CONF" ]] || abort "packages.conf not found: ${PACKAGES_CONF}"
# shellcheck disable=SC1090
source "$PACKAGES_CONF"

# stow.conf is optional; config step can also auto-discover packages
if [[ -f "$STOW_CONF" ]]; then
  # shellcheck disable=SC1090
  source "$STOW_CONF"
fi

###############################################################################
# OS detection + updates + prereqs
###############################################################################

determine_os

log "Detected OS: ${OS:-Unknown}${OS_PRETTY:+ (${OS_PRETTY})}"

case "${OS:-Unknown}" in
  macOS)
    update_macos
    ensure_macos_prereqs
    ;;
  SteamOS)
    update_steamos
    update_steamos_packages
    ensure_steamos_prereqs
    ;;
  Debian)
    update_debian
    ensure_debian_prereqs
    ;;
  *)
    abort "Unsupported OS: ${OS:-Unknown}"
    ;;
esac

###############################################################################
# Homebrew (system-agnostic manager)
###############################################################################
# Per project policy, brew is the default package manager everywhere.
# Brew itself should be installed previously (or you can extend generic.sh to bootstrap it),
# but we always need to make it available in this shell.
setup_brew_shellenv

###############################################################################
# Package installation
###############################################################################
# Package installation is driven by generated files in brewfiles/ (overwritten by save.sh).
# This supports:
# - formulae everywhere
# - casks only on macOS
# - flatpaks only on non-macOS (when available)
install_all_packages_from_files

###############################################################################
# Runtimes
###############################################################################
# Ruby/Node versions are controlled by:
# - ruby/.ruby-version
# - node/.node-version
install_all_runtimes

###############################################################################
# Config restore (stow)
###############################################################################
# Uses stow.conf if present (CONFIG_PACKAGES array), otherwise auto-discovers.
restore_all_configs

log "Setup complete! You may want to reboot your system."
