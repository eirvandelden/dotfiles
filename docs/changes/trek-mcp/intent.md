# Intent: Use TREK from Claude Code and Codex

Author: Etienne van Delden. Status: accepted. Type: feature.

## Problem

Claude Code and Codex cannot read or change trips in TREK (trips.vandelden.family). TREK has a built-in MCP server at `https://trips.vandelden.family/mcp`, but neither client is configured to use it.

## Proposed outcome

Codex has TREK configured in `codex/.codex/config.toml`, and Claude Code's one-time registration is documented in `HEADROOM.md` next to email and fizzy. Both log in through TREK's OAuth consent screen once; no token lives in an environment variable and no separate MCP server is hosted.

## Affected users and systems

Claude Code and Codex on this machine. TREK on CT111.

## Constraints

- OAuth, not TREK's static `trek_` token: that token is deprecated and has unrestricted access.
- Claude's `mcpServers` cannot be managed from dotfiles; registration stays a documented one-time command, run with no Claude session open.
- In Codex, every TREK tool that deletes or removes something asks for approval first, as fizzy's delete tools do. Reads and other writes run without asking.

## Acceptance criteria

- Codex's config points the `trek` server at `https://trips.vandelden.family/mcp` with no bearer token or auth header.
- Codex accepts the config: `codex mcp get trek` with this `config.toml` shows the TREK URL.
- In Codex, deleting a trip asks for approval first; so do the other 9 tools listed in `plan.md`.
- After `codex mcp login trek`, Codex can list the user's trips.
- After following `HEADROOM.md`, Claude Code can list the user's trips.

## Open questions

None.
