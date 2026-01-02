#!/usr/bin/env bash
# install/utils.sh
#
# Shared utilities for ./install.sh
#
# Strategy (see agents.md):
# - Idempotent: safe to run repeatedly.
# - Support: macOS, SteamOS (Arch), Debian-based.
# - Prefer Homebrew everywhere; use native managers only for packages explicitly listed in
#   AUR/APT/FLATPAK sections of packages.conf.
#
# NOTE: This file is intended to be sourced by install.sh (not executed).

set -euo pipefail

###############################################################################
# Logging / errors
###############################################################################

log()  { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

require_cmd() {
  local missing=()
  local cmd
  for cmd in "$@"; do
    if ! need_cmd "$cmd"; then
      missing+=("$cmd")
    fi
  done
  if (( ${#missing[@]} > 0 )); then
    die "Missing required command(s): ${missing[*]}"
  fi
}

###############################################################################
# OS detection
###############################################################################
# Exports:
#   OS: macOS | SteamOS | Debian | Unknown
#   OS_KERNEL: uname -s
#   OS_DISTRO_ID: /etc/os-release ID (if present)
#   OS_PRETTY: /etc/os-release PRETTY_NAME (if present)

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
        # Heuristic fallback
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
# Homebrew bootstrap + shellenv
###############################################################################

brew_path_candidates() {
  cat <<'EOF'
/opt/homebrew/bin/brew
/usr/local/bin/brew
/home/linuxbrew/.linuxbrew/bin/brew
EOF
  if [[ -n "${HOME:-}" ]]; then
    printf '%s\n' "${HOME}/.linuxbrew/bin/brew"
  fi
}

brew_shellenv_eval() {
  # Make brew available in the current shell session.
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

  return 1
}

install_homebrew_if_missing() {
  if brew_shellenv_eval; then
    return 0
  fi

  log "Installing Homebrew…"
  require_cmd curl /bin/bash

  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  brew_shellenv_eval || die "Homebrew installed but brew is still not available (PATH/shellenv issue)."
}

###############################################################################
# OS prerequisites
###############################################################################

ensure_prereqs_macos() {
  log "Ensuring macOS prerequisites…"
  require_cmd xcode-select

  # If already installed, xcode-select -p succeeds
  if xcode-select -p >/dev/null 2>&1; then
    return 0
  fi

  # Interactive GUI prompt; acceptable for local setup.
  xcode-select --install || true
}

steamos_readonly_supported() {
  need_cmd steamos-readonly
}

with_steamos_readonly_disabled() {
  # Usage: with_steamos_readonly_disabled <cmd...>
  if ! steamos_readonly_supported; then
    "$@"
    return
  fi

  require_cmd sudo steamos-readonly
  sudo steamos-readonly disable

  local status=0
  "$@" || status=$?

  sudo steamos-readonly enable || true
  return "$status"
}

ensure_prereqs_steamos() {
  log "Ensuring SteamOS/Arch prerequisites…"
  require_cmd sudo pacman

  with_steamos_readonly_disabled bash -c '
    set -euo pipefail
    if command -v pacman-key >/dev/null 2>&1; then
      sudo pacman-key --init || true
      sudo pacman-key --populate archlinux || true
      sudo pacman-key --populate holo || true
    fi

    # base-devel is required for building AUR helpers like yay.
    sudo pacman -Syu --noconfirm
    sudo pacman -S --needed --noconfirm base-devel git curl file procps-ng
  '
}

ensure_prereqs_debian() {
  log "Ensuring Debian-based prerequisites…"
  require_cmd sudo

  if need_cmd apt-get; then
    sudo apt-get update -y
    sudo apt-get install -y --no-install-recommends \
      ca-certificates curl git build-essential file procps pkg-config
  elif need_cmd apt; then
    sudo apt update -y
    sudo apt install -y ca-certificates curl git build-essential file procps pkg-config
  else
    die "apt/apt-get not found; cannot install Debian prerequisites."
  fi
}

ensure_prereqs() {
  case "${OS:-Unknown}" in
    macOS)  ensure_prereqs_macos ;;
    SteamOS) ensure_prereqs_steamos ;;
    Debian) ensure_prereqs_debian ;;
    *) die "Unsupported OS for prerequisites: ${OS:-Unknown}" ;;
  esac
}

###############################################################################
# Package installation helpers
###############################################################################

brew_is_formula_installed() {
  brew list --formula -1 "$1" &>/dev/null
}

brew_is_cask_installed() {
  brew list --cask -1 "$1" &>/dev/null
}

