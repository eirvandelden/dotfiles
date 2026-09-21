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

## Home MCP servers (email, fizzy, home-assistant)

Same servers as `[mcp_servers.email]` / `[mcp_servers.fizzy]` / `[mcp_servers.home-assistant]` in
`codex/.codex/config.toml`.
Claude has no `bearer_token_env_var`, so the token comes from `${VAR}` expansion instead —
run `unlock` before `claude`, or the server sends the literal `${VAR}` text and gets a 401.

One-time registration (no claude session running — a live session rewrites `~/.claude.json`
and drops the change). Single quotes keep zsh from baking the token into the config:

```bash
claude mcp add --scope user --transport http email http://email-mcp.home.arpa/mcp \
  --header 'Authorization: Bearer ${MCP_EMAIL_SERVER_AUTH_TOKEN}'

claude mcp add --scope user --transport http fizzy http://fizzy-mcp.home.arpa/mcp \
  --header 'Authorization: Bearer ${FIZZY_PAT}'

claude mcp add --scope user --transport http home-assistant http://ha-mcp.home.arpa/mcp \
  --header 'Authorization: Bearer ${HOME_ASSISTANT_MCP_TOKEN}'
```

Home Assistant is deployed from `~/Developer/ha-mcp`: a token-checking gate in front of
[ha-mcp](https://github.com/homeassistant-ai/ha-mcp). ha-mcp's standalone HTTP mode does support
OAuth, but that means a consent-form flow per user; the gate gives one user a shared bearer token
in the same config shape as email and fizzy, with no consent flow to drive from a headless agent.
Codex gates every ha-mcp tool that removes, overwrites, or reconfigures Home Assistant, or that
could change what the agent is allowed to do next (installing add-ons, editing the security
policy, defining new tools) — see the `[mcp_servers.home-assistant.tools.*]` blocks in
`codex/.codex/config.toml` for the current list. Claude Code has no equivalent per-tool setting,
so there it relies on the usual permission prompts.
