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
  local host user shell_name repo
  host="$(hostname 2>/dev/null || true)"
  user="${USER:-}"
  shell_name="${SHELL:-}"
  repo="$(pwd 2>/dev/null || true)"

  cat <<EOF
=========================================
    E T I E N N E ' S   D O T F I L E S
=========================================
 Target OS : ${os}
 Host      : ${host}
 User      : ${user}
 Shell     : ${shell_name}
 Repo      : ${repo}

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
  if declare -p BREW >/dev/null 2>&1; then
    install_brew_packages "${BREW[@]}"
  else
    warn "BREW not defined in packages.conf; skipping."
  fi

  if [[ "${OS:-Unknown}" == "macOS" ]]; then
    log "Installing Homebrew packages (macOS)…"
    if declare -p BREW_MACOS >/dev/null 2>&1; then
      install_brew_packages "${BREW_MACOS[@]}"
    else
      warn "BREW_MACOS not defined in packages.conf; skipping."
    fi
  else
    log "Installing Homebrew packages (Linux)…"
    if declare -p BREW_LINUX >/dev/null 2>&1; then
      install_brew_packages "${BREW_LINUX[@]}"
    else
      warn "BREW_LINUX not defined in packages.conf; skipping."
    fi
  fi

  if [[ "${OS:-Unknown}" == "SteamOS" ]]; then
    log "Installing AUR packages (SteamOS/Arch)…"
    if declare -p AUR >/dev/null 2>&1; then
      install_aur_packages "${AUR[@]}"
    else
      warn "AUR not defined in packages.conf; skipping."
    fi
  fi

  if [[ "${OS:-Unknown}" == "Debian" ]]; then
    log "Installing APT packages (Debian-based)…"
    if declare -p APT >/dev/null 2>&1; then
      install_apt_packages "${APT[@]}"
    else
      warn "APT not defined in packages.conf; skipping."
    fi
  fi

  if [[ "${OS:-Unknown}" != "macOS" ]]; then
    log "Installing Flatpak packages (Linux)…"
    if declare -p FLATPAK >/dev/null 2>&1; then
      install_flatpak_packages "${FLATPAK[@]}"
    else
      warn "FLATPAK not defined in packages.conf; skipping."
    fi
  fi

  # Runtimes (versions are controlled by repo files)
  log "Installing Ruby runtime (from ruby/.ruby-version)…"
  install_ruby_runtime "ruby/.ruby-version"

  log "Installing Node runtime (from node/.node-version)…"
  install_node_runtime "node/.node-version"

  # Language packages
  log "Installing Ruby gems…"
  if declare -p RUBY_GEMS >/dev/null 2>&1; then
    install_ruby_gems "${RUBY_GEMS[@]}"
  else
    warn "RUBY_GEMS not defined in packages.conf; skipping."
  fi

  log "Installing global npm packages…"
  if declare -p NPM_PACKAGES >/dev/null 2>&1; then
    install_npm_packages "${NPM_PACKAGES[@]}"
  else
    warn "NPM_PACKAGES not defined in packages.conf; skipping."
  fi

  # Config (stow)
  log "Configuring dotfiles via stow…"
  if declare -p STOW >/dev/null 2>&1; then
    # Stow root is the repo root (no more ./home prefix).
    # Each stow package in STOW must be a directory at: <repo>/<APP>
    stow_configure "${root}" "${STOW[@]}"
  else
    warn "STOW not defined in packages.conf; skipping stow step."
  fi

  log "Setup complete! You may want to restart your shell (or reboot)."
}

main "$@"
