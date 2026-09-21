---
created: 2026-09-18T14:12:19Z
branch: ai/home-assistant-mcp-server
trigger: manual
restored: false
topic: home-assistant-mcp
---

# Handoff: Home Assistant MCP

## Goal

Read and control Home Assistant from Codex and Claude Code, including creating automations,
scenes and scripts.

## What changed since the earlier plan

An earlier plan called for two MCP servers: Home Assistant's official `mcp_server` integration for
entity control, and `voska/hass-mcp` for creating automations. Both premises turned out to be
wrong, and that plan document is gone (the workspace holding it was deleted):

- The official integration documents that it **cannot** create automations or scenes.
- `voska/hass-mcp` cannot either. Its `app/hass.py` only reaches `/api/states`, `/api/services`,
  `/api/history` and `/api/error_log` — there is no write against Home Assistant's config API. Its
  `create_automation` is a guided conversation that ends with YAML you paste in yourself.

Replaced by a single server, [homeassistant-ai/ha-mcp](https://github.com/homeassistant-ai/ha-mcp),
which does have `ha_config_set_automation`, plus scenes, scripts, helpers, dashboards, history and
automation traces.

## Key decisions

- **One server, not two.** ha-mcp covers everything the official integration does and adds the
  config writes that were the point of the exercise.
- **A gate in front of it.** ha-mcp's standalone HTTP mode does support OAuth, but that means a
  consent-form flow per user. `~/.codex/config.toml` is a symlink into this repo, so a secret URL
  (ha-mcp's other option) would land in a tracked file. A Caddy gate checking a shared bearer token
  gives one user the same config shape as the other home MCP servers instead: a plain URL plus
  `bearer_token_env_var`, no consent flow to drive from a headless agent.
- **Deployed like fizzy-mcp.** Kamal, the same registry and build host as the other home MCP
  servers, kamal-proxy host `ha-mcp.home.arpa`. The gate is the Kamal app; ha-mcp is a Kamal
  accessory beside it, never exposed through the proxy. Exact hosts and topology:
  [eirvandelden/ha-mcp](https://github.com/eirvandelden/ha-mcp) (private — it documents the
  internal network layout, so it stays out of this public repo).
- **Token from 1Password.** `HOME_ASSISTANT_MCP_TOKEN` resolves through `unlock`, exactly like the
  email and fizzy tokens. Run `unlock` before `codex` or `claude`, or the server gets a 401.
- **Approval prompts on the tools that remove, overwrite, or reconfigure Home Assistant, or that
  could change what the agent is allowed to do next** (installing add-ons, editing the security
  policy, defining new tools). See the `[mcp_servers.home-assistant.tools.*]` blocks in
  `codex/.codex/config.toml` for the current list — not just the handful with obvious names like
  "remove" or "delete"; `ha_call_service` and `ha_bulk_control` can reach the same effects
  generically, so they are gated too. Creating a new automation stays frictionless, since that is
  the daily use and a mistake there is visible and revertible in the Home Assistant UI.
  Overwriting an *existing* automation, script, scene or dashboard by id is not the same kind of
  mistake — the previous version isn't in the UI to revert to — so treat `ha_config_set_*` calls
  against an id you didn't just create with more care than a plain create.

## Where the work lives

- [eirvandelden/ha-mcp](https://github.com/eirvandelden/ha-mcp) (private) — the deploy repository:
  Caddyfile, Dockerfile, `config/deploy.yml`, `.kamal/secrets`, and two checks
  (`test/local_gate.sh`, `test/acceptance.sh`).
- This branch — Codex server entry with its approval gates, the 1Password mapping line, the Claude
  Code registration block in `claude/.claude/HEADROOM.md`.

## State

Deployed and working. The gate is live at `ha-mcp.home.arpa`: an unauthenticated request gets
`401`, the right bearer token reaches through to ha-mcp, and `test/acceptance.sh` in the deploy
repo passes all four checks. `codex mcp list` shows `home-assistant` connected. Not yet done:
registering the server with Claude Code, and creating a real automation through it to confirm it
lands in Home Assistant's UI.

## Next steps

1. `unlock`, then register with Claude Code (see `claude/.claude/HEADROOM.md` for the exact
   command) — no live `claude` session running, or it rewrites `~/.claude.json` and drops the
   change.
2. Confirm both agents see it: `codex mcp list` and Claude Code's `/mcp`.
3. Ask for an automation and confirm it appears under Settings → Automations.
