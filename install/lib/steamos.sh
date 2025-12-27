#!/usr/bin/env bash
# SteamOS / Arch-specific functions for dotfiles installer.
#
# This file is intended to be sourced (not executed).
# It assumes `dotfiles/install/lib/generic.sh` has already been sourced.
#
# Responsibilities:
# - SteamOS readonly handling
# - System update
# - Prereqs for building/installing packages
# - Native fallback installs:
#   - Prefer pacman when possible
#   - Use yay (AUR helper) only when the package is not in repos
#
# Note: The global install policy is "prefer brew, fallback to native".
# The native fallback entrypoint is `install_native_package_steamos <pkg>`.

set -euo pipefail

###############################################################################
# SteamOS readonly helpers
###############################################################################

is_steamos_readonly_supported() {
  need_cmd steamos-readonly
}

steamos_readonly_disable() {
  if is_steamos_readonly_supported; then
    sudo steamos-readonly disable
  fi
}

steamos_readonly_enable() {
  if is_steamos_readonly_supported; then
    sudo steamos-readonly enable
  fi
}

with_steamos_readonly_disabled() {
  if ! is_steamos_readonly_supported; then
    "$@"
    return
  fi

  steamos_readonly_disable
  local _status=0
  "$@" || _status=$?
  steamos_readonly_enable
  return "$_status"
}

###############################################################################
# System update + prereqs
###############################################################################

update_steamos() {
  log "Updating SteamOS system…"
  if need_cmd steamos-update; then
    sudo steamos-update
  else
    warn "steamos-update not found; skipping OS update."
  fi
}

update_steamos_packages() {
  log "Updating system installed packages…"
  check_required_tooling pacman
  sudo pacman -Syu --noconfirm
}

ensure_pacman_keyring_initialized() {
  if ! need_cmd pacman-key; then
    warn "pacman-key not found; skipping keyring initialization."
    return 0
  fi

  log "Initializing pacman keyring…"
  sudo pacman-key --init

  # Populate what exists; ignore failures if a keyring isn't available on a given image.
  sudo pacman-key --populate archlinux || true
  sudo pacman-key --populate holo || true
}

ensure_steamos_prereqs() {
  log "Ensuring SteamOS/Arch prerequisites…"
  check_required_tooling pacman sudo

  # Disable SteamOS readonly during installs, but always re-enable it afterwards.
  with_steamos_readonly_disabled bash -c '
    set -euo pipefail

    # Initialize keyring if needed
    if command -v ensure_pacman_keyring_initialized >/dev/null 2>&1; then
      ensure_pacman_keyring_initialized
    fi

    echo "Installing base-devel and prerequisites…"
    sudo pacman -S --needed --noconfirm base-devel procps-ng curl file git
  '
}

###############################################################################
# yay (AUR) helpers
###############################################################################

ensure_yay_installed() {
  if need_cmd yay; then
    return 0
  fi

  check_required_tooling pacman git makepkg

  log "Installing yay (AUR helper)…"
  local tmpdir
  tmpdir="$(mktemp -d)"
  (
    set -euo pipefail
    cd "$tmpdir"
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
  )
  rm -rf "$tmpdir"
}

###############################################################################
# Native fallback entrypoint (used when brew cannot install)
###############################################################################

install_native_package_steamos() {
  local pkg="$1"

  check_required_tooling pacman

  # On SteamOS, installing via pacman may require readonly to be disabled.
  with_steamos_readonly_disabled bash -c "
    set -euo pipefail

    # If pacman already has it, install via pacman.
    if pacman -Si \"${pkg}\" >/dev/null 2>&1; then
      echo \"Installing native package via pacman: ${pkg}\"
      sudo pacman -S --needed --noconfirm \"${pkg}\"
      exit 0
    fi

    # Otherwise fall back to AUR via yay.
    echo \"Package not found in pacman repos: ${pkg} — trying yay (AUR)…\"
    if command -v ensure_yay_installed >/dev/null 2>&1; then
      ensure_yay_installed
    else
      echo \"error: ensure_yay_installed not available\" >&2
      exit 1
    fi

    yay -S --needed --noconfirm \"${pkg}\"
  "
}
