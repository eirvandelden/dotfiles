#!/usr/bin/env bash
# macOS-specific functions for dotfiles installer.
#
# This file is intended to be sourced (not executed).
# It assumes `dotfiles/install/lib/generic.sh` has already been sourced.

set -euo pipefail

update_macos() {
  log "Updating macOS system…"
  check_required_tooling softwareupdate
  softwareupdate --install --all
}

ensure_macos_prereqs() {
  log "Ensuring Xcode Command Line Tools are installed…"

  check_required_tooling xcode-select

  # If already installed, xcode-select -p succeeds.
  if xcode-select -p >/dev/null 2>&1; then
    return 0
  fi

  # This triggers a GUI prompt; acceptable for interactive runs.
  xcode-select --install || true
}

install_native_package_macos() {
  # macOS "native" fallback is intentionally not implemented.
  # For this project, Homebrew is the package manager on macOS.
  local pkg="$1"
  abort "No native installer fallback for macOS (package: ${pkg}). Use Homebrew or add a custom install step."
}
