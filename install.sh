#!
# source: https://github.com/typecraft-dev/crucible

# Print logo
print_logo() {
  cat << "EOF"
Etienne's dev setup
EOF
}

clear
print_logo

# Exit on any error
set -e

# Source utility functions
source install/utils.sh

# Source the package list
if [ ! -f "packages.conf" ]; then
  echo "Error: packages.conf not found!"
  exit 1
fi

source packages.conf

determine_os
# Update the system first
if [[ "$(OS)" == "Unknown"]]; then
  abort "Installation is only supported on macOS and Linux."
elif [[ "$(OS)" == "SteamOS" ]]; then
  update_steamos
  update_steamos_packages
elif [[ "$(OS)" == "macOS" ]]; then
  update_macos
fi

# Prerequisites
if [[ "$(OS)" == "SteamOS"]]; then
  echo "Ensuring base-devel is installed…"
  echo "Temporarily disabling steamos-readonly to install packages…"
  sudo steamos-readonly disable
  echo "Initializing pacman keyring with arch and holo…"
  sudo pacman-key --init
  sudo pacman-key --populate archlinux
  sudo pacman-key --populate holo
  echo "Installing base-devel and other prerequisites…"
  sudo pacman -S --needed base-devel procps-ng curl file git
  echo "Re-enabling steamos-readonly…"
  sudo steamos-readonly enable
elif [[ "$(OS)" == "macOS" ]]; then
  echo "Ensuring Xcode Command Line Tools are installed…"
  xcode-select --install || echo "Xcode Command Line Tools already installed."
fi

echo "Installing Homebrew…"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"


# Install packages by category
echo "Installing system utilities…"
install_packages "${SYSTEM_UTILS[@]}"

echo "Installing development tools…"
install_packages "${DEV_TOOLS[@]}"

# echo "Installing system maintenance tools…"
# install_packages "${MAINTENANCE[@]}"

# echo "Installing desktop environment…"
# install_packages "${DESKTOP[@]}"

echo "Installing desktop environment…"
install_packages "${OFFICE[@]}"

# echo "Installing media packages…"
# install_packages "${MEDIA[@]}"

# echo "Installing fonts…"
# install_packages "${FONTS[@]}"

echo "Installing packages that needs OS specific installs…"
for package in "${OS_SPECIFIC[@]}"; do
  install_os_specific "$package"
done

echo "Installing default ruby version…"
install_ruby

echo "Installing default ruby gems…"
install_ruby_gems "${RUBY_GEMS[@]}"

echo "Installing default node version…"
install_node

echo "Installing default npm packages…"
install_npm_packages "${NPM_PACKAGES[@]}"

echo "Installing ssh keys…"
# TODO: fully move to using 1password CLI for SSH key management
# TODO: add steps for manual installation of ssh keys
echo "Not implemented yet."


# # Enable services
# echo "Configuring services…"
# for service in "${SERVICES[@]}"; do
#   if ! systemctl is-enabled "$service" &> /dev/null; then
#     echo "Enabling $service…"
#     sudo systemctl enable "$service"
#   else
#     echo "$service is already enabled"
#   fi
# done

# # Some programs just run better as flatpaks. Like discord/spotify
# echo "Installing flatpaks (like discord and spotify)"
# . install-flatpaks.sh

echo "Setup complete! You may want to reboot your system."
