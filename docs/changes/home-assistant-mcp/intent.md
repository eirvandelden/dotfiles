# Intent: Home Assistant MCP in Claude and Codex

Author: Etienne van Delden de la Haije. Status: accepted. Type: chore.

## Problem

Claude Code and Codex sessions cannot read or control Home Assistant. The Home Assistant MCP server runs at `http://ha-mcp.home.arpa/mcp` behind a gate that wants a bearer token, but neither tool knows the server exists, and `unlock` does not load the gate token.

## Proposed outcome

After `unlock`, every new Codex session has the Home Assistant tools. Every new Claude session has them too, once the documented one-time registration command has run on that machine. Codex runs reads freely and asks before anything that changes Home Assistant.

## Affected users and systems

- Etienne, in Claude Code and Codex sessions on any machine that uses these dotfiles.
- `unlock` / `secrets`, through the personal 1Password mapping file.
- The Codex config (`codex/.codex/config.toml`).
- The Claude MCP setup notes (`claude/.claude/HEADROOM.md`).
- The 1Password item `Familie/HomeAssistantMcp`, field `HA_MCP_GATE_TOKEN` — read, not changed.

## Constraints

- The gate token never lands in the repository or in `~/.claude.json`; only its 1Password reference and the literal `${HA_MCP_GATE_TOKEN}` text do.
- Follow the existing email and fizzy pattern: the token comes from `unlock`, Codex reads it through `bearer_token_env_var`, Claude through `${VAR}` header expansion.
- `~/.claude.json` is not in the dotfiles and stays that way; the Claude side is a documented one-time command.
- Home Assistant is a personal system: its token mapping goes in the personal dotfiles, never in `dotfiles-work`.
- Dotfiles changes go live only once merged and pulled into the main checkout, which has unrelated uncommitted edits to `codex/.codex/config.toml` and `claude/.claude/settings.json`.

## In scope

- Load the gate token through `unlock`.
- Register the Home Assistant server as `homeassistant` for Codex, with approval required for every tool that changes Home Assistant.
- Document the one-time Claude registration command, also as `homeassistant`, next to the email and fizzy ones.

## Out of scope

- Deploying or changing the ha-mcp server or its gate.
- Claude permission rules for the Home Assistant tools; Claude keeps its default permission handling, as for email and fizzy.
- Automating `claude mcp add` in `install.sh`, or a Claude plugin that ships the server.
- Running the Claude registration command on this machine; Etienne runs it with no Claude session open.
- The failing GitHub MCP server (401) and the uncommitted edits in the main checkout.
- Moving the email or fizzy setup.

## Acceptance criteria

- After `unlock`, the shell has `HA_MCP_GATE_TOKEN` set to the gate token.
- A new Codex session started after `unlock` lists the Home Assistant tools and reads the state of an entity without asking for approval.
- In that Codex session, turning on a light asks for approval before it runs; so does creating, editing or deleting an automation, scene or script.
- After the documented registration command has run once, a new Claude session started after `unlock` shows the Home Assistant server as connected and reads the state of an entity.
- A session started without `unlock` gets a 401 from the gate; `HEADROOM.md` says to run `unlock` first.

## Open questions

None.
