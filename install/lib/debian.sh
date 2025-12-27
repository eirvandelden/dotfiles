#!/usr/bin/env bash
# Debian-specific functions for dotfiles installer.
#
# This file is intended to be sourced (not executed).
# It assumes `dotfiles/install/lib/generic.sh` has already been sourced.
#
# Responsibilities:
# - System update (safe defaults)
# - Basic prerequisites for builds and fetching scripts
# - Native fallback installs using apt when Homebrew cannot install a package
#
# Policy:
# - Prefer Homebrew for everything (handled by generic install policy)
# - Only use apt as a fallback when brew cannot install a package

set -euo pipefail

debian_is_apt_available() {
  need_cmd apt-get || need_cmd apt
}

debian_apt_update() {
  if need_cmd apt-get; then
    sudo apt-get update -y
  else
    sudo apt update -y
  fi
}

debian_apt_install() {
  # Install packages passed as args using apt-get if available (more script-friendly).
  if need_cmd apt-get; then
    sudo apt-get install -y --no-install-recommends "$@"
  else
    sudo apt install -y "$@"
  fi
}

update_debian() {
  log "Updating Debian-based system…"

  check_required_tooling sudo
  debian_is_apt_available || abort "apt/apt-get not found; cannot update Debian-based system."

  debian_apt_update

  # Keep this conservative: upgrade only, no distro-release changes.
  if need_cmd apt-get; then
    sudo apt-get upgrade -y
  else
    sudo apt upgrade -y
  fi
}

ensure_debian_prereqs() {
  log "Ensuring Debian-based prerequisites…"

  check_required_tooling sudo
  debian_is_apt_available || abort "apt/apt-get not found; cannot install Debian prerequisites."

  debian_apt_update

  # Minimal base required by this repo:
  # - curl: Homebrew install script fetch
  # - git: cloning AUR helper alternatives / general tooling
  # - ca-certificates: TLS works reliably
  # - build-essential, file, procps: common build + inspection tools
  # - pkg-config: commonly needed to build native deps for ruby/node/etc.
  debian_apt_install \
    ca-certificates \
    curl \
    git \
    build-essential \
    file \
    procps \
    pkg-config

  # Some distros don't ship these by default; harmless if already installed.
  # Helps with add-ons, keyrings, and general scripting.
  if ! need_cmd gpg; then
    debian_apt_install gnupg
  fi
}

install_native_package_debian() {
  # Native fallback entrypoint used by `install_via_brew_or_native` when brew can't install.
  #
  # This does NOT attempt to be clever about package name mismatches.
  # If a name differs between brew and apt, put it in PACMAN_ONLY/BREW_ONLY style
  # lists (or add mapping logic later).
  local pkg="$1"

  check_required_tooling sudo
  debian_is_apt_available || abort "apt/apt-get not found; cannot install native package '${pkg}'."

  debian_apt_update

  log "Installing native package via apt: ${pkg}"
  # If the package name doesn't exist in apt, this will fail and bubble up.
  debian_apt_install "${pkg}"
}
