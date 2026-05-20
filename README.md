# dotfiles

My personal dotfiles and a cross-platform installer to bootstrap my dev environment.

## 🤖Installation

### Option A: Curlable bootstrap (recommended)

This will clone/update the repo into `~/Developer/dotfiles` and run `./install.sh`:

    curl -fsSL https://raw.githubusercontent.com/eirvandelden/dotfiles/main/bootstrap.sh | sh

You can override defaults:

    TARGET_DIR="$HOME/Developer/dotfiles" \
    REPO_URL="https://github.com/eirvandelden/dotfiles.git" \
    BRANCH="main" \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/eirvandelden/dotfiles/main/bootstrap.sh)"

### Option B: Manual clone

    mkdir -p ~/Developer
    cd ~/Developer
    git clone https://github.com/eirvandelden/dotfiles.git
    cd dotfiles
    ./install.sh

## 🔁Syncing packages

Packages are defined in `packages.conf` and installed by `./install.sh`.

If you’re using Homebrew’s bundle on a specific machine, you can still dump a Brewfile manually, but it is not the source of truth for this repo.

### List currently installed packages (one-liners)

Homebrew (formulae):

    brew list --formula

Homebrew (casks, macOS only):

    brew list --cask

AUR / Arch (via yay):

    yay -Qe

pacman (native/explicitly installed packages):

    pacman -Qe

Debian (apt; manually installed packages):

    apt-mark showmanual

Flatpak (user installs, Linux only — supported by `./install.sh` via the `FLATPAK` list in `packages.conf`):

    flatpak list --user --app

## 🧩 Dotfiles (stow)

Dotfiles are applied using GNU Stow. The installer expects stow packages to be directories at the repository root (no `home/` directory).

Example:

- If `STOW=(neovim)` in `packages.conf`
- and there is a `./neovim/` directory in this repo

then the installer will run:

- `stow neovim`

## 🌳 Git Worktree Automation

This repo includes a generic, reusable worktree tooling system that automates the setup of new git worktrees. Perfect for managing multiple feature branches, Rails projects, or Conductor workspaces.

### What It Does

When you create a new worktree with `git worktree add feature-branch`, the system automatically:

1. **Symlinks shared files** from `.worktree-local/` using GNU Stow (e.g., `.env`, `config/master.key`, `storage/`)
2. **Configures puma-dev** for Rails projects (enables `https://feature-branch.myproject.localhost` access)
3. **Assigns stable ports** for development servers
4. **Integrates with Conductor** for seamless workspace creation

### Quick Start

```bash
# Prerequisites
brew install stow
brew install puma-dev  # Optional, for Rails projects

# The worktree tools are installed when you stow the git package
cd ~/Developer/dotfiles
stow git

# Create a worktree - automation runs automatically!
cd ~/Developer/myproject
git worktree add feature-branch
cd feature-branch
# Setup is done automatically via post-checkout hook

# Access your Rails app at:
# https://feature-branch.myproject.localhost
```

### Configuration

Create `.worktree.yml` in your repository root to customize behavior:

```yaml
project:
  name: myproject      # Required for puma-dev naming

stow:
  enabled: true
  packages:
    - rails           # Stow packages to symlink

puma_dev:
  enabled: true
```

Create `.worktree-local/` directory for shared files:

```
.worktree-local/
└── rails/
    ├── .env
    ├── config/
    │   └── master.key
    └── storage/
```

### Conductor Integration

Initialize a project for Conductor:

```bash
cd ~/Developer/myproject
conductor-init myproject 3000
```

This creates:
- `conductor.json` - Conductor configuration
- `bin/conductor-setup` - Setup script
- `script/server` - Universal server launcher

### Documentation

For complete documentation, see:
- [Git Worktree Tools README](git/.config/git/worktree-tools/README.md)

Available commands:
- `worktree-setup [path]` - Setup worktree (runs automatically via git hook)
- `worktree-setup-all` - Setup all worktrees in current repo
- `worktree-remove <path>` - Cleanup before removing worktree
- `conductor-init <name> [port]` - Initialize project for Conductor

## 😔Manual installation

- [zsh-notify](https://github.com/eirvandelden/zsh-notify)
  - Running `git clone https://github.com/eirvandelden/zsh-notify ~/.zsh-notify/`
- [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-autosuggestions)
  - Running `git clone https://github.com/zsh-users/zsh-autosuggestions.git ~/.zsh-autosuggestions/`
- [solarized](http://ethanschoonover.com/solarized)
- **terminal notifier** `brew install terminal-notifier`

### puma-dev

Configure puma-dev with:

```
sudo puma-dev -setup
puma-dev -install -d test:localhost:WORK.test:WORK.localhost -install-port 9280 -install-https-port 928
```

### Sensible OS X defaults

When setting up a new Mac, you may want to set some sensible OS X defaults:

    ./.macos
