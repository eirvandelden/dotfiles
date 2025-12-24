#!/bin/bash

# Function to determin OS type
determine_os() {
  OS="$(uname)"
  case "${os_type}" in
    Linux*)   echo "SteamOS" ;;
    Darwin*)  echo "macOS" ;;
    *)        echo "Unknown" ;;
  esac
}

##
# SteamOS Specific Functions
##
update_steamos() {
  echo "Updating SteamOS system…"
  sudo steamos-update
}

# Update steamos packages
update_steamos_package() {
  echo "Updating system installed packages…"
  sudo pacman -Syu --noconfirm
}

##
# macOS Specific Functions
##
update_macos() {
  echo "Updating macOS system…"
  softwareupdate --install --all
}

### Brew functions

# Function to check if a package is installed
is_installed() {
  brew list --formula -1 "$name" &>/dev/null || brew list --cask -1 "$name" &>/dev/null
}

### Pacman functions

# Function to check if a package is installed
is_installed_with_pacman() {
  pacman -Qi "$1" &> /dev/null
}

# Function to check if a package is installed
is_group_installed_with_pacman() {
  pacman -Qg "$1" &> /dev/null
}

# Function to install packages if not already installed
install_packages_with_pacman() {
  local packages=("$@")
  local to_install=()

  for pkg in "${packages[@]}"; do
    if ! is_installed "$pkg" && ! is_group_installed "$pkg"; then
      to_install+=("$pkg")
    fi
  done

  if [ ${#to_install[@]} -ne 0 ]; then
    echo "Installing: ${to_install[*]}"
    pacman -S --noconfirm "${to_install[@]}"
  fi
}

##
# Generic functions
#

install_puma-dev() {
  echo "Installing puma-dev…"
  brew install puma/puma/puma-dev
}

install_ruby() {
  echo "Installing Ruby…"
  echo "Not implemented yet."
}

install_ruby_gems() {
  echo "Installing Ruby gems…"
  echo "Not implemented yet."
}

install_node() {
  echo "Installing Node.js…"
  echo "Not implemented yet."
}

install_npm_packages() {
  echo "Installing npm packages…"
  echo "Not implemented yet."
}
