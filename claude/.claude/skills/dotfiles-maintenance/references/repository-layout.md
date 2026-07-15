# Dotfiles Repository Layout Detail

**Stow packages**

Each top-level directory in the dotfiles repo is a Stow package. Key packages include:
`zsh`, `git`, `ghostty`, `ruby`, `bundler`, `node`, `neovim`, `zed`, `lefthook`, `rubocop`,
`solargraph`, `1password`, `ssh`, `secrets`, `lazygit`, `pumadev`, `caddy`, `claude`.

**Cross-platform**

The dotfiles support macOS, SteamOS/Arch, and Debian-based Linux. Platform-specific packages are
separated in `packages.conf` (`BREW_MACOS`, `BREW_LINUX`, `AUR`, `APT`, `FLATPAK`).
