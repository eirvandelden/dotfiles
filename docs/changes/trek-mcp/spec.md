# Spec: Use TREK from Claude Code and Codex

From `intent.md` (2026-09-29). Status: accepted.

## Requirements

- `codex/.codex/config.toml` has a `[mcp_servers.trek]` entry with `url = "https://trips.vandelden.family/mcp"` and no bearer token setting, so Codex uses OAuth (`codex mcp login trek`).
- Every TREK tool that deletes or removes something has `approval_mode = "approve"` in Codex.
- `HEADROOM.md` documents Claude Code's one-time registration (`claude mcp add --scope user --transport http trek https://trips.vandelden.family/mcp`), that it must run with no Claude session open, and that login happens through `/mcp`.
- `HEADROOM.md` documents Codex's one-time `codex mcp login trek`.

## Design decisions

- OAuth with dynamic client registration, not the deprecated static `trek_` token and not a machine client: both clients refresh OAuth tokens themselves, neither can renew a `client_credentials` token.
- No `scopes` setting: scopes are picked on TREK's consent screen at login.
- The list of delete and remove tools comes from TREK's wiki (MCP-Tools-and-Resources, MCP-Addon-Tools), then is checked against the tool list the live server shows after login. Names in the config that the server does not have are removed; delete or remove tools the server has but the config misses are added.

## Integration points

- TREK on CT111, with `APP_URL` set (homelab-iac change `trek-app-url`).
- `~/.claude.json` (written by `claude mcp add`, not managed by dotfiles).
- Codex's OAuth credential store (written by `codex mcp login`).

## Acceptance criteria

- Codex's config points the `trek` server at `https://trips.vandelden.family/mcp` with no bearer token.
- Codex accepts the config: `codex mcp get trek` with this `config.toml` shows the TREK URL.
- In Codex, deleting a trip asks for approval first; so does every other TREK tool that deletes or removes something.
- After `codex mcp login trek`, Codex can list the user's trips.
- After following `HEADROOM.md`, Claude Code can list the user's trips.

---
Domain skills applied: None (dotfiles-maintenance rules on editing sources, not symlinks, apply).
