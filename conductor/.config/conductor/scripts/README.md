# Conductor Workspace Scripts

These are generic, reusable scripts for Conductor workspace lifecycle management. Copy them into your project's `bin/` directory to enable Conductor integration.

## Quick Start

```bash
# In your project root
cp ~/.config/conductor/scripts/{setup,run,archive} bin/
chmod +x bin/{setup,run,archive}

# Create conductor.json
cat > conductor.json <<'JSON'
{
  "name": "myproject",
  "setup": "./bin/setup",
  "server": "./bin/run",
  "archive": "./bin/archive"
}
JSON
```

## Scripts

### `setup`

Called when Conductor creates a new workspace. This script:

1. **Runs worktree-setup** - Sets up Stow symlinks and puma-dev
2. **For Rails projects:**
   - Loads secrets from 1Password (via `unlock` or `secrets` command)
   - Configures workspace-specific database name
   - Writes `DATABASE_NAME` to `.env.local`
   - Runs `bundle install`
   - Creates and migrates database with `rails db:prepare`

**Personal projects** (non-Rails): Just runs worktree-setup

**Work projects** (Rails with database): Adds full Rails setup with isolated database

**Database naming pattern:**
- Format: `projectname_workspacename_development`
- Example: `myapp_feature-auth_development`
- Ensures no conflicts between workspaces

### `run`

Starts the development server. Intelligently detects project type:

**Rails projects:**
1. Prefers `bin/dev` (Rails 7+ convention)
2. Falls back to `Procfile.dev` with foreman
3. Falls back to `bundle exec rails server`

**Node projects:**
1. Looks for `npm run dev`
2. Falls back to `npm run start:dev`
3. Falls back to `npm start`

Always respects `CONDUCTOR_PORT` environment variable.

### `archive`

Called before Conductor removes a workspace. This script:

- **For Rails projects:** Drops the workspace-specific database
- **For other projects:** Does nothing (but required by Conductor)

Safe error handling - won't fail if database doesn't exist.

## Rails Database Configuration

For Rails projects, configure your `database.yml` to use the `DATABASE_NAME` environment variable:

```yaml
# config/database.yml
development:
  <<: *default
  database: <%= ENV.fetch("DATABASE_NAME", "myapp_development") %>
```

This allows each workspace to have its own isolated database.

## Shared Files Setup

Create a `.worktree-local/` directory in your project root (or let Conductor use `CONDUCTOR_ROOT_PATH`):

```bash
mkdir -p .worktree-local/rails/config
mkdir -p .worktree-local/rails/storage

# Copy Rails credentials key
cp config/master.key .worktree-local/rails/config/

# Create shared .env
cat > .worktree-local/rails/.env <<'EOF'
RAILS_ENV=development
# Add other shared environment variables here
EOF
```

Create `.worktree.yml` to enable Stow:

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

Add to `.gitignore`:

```
/.worktree-local/
/.env.local
```

## Environment Variables

These scripts use Conductor environment variables:

- `CONDUCTOR_PORT` - First port in a range of 10 consecutive ports
- `CONDUCTOR_ROOT_PATH` - Path to project root (one level above workspace)
- `CONDUCTOR_WORKSPACE_PATH` - Path to current workspace
- `CONDUCTOR_WORKSPACE_NAME` - Name of the workspace

## Customization

These scripts are meant to be copied and customized per-project. After copying:

1. Edit `bin/setup` to add project-specific setup steps
2. Edit `bin/run` to adjust server startup behavior
3. Edit `bin/archive` to add cleanup steps

The scripts are designed to work for most Rails and Node projects out of the box.

## Troubleshooting

See the main worktree-tools README for detailed troubleshooting:

```bash
cat ~/.config/git/worktree-tools/README.md
```

Common issues:
- **Missing secrets**: Install `unlock` or `secrets` command for 1Password integration
- **Database conflicts**: Ensure `DATABASE_NAME` is in `database.yml`
- **Stow conflicts**: Make sure `.worktree-local/` exists and files are symlinked