brew_install_one() {
  # Best-effort: try as formula first, then as cask on macOS only.
  local name="$1"

  if brew_is_formula_installed "$name"; then
    return 0
  fi

  # On macOS, support casks in BREW_MACOS, but we won't guess here unless formula install fails.
  if brew install "$name" >/dev/null 2>&1; then
    return 0
  fi

  if [[ "${OS:-Unknown}" == "macOS" ]]; then
    if brew_is_cask_installed "$name"; then
      return 0
    fi
    brew install --cask "$name"
    return 0
  fi

  return 1
}

install_brew_packages() {
  # Usage: install_brew_packages "${BREW[@]}"
  require_cmd brew

  local pkgs=("$@")
  local pkg
  for pkg in "${pkgs[@]}"; do
    [[ -z "$pkg" ]] && continue

    if brew_is_formula_installed "$pkg" || brew_is_cask_installed "$pkg"; then
      log "brew: already installed: $pkg"
      continue
    fi

    log "brew: installing: $pkg"
    if ! brew_install_one "$pkg"; then
      die "brew could not install '$pkg' (consider moving it to AUR/APT or OS-specific lists)"
    fi
  done
}

###############################################################################
# Native package managers (explicit lists only)
###############################################################################
#
# - SteamOS/Arch: AUR via yay (AUR list)
# - Debian: APT via apt/apt-get (APT list)
# - Linux (SteamOS/Debian): Flatpak via flatpak (FLATPAK list)

ensure_yay_installed() {
  if need_cmd yay; then
    return 0
  fi

  # Install yay from AUR
  require_cmd sudo pacman git makepkg

  with_steamos_readonly_disabled bash -c '
    set -euo pipefail
    tmp="$(mktemp -d)"
    trap "rm -rf \"$tmp\"" EXIT
    cd "$tmp"
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
  '
}

aur_is_installed() {
  # Works for both repo and AUR packages when yay is installed.
  yay -Qi "$1" &>/dev/null
}

