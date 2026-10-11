# Intent: Register the journal_administration MCP server in Claude Code and Codex

Author: Etienne van Delden. Status: accepted. Type: chore.

## Problem

The journal_administration app now answers Model Context Protocol requests at `/mcp`, on the home network host `finances.home.arpa`, authenticated with a per-user `assistant_token` sent as a Bearer header. Neither Claude Code nor Codex on this machine know about it yet, so Etienne cannot ask either assistant to read the books, file a transaction, or check a budget.

## Proposed outcome

Starting a fresh Claude Code or Codex session on this machine, the journal server is reachable the same way email, fizzy and homeassistant already are: Claude after running the documented one-time `claude mcp add` command, Codex automatically once dotfiles are stowed. The token travels only through 1Password and shell env expansion, never in a committed file.

## Affected users and systems

Etienne, on this machine only. Claude Code's user-scope MCP registration (`~/.claude.json`, not dotfiles-managed). Codex's `codex/.codex/config.toml` (dotfiles-managed, applied by stow). The 1Password secrets template at `secrets/.config/secrets/1password.env`, consumed by the `unlock` alias.

## Constraints

- No plaintext secret in the repo. The 1Password mapping file holds only an `op://` reference.
- Claude has no `bearer_token_env_var` equivalent, so its registration is the same one-time imperative command already used for email, fizzy and homeassistant, documented in HEADROOM.md rather than applied by stow — a live Claude session rewrites `~/.claude.json` and would drop a dotfiles-managed version anyway.
- Codex's side is declarative, in `codex/.codex/config.toml`, alongside the three existing home servers.
- Follow the existing three-server pattern exactly rather than inventing a new shape: same env-var-expansion approach as email/fizzy/homeassistant, not TREK's OAuth flow — journal_administration uses a static bearer token, not a login screen.

## In scope

- `codex/.codex/config.toml`: add a `[mcp_servers.journal]` block — `url = "http://finances.home.arpa/mcp"`, `bearer_token_env_var = "JOURNAL_ASSISTANT_TOKEN"` — next to the existing email, fizzy and homeassistant blocks. No per-tool `approval_mode` override.
- `claude/.claude/HEADROOM.md`: extend the "Home MCP servers" section's heading and example block to include journal, with its own `claude mcp add --scope user --transport http journal http://finances.home.arpa/mcp --header 'Authorization: Bearer ${JOURNAL_ASSISTANT_TOKEN}'` line.
- `secrets/.config/secrets/1password.env`: add `JOURNAL_ASSISTANT_TOKEN=op://Familie/JournalAdministration/assistant_token`.

## Out of scope

- Creating the 1Password item or populating the actual `assistant_token` value — Etienne does this himself in 1Password, outside the dotfiles repo.
- Running the one-time `claude mcp add` command on this machine — documented, not executed as part of this change, same as the existing three servers.
- Per-tool `approval_mode` gates on any journal tool. Etienne reviewed the six write tools (`add_account_alias`, `charge_to_appropriation`, `set_appropriation`, `set_transaction_category`, `set_budget_amount`, `start_budget` — the last one self-declaring `destructive_hint: true`) and chose to run all of them freely, matching the stance the app's own tool annotations already take.
- Any change to the journal_administration app itself.
- `claude/.claude/settings.json` and `codex/.codex/rules/default.rules` — checked, neither references the existing home MCP servers by name, so neither needs a change here.

## Acceptance criteria

- `codex/.codex/config.toml` declares a `[mcp_servers.journal]` block pointing at `http://finances.home.arpa/mcp` with `bearer_token_env_var = "JOURNAL_ASSISTANT_TOKEN"`, sitting next to the email, fizzy and homeassistant blocks, with no tool-level override.
- HEADROOM.md's "Home MCP servers" section names journal alongside email, fizzy and homeassistant, and its command block includes the one-time `claude mcp add --scope user --transport http journal http://finances.home.arpa/mcp --header 'Authorization: Bearer ${JOURNAL_ASSISTANT_TOKEN}'` line.
- `secrets/.config/secrets/1password.env` maps `JOURNAL_ASSISTANT_TOKEN` to `op://Familie/JournalAdministration/assistant_token`, and the diff contains no plaintext secret anywhere.
- Once Etienne has created the 1Password item and stowed the change, running `unlock` in a fresh shell and then `echo $JOURNAL_ASSISTANT_TOKEN` prints the real token rather than the literal `${JOURNAL_ASSISTANT_TOKEN}` text.

## Open questions

None.
