# agents.md

This repository contains Etienne van Delden’s dotfiles and a cross-platform installer that bootstraps a development environment in an **idempotent** way.

**Idempotent** means: you can run `./install.sh` repeatedly; it should only make changes when something is missing or not configured according to this repo.

---

## Audience

This document is for AI agents (and humans) making changes in this repository. It explains:

- the purpose of the repo,
- the install strategy,
- the source-of-truth configuration structure,
- conventions and guardrails to keep the installer reliable.

---

## Supported platforms

The installer is expected to run on:

- **macOS**
- **SteamOS** (Arch-based Linux)
- **Debian-based Linux** (Debian, Ubuntu, etc.)

---

## Bootstrap script (curlable entrypoint)

This repo includes a minimal POSIX `sh` bootstrap script: `bootstrap.sh`.

Purpose:

- Clone or update this repo into the default location: `~/Developer/dotfiles`
- Run the installer: `~/Developer/dotfiles/install.sh`

How to run:

    curl -fsSL https://raw.githubusercontent.com/eirvandelden/dotfiles/main/bootstrap.sh | sh

Optional overrides (advanced):

- `TARGET_DIR` (default: `~/Developer/dotfiles`)
- `REPO_URL` (default: `https://github.com/eirvandelden/dotfiles.git`)
- `BRANCH` (default: `main`)

Example:

    TARGET_DIR="$HOME/Developer/dotfiles" \
    REPO_URL="https://github.com/eirvandelden/dotfiles.git" \
    BRANCH="main" \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/eirvandelden/dotfiles/main/bootstrap.sh)"

Notes:

- The bootstrap script intentionally stays minimal and requires `git`.
- OS detection, prerequisites, and all configuration logic live in `install.sh`.

---

## Core strategy (keep it simple)

### Package managers

- **Homebrew is the default, system-agnostic package manager on all OSes.**
- If a package is not available in Homebrew, fall back to:
  - **SteamOS/Arch:** `yay` (AUR), and `pacman` as a prerequisite
  - **Debian-based:** `apt` / `apt-get`
- On Linux, support **Flatpak** as an additional package manager for GUI apps:
  - **Linux (SteamOS + Debian):** `flatpak` (user installs, default remote `flathub`)

No generated Brewfiles are used as source of truth. The configuration is defined in `packages.conf`.

### Source of truth

`packages.conf` is the only manually maintained file that defines what should be installed.

It must remain valid Bash because the installer sources it.

---

## `packages.conf` required sections

`packages.conf` defines arrays. Each array has a strict meaning:

### Homebrew (preferred)

- `BREW`
  - Packages installed via `brew` on **all** supported OSes.
  - Items must be installable via: `brew install <name>`

- `BREW_MACOS`
  - Packages installed via `brew` on **macOS only**.
  - Items must be installable via: `brew install <name>` or `brew install --cask <name>`
  - Use this for macOS GUI apps and macOS-only tools.

- `BREW_LINUX`
  - Packages installed via `brew` on **Linux only** (SteamOS + Debian-based).
  - Items must be installable via: `brew install <name>`

### Native fallbacks (only when not in brew)

- `AUR`
  - Packages installed via `yay` on **SteamOS/Arch only**.
  - Items must be installable via: `yay -S <name>`
  - Use only when the package cannot be installed via brew (or brew name mismatch makes it impractical).

- `APT`
  - Packages installed via `apt` on **Debian-based only**.
  - Items must be installable via: `apt-get install <name>` (or `apt install <name>`)
  - Use only when the package cannot be installed via brew.

### Flatpak (Linux)

- `FLATPAK`
  - Flatpak app IDs to install on **Linux only** (SteamOS + Debian-based).
  - Items should be app IDs, e.g. `com.discordapp.Discord`.
  - Installer should:
    - ensure the `flathub` remote exists for the current user
    - install with `flatpak install --user --noninteractive --or-update`

### Runtimes and language tooling

- `RUBY_GEMS`
  - Ruby gems installed after Ruby is installed.
  - Installed via `gem install`.

- `NPM_PACKAGES`
  - Global npm packages installed after Node is installed.
  - Installed via `npm install -g`.

### Dotfiles configuration

- `STOW`
  - List of “stow apps” (stow packages) to configure.
  - For each entry `APP`, installer will run: `stow APP`
  - `APP` must correspond to a directory at the repository root (for example: `./APP`).

---

## Install flow (`install.sh`)

`install.sh` should implement this sequence:

1. **Print a boot screen** (clear + logo/header).
2. **Detect OS** (macOS / SteamOS / Debian).
3. **Install prerequisites** (OS-dependent):
   - macOS: Xcode Command Line Tools (or verify present)
   - SteamOS: keyring/base tooling; handle readonly filesystem safely
   - Debian: `apt update`, install minimum build tools (curl, git, etc.)
4. **Install Homebrew** (if missing) and load brew environment into the current shell session.
5. **Install packages** in this order:
   1. `BREW`
   2. `BREW_MACOS` (macOS only)
   3. `BREW_LINUX` (Linux only)
   4. `AUR` (SteamOS/Arch only)
   5. `APT` (Debian only)
   6. `FLATPAK` (Linux only)
6. **Install runtimes**:
   - Ruby version from `ruby/.ruby-version`
   - Node version from `node/.node-version`
7. **Install language packages**:
   - `RUBY_GEMS`
   - `NPM_PACKAGES` (global)
8. **Configure dotfiles**:
   - run `stow` for each app in `STOW`

---

## Runtime versions (Ruby + Node)

Versions are defined by files in this repo:

- Ruby: `ruby/.ruby-version`
- Node: `node/.node-version`

### Ruby requirements

- Install using `ruby-install`.
- Build preferences:
  - **jemalloc support**
  - **YJIT enabled** (ZJIT is experimental; only enable if explicitly requested and supported by the toolchain/version)
- Must be idempotent:
  - if requested Ruby version is already installed, skip.

### Node requirements

- Install using `node-build`.
- Must be idempotent:
  - if requested Node version is already installed, skip.

---

## Idempotency rules (non-negotiable)

When changing installer behavior, keep these rules:

- **Check before install**:
  - brew: `brew list --formula` / `brew list --cask` or `brew list <name>`
  - yay: `yay -Qi <name>` (or `pacman -Qi` for repo pkgs)
  - apt: `dpkg -s <name>`
  - flatpak: `flatpak info --user <app-id>`
- **Avoid “always do X” steps** that cause churn on every run.
- **Fail fast with clear errors** when configuration is wrong:
  - missing `packages.conf`
  - missing stow package directory listed in `STOW`
  - missing required tools for runtime steps (e.g., `ruby-install`, `node-build`) if you expect them to be present

---

## SteamOS specifics

SteamOS can be immutable/readonly in places. If native installs are needed:

- toggle readonly safely (disable, perform install, re-enable)
- use traps/cleanup where appropriate so the system isn’t left writable on error
- be careful with `set -euo pipefail`: treat known-benign non-zero exits explicitly

---

## Engineering guidelines for agents

- Keep the code **boring and readable**.
- Prefer small functions with single responsibility.
- Logging:
  - print what you’re doing,
  - print what you skipped (already installed),
  - print when you fall back (brew → yay/apt/flatpak).
- Don’t introduce new generated artifacts as source of truth.
  - `packages.conf` is the source of truth.

---

## When requirements are unclear

Ask for clarification rather than inventing behavior, especially for:

- where runtimes should be installed (prefixes/shims),
- whether to bootstrap `yay`,
- how strictly to treat failures from OS update tools,
- flatpak install scope (`--user` vs system),
- stow root directory conventions.
