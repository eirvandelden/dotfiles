# Headroom

Context compression layer for Claude Code and Codex sessions.

## Claude

### Launch

```bash
headroom wrap claude                    # full integration (preferred)
headroom wrap claude -- --model opus    # pass flags through to claude
headroom unwrap claude                  # remove durable wrapping
```

### Meta commands

```bash
headroom stats                          # token savings
headroom update                         # self-update
headroom learn                          # mine session learnings → CLAUDE.md
```

### Semble (semantic code search MCP)

One-time registration after `install.sh` installs `semble[mcp]` via uv (`mcpServers` is not a valid `settings.json` key, so this can't be dotfiles-managed):

```bash
claude mcp add --scope user semble uvx -- --from "semble[mcp]" semble
```

### Home MCP servers (email, fizzy, homeassistant)

Same servers as `[mcp_servers.email]` / `[mcp_servers.fizzy]` / `[mcp_servers.homeassistant]` in `codex/.codex/config.toml`. Claude has no `bearer_token_env_var`, so the token comes from `${VAR}` expansion instead — run `unlock` before `claude`, or the server sends the literal `${VAR}` text and gets a 401.

One-time registration (no claude session running — a live session rewrites `~/.claude.json` and drops the change). Single quotes keep zsh from baking the token into the config:

```bash
claude mcp add --scope user --transport http email http://email-mcp.home.arpa/mcp \
  --header 'Authorization: Bearer ${MCP_EMAIL_SERVER_AUTH_TOKEN}'

claude mcp add --scope user --transport http fizzy http://fizzy-mcp.home.arpa/mcp \
  --header 'Authorization: Bearer ${FIZZY_PAT}'

claude mcp add --scope user --transport http homeassistant http://ha-mcp.home.arpa/mcp \
  --header 'Authorization: Bearer ${HA_MCP_GATE_TOKEN}'
```

### TREK MCP server

TREK (trips.vandelden.family) logs in through OAuth, so there is no token and no header.

One-time registration, with no Claude session running (a live session rewrites `~/.claude.json` and drops the change):

```bash
claude mcp add --scope user --transport http trek https://trips.vandelden.family/mcp
```

Then start `claude`, run `/mcp`, and log in once on TREK's consent screen.

## Codex

### Launch

```bash
headroom wrap codex                     # full integration (preferred)
headroom wrap codex -- --model opus     # pass flags through to codex
headroom unwrap codex                   # remove durable wrapping
```

### Meta commands

```bash
headroom stats                          # token savings
headroom update                         # self-update
headroom learn                          # mine session learnings
```

### TREK MCP login

One-time login. Pick the scopes on TREK's consent screen. The config is in `codex/.codex/config.toml`.

```bash
codex mcp login trek
```
