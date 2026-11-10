#!/usr/bin/env bash
# install/tasks/26_install_herdr_app.sh
#
# herdr-app install task script (SteamOS only).
#
# Purpose:
# - Install herdr-app on SteamOS from the verified Linux release tarball. On macOS the cask in
#   `BREW_MACOS` installs it.
#
# Usage:
#   ./install/tasks/26_install_herdr_app.sh
#
# Notes:
# - "SteamOS" is the group `determine_os` reports, the same group the AUR task serves.
# - It reads the release manifest, picks the target for `uname -m`, downloads the tarball and checks
#   its sha256 against the manifest before anything lands in $HOME.
# - It writes only under $HOME and $XDG_DATA_HOME, uses no sudo, runs nothing it downloaded and does
#   not install herdr-core. herdr-app updates itself afterwards.
# - Every request is HTTPS only, redirects included, and the tarball must come from releases.herdr.dev.
#
# Idempotency:
# - The launcher link is written last. Once it resolves to an executable the task makes no request.
#   Every step overwrites, so a rerun after a failure starts clean.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_common.sh"

readonly HERDR_APP_MANIFEST_URL="https://releases.herdr.dev/app/latest.json"
readonly HERDR_APP_URL_PREFIX="https://releases.herdr.dev/"

HERDR_APP_STAGING=""

herdr_app_cleanup() { [[ -z "$HERDR_APP_STAGING" ]] || rm -rf "$HERDR_APP_STAGING"; }

herdr_app_home()     { printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/herdr-app"; }
herdr_app_launcher() { printf '%s\n' "$HOME/.local/bin/herdr-app"; }

# True when the launcher link resolves to an executable file.
herdr_app_installed() {
  [[ -x "$(herdr_app_launcher)" && -f "$(herdr_app_launcher)" ]]
}

# Prints the release target for this machine, or dies.
herdr_app_target() {
  local arch
  arch="$(uname -m)"

  case "$arch" in
    x86_64)          printf 'linux-x86_64\n' ;;
    aarch64|arm64)   printf 'linux-aarch64\n' ;;
    *)               die "herdr-app: no release for architecture: ${arch}" ;;
  esac
}

# Downloads <url> to <out>, HTTPS only, redirects included.
herdr_app_fetch() {
  local url="$1" out="$2"
  curl --proto =https --proto-redir =https -fsSL -o "$out" "$url"
}

# Prints "<url> <sha256>" for <target> from <manifest>, or dies.
herdr_app_release() {
  local manifest="$1" target="$2" url sha256

  url="$(jq -er --arg target "$target" '.targets[$target].url' "$manifest")" \
    || die "herdr-app: no url for ${target} in the release manifest"
  sha256="$(jq -er --arg target "$target" '.targets[$target].sha256' "$manifest")" \
    || die "herdr-app: no sha256 for ${target} in the release manifest"

  [[ "$url" == "$HERDR_APP_URL_PREFIX"* ]] || die "herdr-app: tarball url is not on releases.herdr.dev: ${url}"
  [[ "$sha256" =~ ^[0-9a-fA-F]{64}$ ]] || die "herdr-app: malformed sha256 in the release manifest: ${sha256}"

  printf '%s %s\n' "$url" "$sha256"
}

# Dies unless the tarball's sha256 equals <sha256>.
herdr_app_verify() {
  local tarball="$1" expected actual
  expected="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')"
  actual="$(sha256sum "$tarball")"
  actual="${actual%% *}"

  [[ "$actual" == "$expected" ]] || die "herdr-app: sha256 mismatch (expected ${expected}, got ${actual})"
}

# Extracts <tarball> into <staging>, or dies unless it holds a regular, executable herdr-app.
herdr_app_unpack() {
  local tarball="$1" staging="$2" executable="$2/herdr-app/herdr-app"

  tar -xzf "$tarball" -C "$staging"
  [[ -f "$executable" && ! -L "$executable" && -x "$executable" ]] \
    || die "herdr-app: the tarball holds no regular executable at herdr-app/herdr-app"
}

herdr_app_desktop_entry() {
  local app_home="$1"
  printf '%s\n' \
    "[Desktop Entry]" \
    "Type=Application" \
    "Name=Herdr" \
    "Exec=${app_home}/herdr-app" \
    "Icon=herdr-app" \
    "Categories=Development;"
}

# Moves the unpacked release into the app home and links the launcher last.
herdr_app_place() {
  local staging="$1" app_home data launcher
  app_home="$(herdr_app_home)"
  data="${XDG_DATA_HOME:-$HOME/.local/share}"
  launcher="$(herdr_app_launcher)"

  mkdir -p "$(dirname "$app_home")" "$data/icons/hicolor/scalable/apps" "$data/applications" "$(dirname "$launcher")"
  rm -rf "${app_home}.new"
  mv "$staging/herdr-app" "${app_home}.new"
  rm -rf "$app_home"
  mv "${app_home}.new" "$app_home"

  cp -f "$app_home/herdr-app.svg" "$data/icons/hicolor/scalable/apps/herdr-app.svg"
  herdr_app_desktop_entry "$app_home" > "$data/applications/herdr-app.desktop"
  ln -sfn "$app_home/herdr-app" "$launcher"
}

main() {
  task_bootstrap

  determine_os
  log "os: detected: ${OS:-Unknown}${OS_PRETTY:+ (${OS_PRETTY})}"

  if [[ "${OS:-Unknown}" != "SteamOS" ]]; then
    log "herdr-app: not SteamOS, skipping."
    return 0
  fi

  if herdr_app_installed; then
    log "herdr-app: already installed, skipping."
    return 0
  fi

  require_cmd curl jq tar sha256sum

  local target release url sha256
  target="$(herdr_app_target)"
  HERDR_APP_STAGING="$(mktemp -d)"
  trap herdr_app_cleanup EXIT
  local staging="$HERDR_APP_STAGING"

  herdr_app_fetch "$HERDR_APP_MANIFEST_URL" "$staging/latest.json"
  release="$(herdr_app_release "$staging/latest.json" "$target")"
  read -r url sha256 <<< "$release"
  herdr_app_fetch "$url" "$staging/herdr-app.tar.gz"
  herdr_app_verify "$staging/herdr-app.tar.gz" "$sha256"
  mkdir "$staging/unpacked"
  herdr_app_unpack "$staging/herdr-app.tar.gz" "$staging/unpacked"
  herdr_app_place "$staging/unpacked"

  log "herdr-app: installed from ${url}."
}

main "$@"
