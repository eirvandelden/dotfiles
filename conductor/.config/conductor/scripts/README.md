# Conductor Workspace Scripts

Generic scripts for personal AI workspace lifecycle management in Conductor. These scripts are used by personal projects running as AI workspaces at `https://ai.<project>.localhost`.

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

Called when Conductor creates a new workspace. Runs `worktree-setup` to configure Stow symlinks and puma-dev. No database or dependency setup — handle those in your project's own setup steps if needed.

### `run`

Starts the development server on port **3010**, matching the `ai.<project>.localhost → 3010` Caddy route.

Detects project type automatically:

**Rails projects:**
1. Prefers `bin/dev` (Rails 7+ convention)
2. Falls back to `Procfile.dev` with foreman
3. Falls back to `bundle exec rails server`

**Node projects:**
1. Looks for `npm run dev`
2. Falls back to `npm run start:dev`
3. Falls back to `npm start`

Port is fixed at 3010. Work projects with different ports use separate scripts in `dotfiles-work`.

### `archive`

Called before Conductor removes a workspace. Removes the `.context/` directory (AI-generated workspace files) and runs `worktree-remove` to clean up puma-dev, Caddy config, and Stow symlinks.

## Caddy routing

Personal AI workspaces are routed via the public dotfiles Caddyfile:

```
ai.*.localhost  →  127.0.0.1:3010   (personal AI workspaces, this script)
```

Work project routes (caren, ons-client) live in `dotfiles-work`.

## Customization

These scripts are meant to be copied and customized per-project. After copying:

1. Edit `bin/setup` to add project-specific setup steps
2. Edit `bin/run` to adjust server startup if your project needs a different port or command
3. Edit `bin/archive` to add any additional cleanup steps

## Troubleshooting

See the main worktree-tools README for detailed troubleshooting:

```bash
cat ~/.config/git/worktree-tools/README.md
```

Common issues:
- **Stow conflicts**: Make sure `.worktree-local/` exists and files are symlinked
- **Wrong port**: Verify the `ai.<project>.localhost` Caddy block routes to 3010
