#!/usr/bin/env bash
# install.sh
#
# Cross-platform dotfiles installer (idempotent).
#
# Supported OS:
# - macOS
# - SteamOS (Arch)
# - Debian-based Linux
#
# Strategy (see agents.md):
# - Prefer Homebrew on all platforms.
# - Use native managers only for explicitly configured lists:
#   - SteamOS/Arch: yay (AUR)
#   - Debian: apt/apt-get
#   - Linux: flatpak (FLATPAK)
# - Safe to run repeatedly.

set -euo pipefail

print_logo() {
  local os="${OS:-Detecting…}"
  local host user shell_name repo ruby_ver node_ver
  host="$(hostname 2>/dev/null || true)"
  user="${USER:-}"
  shell_name="${SHELL:-}"
  repo="$(pwd 2>/dev/null || true)"

  ruby_ver="$(cat ruby/.ruby-version 2>/dev/null || echo "unknown")"
  node_ver="$(cat node/.node-version 2>/dev/null || echo "unknown")"

  cat <<EOF
=========================================
    E T I E N N E ' S   D O T F I L E S
=========================================
 Target OS : ${os}
 Host      : ${host}
 User      : ${user}
 Shell     : ${shell_name}
 Repo      : ${repo}

 Ruby      : ${ruby_ver}
 Node      : ${node_ver}

 Manager   : brew-first
 Fallbacks : yay (arch) | apt (debian) | flatpak (linux)

 Press Ctrl+C to abort at any time.
-----------------------------------------
EOF
}

main() {
  clear
  print_logo

  # Ensure we run relative to repo root, regardless of invocation location.
  local root
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "$root"

  # Load installer utilities
  # shellcheck disable=SC1091
  source install/utils.sh

  # Load configuration (source of truth)
  local packages_conf="packages.conf"
  [[ -f "$packages_conf" ]] || die "packages.conf not found at: ${root}/${packages_conf}"
  # shellcheck disable=SC1091
  source "$packages_conf"

  # Detect OS
  determine_os
  log "Detected OS: ${OS:-Unknown}${OS_PRETTY:+ (${OS_PRETTY})}"

  # Re-render splash with detected OS for a nicer UX
  clear
  print_logo

  # Prerequisites (OS dependent)
  ensure_prereqs

  # Homebrew (install if missing + ensure brew available in this shell)
  install_homebrew_if_missing
  require_cmd brew

  # Packages
  log "Installing Homebrew packages (all systems)…"
  install_brew_packages "${BREW[@]}"

  if [[ "${OS:-Unknown}" == "macOS" ]]; then
    log "Installing Homebrew packages (macOS)…"
    install_brew_packages "${BREW_MACOS[@]}"
  else
    log "Installing Homebrew packages (Linux)…"
    install_brew_packages "${BREW_LINUX[@]}"
  fi

  if [[ "${OS:-Unknown}" == "SteamOS" ]]; then
    log "Installing AUR packages (SteamOS/Arch)…"
    install_aur_packages "${AUR[@]}"
  fi

  if [[ "${OS:-Unknown}" == "Debian" ]]; then
    log "Installing APT packages (Debian-based)…"
    install_apt_packages "${APT[@]}"
  fi

  if [[ "${OS:-Unknown}" != "macOS" ]]; then
    log "Installing Flatpak packages (Linux)…"
    install_flatpak_packages "${FLATPAK[@]}"
  fi

  # Runtimes (versions are controlled by repo files)
  log "Installing Ruby runtime (from ruby/.ruby-version)…"
  install_ruby_runtime "ruby/.ruby-version"

  log "Installing Node runtime (from node/.node-version)…"
  install_node_runtime "node/.node-version"

  # Language packages
  log "Installing Ruby gems…"
  install_ruby_gems "${RUBY_GEMS[@]}"

  log "Installing global npm packages…"
  install_npm_packages "${NPM_PACKAGES[@]}"

  # Config (stow)
  log "Configuring dotfiles via stow…"
  # Stow directory is the repo root (where the stow packages live).
  # Target directory is handled inside stow_configure (it uses $HOME).
  stow_configure "${root}" "${STOW[@]}"

  log "Setup complete! You may want to restart your shell (or reboot)."
}

main "$@"