install_aur_packages() {
  # Usage: install_aur_packages "${AUR[@]}"
  [[ "${OS:-Unknown}" == "SteamOS" ]] || return 0

  local pkgs=("$@")
  if (( ${#pkgs[@]} == 0 )); then
    return 0
  fi

  ensure_yay_installed

  local pkg
  for pkg in "${pkgs[@]}"; do
    [[ -z "$pkg" ]] && continue
    if aur_is_installed "$pkg"; then
      log "aur: already installed: $pkg"
      continue
    fi

    log "aur: installing: $pkg"
    with_steamos_readonly_disabled yay -S --needed --noconfirm "$pkg"
  done
}

apt_is_installed() {
  dpkg -s "$1" >/dev/null 2>&1
}

install_apt_packages() {
  # Usage: install_apt_packages "${APT[@]}"
  [[ "${OS:-Unknown}" == "Debian" ]] || return 0

  local pkgs=("$@")
  if (( ${#pkgs[@]} == 0 )); then
    return 0
  fi

  require_cmd sudo
  if need_cmd apt-get; then
    sudo apt-get update -y
    local pkg
    for pkg in "${pkgs[@]}"; do
      [[ -z "$pkg" ]] && continue
      if apt_is_installed "$pkg"; then
        log "apt: already installed: $pkg"
      else
        log "apt: installing: $pkg"
        sudo apt-get install -y --no-install-recommends "$pkg"
      fi
    done
  elif need_cmd apt; then
    sudo apt update -y
    local pkg
    for pkg in "${pkgs[@]}"; do
      [[ -z "$pkg" ]] && continue
      if apt_is_installed "$pkg"; then
        log "apt: already installed: $pkg"
      else
        log "apt: installing: $pkg"
        sudo apt install -y "$pkg"
      fi
    done
  else
    die "apt/apt-get not found; cannot install APT packages."
  fi
}

flatpak_is_installed() {
  # Usage: flatpak_is_installed <app-id>
  # Checks user installation to align with the brew “user-space” philosophy.
  flatpak info --user "$1" >/dev/null 2>&1
}

ensure_flathub_remote() {
  # Add flathub remote for the current user if missing.
  # This is safe/idempotent.
  require_cmd flatpak
  if flatpak remotes --user 2>/dev/null | grep -qx "flathub"; then
    return 0
  fi
  log "flatpak: adding flathub remote (user)…"
  flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}

install_flatpak_packages() {
  # Usage: install_flatpak_packages "${FLATPAK[@]}"
  # Linux only (SteamOS + Debian). Skips on macOS.
  [[ "${OS:-Unknown}" != "macOS" ]] || return 0

  local pkgs=("$@")
  if (( ${#pkgs[@]} == 0 )); then
    return 0
  fi

  if ! need_cmd flatpak; then
    warn "flatpak not found; skipping FLATPAK packages."
    return 0
  fi

  ensure_flathub_remote

  local pkg
  for pkg in "${pkgs[@]}"; do
    [[ -z "$pkg" ]] && continue

    if flatpak_is_installed "$pkg"; then
      log "flatpak: already installed: $pkg"
      continue
    fi

    log "flatpak: installing: $pkg"
    flatpak install --user --noninteractive --or-update flathub "$pkg"
  done
}

###############################################################################
# Runtime installs (Ruby + Node)
###############################################################################

read_version_file() {
  local path="$1"
  [[ -f "$path" ]] || die "Version file not found: $path"
  local version
  version="$(tr -d ' \t\r\n' <"$path")"
  [[ -n "$version" ]] || die "Version file is empty: $path"
  printf '%s' "$version"
}

ruby_prefix_for() {
  local version="$1"
  printf '%s' "${HOME}/.rubies/ruby-${version}"
}

ruby_is_installed() {
  local version="$1"
  local prefix="$2"
  [[ -x "${prefix}/bin/ruby" ]] || return 1
  "${prefix}/bin/ruby" -v 2>/dev/null | grep -q "ruby ${version}\b"
}

install_ruby_runtime() {
  local version_file="${1:-ruby/.ruby-version}"
  require_cmd ruby-install

  local version prefix
  version="$(read_version_file "$version_file")"
  prefix="$(ruby_prefix_for "$version")"

  if ruby_is_installed "$version" "$prefix"; then
    log "ruby: already installed: ${version} (${prefix})"
    return 0
  fi

  log "ruby: installing ${version} with jemalloc + YJIT (prefix: ${prefix})"
  ruby-install ruby "$version" -- \
    --prefix="$prefix" \
    --with-jemalloc \
    --enable-yjit

  log "ruby: installed: ${version} (${prefix})"
}

node_prefix_for() {
  local version="$1"
  printf '%s' "${HOME}/.nodes/node-${version}"
}

node_is_installed() {
  local version="$1"
  local prefix="$2"
  [[ -x "${prefix}/bin/node" ]] || return 1
  "${prefix}/bin/node" --version 2>/dev/null | tr -d 'v' | grep -qx "${version}"
}

install_node_runtime() {
  local version_file="${1:-node/.node-version}"
  require_cmd node-build

  local version prefix
  version="$(read_version_file "$version_file")"
  prefix="$(node_prefix_for "$version")"

  if node_is_installed "$version" "$prefix"; then
    log "node: already installed: ${version} (${prefix})"
    return 0
  fi

  log "node: installing ${version} (prefix: ${prefix})"
  node-build "$version" "$prefix"

  log "node: installed: ${version} (${prefix})"
}

###############################################################################
# Language packages (Ruby gems + npm globals)
###############################################################################

install_ruby_gems() {
  # Installs into whatever `gem` is on PATH (the active Ruby).
  # You should ensure your shell points to the Ruby you want before running, or
  # adjust install.sh to export PATH to the installed Ruby prefix.
  require_cmd gem

  log "gem: updating RubyGems (best-effort)…"
  gem update --system || warn "gem update --system failed; continuing."

  local gems=("$@")
  local g
  for g in "${gems[@]}"; do
    [[ -z "$g" ]] && continue
    if gem list -i "$g" >/dev/null 2>&1; then
      log "gem: already installed: $g"
    else
      log "gem: installing: $g"
      gem install "$g"
    fi
  done
}

install_npm_packages() {
  require_cmd npm

  local pkgs=("$@")
  local p
  for p in "${pkgs[@]}"; do
    [[ -z "$p" ]] && continue
    if npm -g ls --depth=0 "$p" >/dev/null 2>&1; then
      log "npm: already installed: $p"
    else
      log "npm: installing: $p"
      npm install -g "$p"
    fi
  done
}

###############################################################################
# Stow configuration
###############################################################################

stow_configure() {
  # Usage: stow_configure <stow_root_dir> "${STOW[@]}"
  local stow_dir="$1"
  shift || true

  require_cmd stow

  [[ -d "$stow_dir" ]] || die "Stow directory not found: $stow_dir"

  local apps=("$@")
  local app
  for app in "${apps[@]}"; do
    [[ -z "$app" ]] && continue
    [[ -d "${stow_dir}/${app}" ]] || die "Stow package not found: ${stow_dir}/${app}"

    log "stow: applying: $app"
    stow --dir "$stow_dir" --target "$HOME" --restow "$app"
  done
}
