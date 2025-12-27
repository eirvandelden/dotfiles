#!/usr/bin/env bash
# Stow implementation for dotfiles installer.
#
# This file is intended to be sourced (not executed).
#
# Responsibilities:
# - Provide functions to restore/remove dotfiles using GNU Stow
# - Keep behavior idempotent and user-space
# - Validate expected directory structure
#
# Orchestration is done by install/steps/config.sh, which loads stow.conf and then
# calls these functions.

set -euo pipefail

stow_check_prereqs() {
  if ! command -v stow >/dev/null 2>&1; then
    printf 'error: stow is required but was not found on PATH\n' >&2
    return 1
  fi
}

stow_check_package_dir() {
  local stow_dir="$1"
  if [[ -z "$stow_dir" ]]; then
    printf 'error: stow dir is required\n' >&2
    return 1
  fi
  if [[ ! -d "$stow_dir" ]]; then
    printf 'error: stow directory not found: %s\n' "$stow_dir" >&2
    return 1
  fi
}

stow_check_package_exists() {
  local stow_dir="$1"
  local package="$2"

  if [[ -z "$package" ]]; then
    printf 'error: stow package name is required\n' >&2
    return 1
  fi

  if [[ ! -d "${stow_dir}/${package}" ]]; then
    printf 'error: stow package not found: %s\n' "${stow_dir}/${package}" >&2
    return 1
  fi
}

# Restore a single stow package from <stow_dir> into $HOME.
# Usage: stow_restore_package "/path/to/home" "neovim"
stow_restore_package() {
  local stow_dir="$1"
  local package="$2"

  stow_check_prereqs
  stow_check_package_dir "$stow_dir"
  stow_check_package_exists "$stow_dir" "$package"

  printf 'Restoring config via stow: %s\n' "$package"
  stow \
    --dir "$stow_dir" \
    --target "$HOME" \
    --restow \
    "$package"
}

# Remove a single stow package's links from $HOME.
# Usage: stow_remove_package "/path/to/home" "neovim"
stow_remove_package() {
  local stow_dir="$1"
  local package="$2"

  stow_check_prereqs
  stow_check_package_dir "$stow_dir"
  stow_check_package_exists "$stow_dir" "$package"

  printf 'Removing config via stow: %s\n' "$package"
  stow \
    --dir "$stow_dir" \
    --target "$HOME" \
    --delete \
    "$package"
}

# Restore multiple stow packages.
# Usage: stow_restore_packages "/path/to/home" pkg1 pkg2 ...
stow_restore_packages() {
  local stow_dir="$1"
  shift || true

  stow_check_prereqs
  stow_check_package_dir "$stow_dir"

  local packages=("$@")
  if (( ${#packages[@]} == 0 )); then
    printf 'No stow packages specified; nothing to restore.\n'
    return 0
  fi

  printf 'Restoring %d stow package(s) from %s\n' "${#packages[@]}" "$stow_dir"

  local pkg
  for pkg in "${packages[@]}"; do
    [[ -z "$pkg" ]] && continue
    stow_restore_package "$stow_dir" "$pkg"
  done
}

# Remove multiple stow packages.
# Usage: stow_remove_packages "/path/to/home" pkg1 pkg2 ...
stow_remove_packages() {
  local stow_dir="$1"
  shift || true

  stow_check_prereqs
  stow_check_package_dir "$stow_dir"

  local packages=("$@")
  if (( ${#packages[@]} == 0 )); then
    printf 'No stow packages specified; nothing to remove.\n'
    return 0
  fi

  printf 'Removing %d stow package(s) from %s\n' "${#packages[@]}" "$stow_dir"

  local pkg
  for pkg in "${packages[@]}"; do
    [[ -z "$pkg" ]] && continue
    stow_remove_package "$stow_dir" "$pkg"
  done
}
