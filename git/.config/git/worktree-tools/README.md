# Git Worktree Tools

Generic, reusable tooling for automating git worktree setup across Rails, Node, and generic projects.

## Overview

This toolkit automatically configures new git worktrees by:

1. **Symlinking shared files** from `.worktree-local/` using GNU Stow
2. **Configuring puma-dev** for Rails projects (enables `https://<name>.localhost` access)
3. **Integrating with Conductor** for seamless workspace creation
4. **Running automatically** via git `post-checkout` hook

**Key benefit:** Run `git worktree add feature-branch` and immediately start developing at `https://feature-branch.myproject.localhost` with all shared configuration files in place.

## Quick Start

### Prerequisites

```bash
# Required
brew install stow

# Optional (for Rails projects)
brew install puma-dev
```

### Basic Usage

1. **Install the dotfiles** (if not already done):
   ```bash
   cd ~/dotfiles
   stow git
   ```

2. **Create a worktree** - automation runs automatically:
   ```bash
   cd ~/Developer/myproject
   git worktree add feature-branch
   cd feature-branch
   # worktree-setup runs automatically via post-checkout hook!
   ```

3. **Access your app** (Rails with puma-dev):
   ```bash
   # Main worktree
   https://myproject.localhost

   # Feature worktree
   https://feature-branch.myproject.localhost
   ```

### Manual Usage

You can also run the tools manually:

```bash
# Setup current directory
worktree-setup

# Setup specific worktree
worktree-setup /path/to/worktree

# Setup all worktrees in current repo
worktree-setup-all

# Cleanup before removing worktree
worktree-remove /path/to/worktree
git worktree remove /path/to/worktree
```

## Configuration

### `.worktree.yml`

Create `.worktree.yml` in your repository root to customize behavior:

```yaml
project:
  name: myproject      # Required for puma-dev naming
  type: rails          # Optional: auto-detected (rails, node, generic)

stow:
  enabled: true
  packages:
    - ruby             # Stow packages to symlink
    - neovim
  target: ~            # Where to create symlinks (default: current directory)
  source_dir: ~/.worktree-local  # Where packages are stored

puma_dev:
  enabled: true
  name: myproject-feature  # Defaults to worktree directory name
  domain: test             # TLD for puma-dev (default: test)
  dir: ~/.puma-dev         # Puma-dev symlink directory
```

**Note:** Configuration is optional. Sensible defaults work for most Rails projects.

### `.worktree-local/` Directory

Create a `.worktree-local/` directory in your repository root (or in `CONDUCTOR_ROOT_PATH` for Conductor) to store files that should be shared across all worktrees.

Example structure:

```
.worktree-local/
├── rails/              # Package name (used with stow)
│   ├── .env           # Shared environment variables
│   ├── config/
│   │   └── master.key # Shared Rails credentials key
│   └── storage/       # Shared Active Storage files
└── node/
    └── .env.local     # Shared Node environment
```

Then enable stow in `.worktree.yml`:

```yaml
stow:
  enabled: true
  packages:
    - rails  # or 'node' for Node projects
```

## Architecture

### Three-Layer Design

1. **Ruby Library Modules** (`lib/*.rb`)
   - `common.rb` - Base functionality (logging, git helpers, Conductor detection)
   - `detect.rb` - Project type detection (Rails/Node/generic)
   - `config.rb` - Configuration loading and validation
   - `symlinker.rb` - GNU Stow integration
   - `puma_dev.rb` - Puma-dev symlink management

2. **Executable Scripts**
   - `worktree-setup` - Main orchestration (detect → config → stow → puma-dev)
   - `worktree-setup-all` - Bulk setup for all worktrees
   - `worktree-remove` - Cleanup (remove puma-dev, unstow packages)

3. **Git Hook Integration**
   - `post-checkout` - Runs `worktree-setup` automatically on new worktrees

### How It Works

1. **New worktree creation:**
   ```bash
   git worktree add feature-branch
   ```

2. **Git triggers `post-checkout` hook:**
   - Detects new worktree (old SHA is all zeros)
   - Calls `worktree-setup` automatically

3. **`worktree-setup` orchestrates:**
   - Detects project type (Rails/Node/generic)
   - Loads `.worktree.yml` or uses defaults
   - Symlinks packages via GNU Stow
   - Configures puma-dev (Rails only)

4. **Result:**
   - Shared files available (`.env`, `master.key`, etc.)
   - Development server accessible at `https://<name>.<project>.localhost`
   - Ready for immediate development!

## Conductor Integration

### Overview

Conductor is a Mac app for managing multiple coding agents in parallel. Each workspace is essentially a git worktree, so this tooling integrates seamlessly.

### Setup

1. **Initialize a project for Conductor:**
   ```bash
   cd ~/Developer/myproject
   conductor-init myproject 3000
   ```

   This creates:
   - `conductor.json` - Conductor configuration
   - `bin/conductor-setup` - Setup script (calls `worktree-setup`)
   - `script/server` - Universal server launcher

