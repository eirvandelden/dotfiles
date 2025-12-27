#!/usr/bin/env bash
# Generic shared functions for dotfiles installer.
#
# This file is intended to be sourced (not executed).
# It provides:
# - logging + error helpers
# - command presence checks
# - OS detection (macOS / SteamOS / Debian / Unknown)
# - Homebrew helpers (shellenv, install wrappers)
# - "prefer brew, fallback to native" helper hooks

set -euo pipefail

###############################################################################
# Logging / error helpers
###############################################################################

log() {
  printf '%s\n' "$*"
}

warn() {
  printf 'warning: %s\n' "$*" >&2
}

abort() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

check_required_tooling() {
  local missing=()

  local cmd
  for cmd in "$@"; do
    if ! need_cmd "$cmd"; then
      missing+=("$cmd")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    abort "Missing required tooling: ${missing[*]}"
  fi
}

###############################################################################
# OS detection
###############################################################################
# Exports:
#   OS            -> "macOS" | "SteamOS" | "Debian" | "Unknown"
#   OS_KERNEL     -> uname -s (Darwin, Linux, ...)
#   OS_DISTRO_ID  -> /etc/os-release ID when present (steamos, arch, debian, ubuntu, ...)
#   OS_PRETTY     -> PRETTY_NAME when present
determine_os() {
  OS_KERNEL="$(uname -s 2>/dev/null || echo Unknown)"
  OS_DISTRO_ID=""
  OS_PRETTY=""
  OS="Unknown"

  if [[ "$OS_KERNEL" == "Darwin" ]]; then
    OS="macOS"
  elif [[ "$OS_KERNEL" == "Linux" ]]; then
    if [[ -r /etc/os-release ]]; then
      # shellcheck disable=SC1091
      . /etc/os-release
      OS_DISTRO_ID="${ID:-}"
      OS_PRETTY="${PRETTY_NAME:-}"
    fi

    case "${OS_DISTRO_ID}" in
      steamos|holo|arch)
        OS="SteamOS"
        ;;
      debian|ubuntu|linuxmint|pop|elementary|kali|raspbian)
        OS="Debian"
        ;;
      *)
        # Fallback heuristics: if apt exists, treat as Debian-like; if pacman exists treat as SteamOS/Arch-like.
        if need_cmd apt-get || need_cmd apt; then
          OS="Debian"
        elif need_cmd pacman; then
          OS="SteamOS"
        else
          OS="Unknown"
        fi
        ;;
    esac
  fi

  export OS OS_KERNEL OS_DISTRO_ID OS_PRETTY
}

###############################################################################
# Homebrew helpers
###############################################################################

brew_path_candidates() {
  # Print candidates in priority order; caller decides which exists.
  # - macOS ARM uses /opt/homebrew
  # - macOS Intel often uses /usr/local
  # - Linuxbrew often uses /home/linuxbrew/.linuxbrew or ~/.linuxbrew
  cat <<'EOF'
/opt/homebrew/bin/brew
/usr/local/bin/brew
/home/linuxbrew/.linuxbrew/bin/brew
EOF
  if [[ -n "${HOME:-}" ]]; then
    printf '%s\n' "${HOME}/.linuxbrew/bin/brew"
  fi
}

setup_brew_shellenv() {
  # Make brew available in the current shell.
  if need_cmd brew; then
    # shellcheck disable=SC2046
    eval "$(brew shellenv)"
    return 0
  fi

  local candidate
  while IFS= read -r candidate; do
    if [[ -x "$candidate" ]]; then
      # shellcheck disable=SC2046
      eval "$("$candidate" shellenv)"
      return 0
    fi
  done < <(brew_path_candidates)

  abort "brew not found on PATH. Install Homebrew first, then re-run."
}

brew_is_installed_formula() {
  brew list --formula -1 "$1" &>/dev/null
}

brew_is_installed_cask() {
  brew list --cask -1 "$1" &>/dev/null
}

brew_install_formula() {
  local name="$1"

  if brew_is_installed_formula "$name"; then
    return 0
  fi

  log "Installing via brew: $name"
  brew install "$name"
}

brew_install_cask() {
  local name="$1"

  if brew_is_installed_cask "$name"; then
    return 0
  fi

  log "Installing via brew (cask): $name"
  brew install --cask "$name"
}

brew_install_best_effort() {
  # Try to install package via brew. Prefer formula; on failure try cask.
  # Returns 0 if installed (or already present), non-zero if brew can't install.
  local name="$1"

  if brew_is_installed_formula "$name" || brew_is_installed_cask "$name"; then
    return 0
  fi

  if brew install "$name" >/dev/null 2>&1; then
    return 0
  fi

  if brew install --cask "$name" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

###############################################################################
# Install policy: prefer brew, fallback to native manager
###############################################################################
# Native install function is delegated to OS-specific libs:
# - install_native_package_steamos <name>
# - install_native_package_debian <name>
# - install_native_package_macos <name>   (usually not used; brew is "native enough" on macOS)
#
# Those functions should:
# - install the package and return 0 on success
# - return non-zero if install fails or unsupported
install_via_brew_or_native() {
  local pkg="$1"

  check_required_tooling brew
  # brew is assumed already "shellenv'd" by the caller.
  if brew_install_best_effort "$pkg"; then
    return 0
  fi

  warn "Homebrew could not install '$pkg'; falling back to native package manager…"

  case "${OS:-Unknown}" in
    SteamOS)
      if need_cmd install_native_package_steamos; then
        install_native_package_steamos "$pkg"
        return $?
      fi
      ;;
    Debian)
      if need_cmd install_native_package_debian; then
        install_native_package_debian "$pkg"
        return $?
      fi
      ;;
    macOS)
      # Typically we don't have a meaningful native fallback for arbitrary packages on macOS.
      # (macOS native would be App Store / pkg installers). Keep it explicit.
      ;;
  esac

  abort "No native fallback available for OS=${OS:-Unknown} (package: $pkg)"
}

###############################################################################
# Version file helper (Ruby/Node)
###############################################################################

read_version_file() {
  local path="$1"
  [[ -f "$path" ]] || abort "Version file not found: $path"
  local version
  version="$(tr -d ' \t\r\n' <"$path")"
  [[ -n "$version" ]] || abort "Version file is empty: $path"
  printf '%s' "$version"
}
