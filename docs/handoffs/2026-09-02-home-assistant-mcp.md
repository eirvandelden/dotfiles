---
created: 2026-09-02
branch: ai/home-assistant-mcp-server
topic: home-assistant-mcp
---

# Handoff: Home Assistant MCP

## Goal

Read and control Home Assistant from Codex and Claude Code, including creating automations,
scenes and scripts.

## What changed since the 2026-09-01 plan

That plan called for two MCP servers: Home Assistant's official `mcp_server` integration for
entity control, and `voska/hass-mcp` for creating automations. Both premises turned out to be
wrong:

- The official integration documents that it **cannot** create automations or scenes.
- `voska/hass-mcp` cannot either. Its `app/hass.py` only reaches `/api/states`, `/api/services`,
  `/api/history` and `/api/error_log` — there is no write against Home Assistant's config API. Its
  `create_automation` is a guided conversation that ends with YAML you paste in yourself.

Replaced by a single server, [homeassistant-ai/ha-mcp](https://github.com/homeassistant-ai/ha-mcp),
which does have `ha_config_set_automation`, plus scenes, scripts, helpers, dashboards, history and
automation traces.

The old plan at `.context/plans/home-assistant-mcp-servers-voor-codex.md` is superseded, and was
lost anyway when the Conductor workspace holding it was deleted.

## Key decisions

- **One server, not two.** ha-mcp covers everything the official integration does and adds the
  config writes that were the point of the exercise.
- **A gate in front of it.** ha-mcp's HTTP mode has no inbound authentication — it authenticates
  by keeping its URL path secret. `~/.codex/config.toml` is a symlink into this repo, so a secret
  URL would land in a tracked file. A Caddy gate checking a shared bearer token gives the same
  config shape as the other home MCP servers instead: a plain URL plus `bearer_token_env_var`.
- **Deployed like fizzy-mcp.** Kamal, `registry.vandelden.family`, remote build on
  `192.168.1.102`, deploy to `192.168.1.101`, kamal-proxy host `ha-mcp.home.arpa`, `ssl: false`.
  The gate is the Kamal app; ha-mcp is a Kamal accessory beside it, never exposed through the
  proxy.
- **Token from 1Password.** `HOME_ASSISTANT_MCP_TOKEN` resolves through `unlock`, exactly like the
  email and fizzy tokens. Run `unlock` before `codex` or `claude`, or the server gets a 401.
- **Approval prompts on the irreversible tools only.** Removing automations, scenes, scripts,
  dashboards, devices and entities; writing raw YAML or files; reloading or restarting Home
  Assistant. Creating things stays frictionless — that is the daily use, and it is visible and
  revertible in the Home Assistant UI.

## Where the work lives

- `~/Developer/ha-mcp` — new repository: Caddyfile, Dockerfile, `config/deploy.yml`,
  `.kamal/secrets`, and two checks (`test/local_gate.sh`, `test/acceptance.sh`). Not yet committed.
- This branch — Codex server entry with its approval gates, the 1Password mapping line, the Claude
  Code registration block in `claude/.claude/HEADROOM.md`.

## State

The gate is proven on this machine: `test/local_gate.sh` runs Caddy against a stand-in for Home
Assistant and passes — no token is refused, a wrong token is refused, the right token reaches
through. Nothing is deployed yet, so `test/acceptance.sh` against `ha-mcp.home.arpa` still fails
at "could not resolve host".

## Next steps

1. Create a long-lived access token on an **admin** Home Assistant account.
2. Create the 1Password item `Familie/HomeAssistantMcp` with `KAMAL_REGISTRY_PASSWORD`,
   `HOMEASSISTANT_TOKEN` and `HA_MCP_GATE_TOKEN`.
3. Add the DNS record `ha-mcp.home.arpa` → `192.168.1.101`.
4. `kamal setup` from `~/Developer/ha-mcp`.
5. `HA_MCP_GATE_TOKEN=... test/acceptance.sh` — expect all checks green.
6. `unlock`, then `codex mcp list` and Claude Code's `/mcp` should both show it connected.
7. Ask for an automation and confirm it appears under Settings → Automations.
