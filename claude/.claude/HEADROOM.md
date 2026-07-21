# Headroom

Context compression layer for Claude Code sessions.

## Launch

```bash
headroom wrap claude                    # full integration (preferred)
headroom wrap claude -- --model opus    # pass flags through to claude
headroom unwrap claude                  # remove durable wrapping
```

## Meta commands

```bash
headroom stats                          # token savings
headroom update                         # self-update
headroom learn                          # mine session learnings → CLAUDE.md
```

## Semble (semantic code search MCP)

One-time registration after `install.sh` installs `semble[mcp]` via uv (`mcpServers` is not a
valid `settings.json` key, so this can't be dotfiles-managed):

```bash
claude mcp add --scope user semble uvx -- --from "semble[mcp]" semble
```
