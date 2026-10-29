# MCP

One-time MCP server setup for Claude Code and Codex, and the Codex daemon rules after `unlock`.

## Claude

### Semble (semantic code search MCP)

One-time registration after `install.sh` installs `semble[mcp]` via uv (`mcpServers` is not a valid `settings.json` key, so this can't be dotfiles-managed):

```bash
claude mcp add --scope user semble uvx -- --from "semble[mcp]" semble
```

### Home MCP servers (email, fizzy, homeassistant, journal)

Same servers as `[mcp_servers.email]` / `[mcp_servers.fizzy]` / `[mcp_servers.homeassistant]` / `[mcp_servers.journal]` in `codex/.codex/config.toml`. Claude has no `bearer_token_env_var`, so the token comes from `${VAR}` expansion instead — run `unlock` before `claude`, or the server sends the literal `${VAR}` text and gets a 401.

One-time registration (no claude session running — a live session rewrites `~/.claude.json` and drops the change). Single quotes keep zsh from baking the token into the config:

```bash
claude mcp add --scope user --transport http email http://email-mcp.home.arpa/mcp \
  --header 'Authorization: Bearer ${MCP_EMAIL_SERVER_AUTH_TOKEN}'

claude mcp add --scope user --transport http fizzy http://fizzy-mcp.home.arpa/mcp \
  --header 'Authorization: Bearer ${FIZZY_PAT}'

claude mcp add --scope user --transport http homeassistant http://ha-mcp.home.arpa/mcp \
  --header 'Authorization: Bearer ${HA_MCP_GATE_TOKEN}'

claude mcp add --scope user --transport http journal http://finances.home.arpa/mcp \
  --header 'Authorization: Bearer ${JOURNAL_ASSISTANT_TOKEN}'
```

### TREK MCP server

TREK (trips.vandelden.family) logs in through OAuth, so there is no token and no header.

One-time registration, with no Claude session running (a live session rewrites `~/.claude.json` and drops the change):

```bash
claude mcp add --scope user --transport http trek https://trips.vandelden.family/mcp
```

Then start `claude`, run `/mcp`, and log in once on TREK's consent screen.

## Codex

### Unlocked sessions

After `unlock`, `codex` runs in-process (`--no-daemon`) through `zsh/.config/zsh/unlocked-bin/codex`, off the shared daemon, so its sessions do not show in `codex agents`.

Never start the background server from an unlocked session ("Start background server" in the agents overview, or a handoff to it). When no shared daemon runs, Codex starts it from that session's environment, and every later Codex session and ChatGPT.app agent then sees the secrets. To clear them, stop the daemon from a locked shell: `codex app-server daemon stop`. This interrupts the work that runs on it. The next `codex` from a locked shell starts a new daemon with that shell's environment.

### TREK MCP login

One-time login. Pick the scopes on TREK's consent screen. The config is in `codex/.codex/config.toml`.

```bash
codex mcp login trek
```