2. **Create `.worktree.yml`** (optional but recommended):
   ```yaml
   project:
     name: myproject

   stow:
     enabled: true
     packages:
       - rails

   puma_dev:
     enabled: true
   ```

3. **Create workspace in Conductor:**
   - Conductor will call `bin/conductor-setup`
   - `worktree-setup` will run automatically
   - Workspace is ready for development!

### Environment Variables

When running in Conductor, these variables are available:

- `CONDUCTOR_ROOT_PATH` - Path to the main repository
- `CONDUCTOR_WORKSPACE_PATH` - Path to the current workspace
- `CONDUCTOR_WORKSPACE_NAME` - Name of the workspace
- `CONDUCTOR_PORT` - Assigned port for this workspace

The tooling automatically detects Conductor and adjusts behavior:
- Uses `CONDUCTOR_ROOT_PATH/.worktree-local/` for shared files
- Uses `CONDUCTOR_PORT` for server and puma-dev
- Uses `CONDUCTOR_WORKSPACE_NAME` for puma-dev naming

## Puma-dev Integration

### URL Naming Pattern

- **Main worktree:** `https://myproject.localhost`
- **Feature worktree:** `https://feature-branch.myproject.localhost`
- **Conductor workspace:** `https://workspace-name.myproject.localhost`

### Port Assignment

- **Conductor:** Uses `CONDUCTOR_PORT` environment variable
- **Main worktree:** Uses base port from config (default: 3000)
- **Feature worktrees:** Uses hash-based stable port offset (base + hash % 1000)

### How It Works

1. Creates a symlink in `~/.puma-dev/` pointing to the worktree directory
2. Creates a `.pumadev` file in the worktree root with the assigned port
3. Puma-dev proxies `https://<name>.<domain>` to the specified port

## Troubleshooting

### Stow conflicts

**Problem:** Stow reports conflicts when symlinking files.

**Solution:**
- Remove conflicting files from the worktree
- Or adjust `.worktree.yml` to use a different target directory
- Or disable stow and manage symlinks manually

### Puma-dev not working

**Problem:** Can't access `https://<name>.localhost`

**Checklist:**
1. Is puma-dev installed? `brew install puma-dev`
2. Is puma-dev running? `puma-dev -V`
3. Is the symlink created? `ls -la ~/.puma-dev/`
4. Is the `.pumadev` file present? `cat .pumadev`
5. Check puma-dev logs: `tail -f ~/Library/Logs/puma-dev.log`

### Post-checkout hook not running

**Problem:** `worktree-setup` doesn't run automatically.

**Solution:**
1. Check if the hook is installed: `ls -la $(git config core.hooksPath || echo .git/hooks)/post-checkout`
2. If not, stow the git package: `cd ~/dotfiles && stow git`
3. Verify hook is executable: `chmod +x ~/.config/git/hooks/post-checkout`

### Configuration errors

**Problem:** `worktree-setup` fails with a config error.

**Solution:**
- Check `.worktree.yml` syntax (valid YAML)
- Ensure source directories exist
- Validate project name (lowercase, no spaces)
- Enable `DEBUG=1` for detailed output: `DEBUG=1 worktree-setup`

### GNU Stow not found

**Problem:** `error: GNU Stow is required but not installed`

**Solution:**
```bash
brew install stow
```

## Advanced Usage

### Custom Configuration Per Worktree

You can override configuration by creating `.worktree.yml` in individual worktrees (though this is rarely needed).

### Disabling Auto-Setup

To prevent the hook from running automatically:

```bash
export WORKTREE_AUTO_SETUP=0
git worktree add feature-branch
```

Or disable the hook entirely:

```bash
git config core.hooksPath /dev/null
```

### Using Without Git Hooks

You can use the tools standalone without the git hook:

```bash
# Just run worktree-setup manually after creating worktrees
git worktree add feature-branch
cd feature-branch
worktree-setup
```

## Development

### Running Tests

```bash
# Test common.rb
ruby -I. -r lib/common -e "include WorktreeTools::Helpers; log 'test'"

# Test detect.rb
ruby -I. -r lib/detect -e "puts WorktreeTools::ProjectDetector.new('.').detect!.project_type"

# Test config.rb
ruby -I. -r lib/config -e "puts WorktreeTools::WorktreeConfig.new('.').load!.inspect"
```

### Debugging

Enable verbose output:

```bash
DEBUG=1 worktree-setup
```

Enable git hook debugging:

```bash
LEFTHOOK_VERBOSE=1 git worktree add feature-branch
```

## Related Files

- `~/.config/git/hooks/post-checkout` - Git hook that triggers automation
- `~/.config/git/worktree-tools/` - This toolkit
- `~/.puma-dev/` - Puma-dev symlinks directory
- `.worktree.yml` - Per-project configuration (in repo root)
- `.worktree-local/` - Shared files directory (in repo root or Conductor root)

## Credits

Built for managing worktrees across:
- Personal development environments
- Conductor workspaces
- CI/CD environments

Replaces project-specific scripts with a generic, reusable solution.
