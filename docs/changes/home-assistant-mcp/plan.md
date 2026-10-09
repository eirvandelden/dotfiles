# Plan: Home Assistant MCP in Claude and Codex

From `intent.md` (2026-10-06). Status: accepted.

## Design decisions

- Codex gates the server with `default_tools_approval_mode = "writes"` on `[mcp_servers.homeassistant]`. In Codex 0.160.1 (`openai/codex` tag `rust-v0.160.1`, `core/src/mcp_tool_call.rs`), `writes` asks for approval unless the tool sets `readOnlyHint=true`. ha-mcp 8.4.0 (the image `eirvandelden/ha-mcp` deploys) sets `readOnlyHint=true` on all 33 read tools and on no write tool. So reads run freely, and every write asks: `ha_call_service` (lights), `ha_bulk_control`, `ha_config_set_*` / `ha_config_remove_*` for automations, scenes and scripts, and the other 38 write tools and 7 mixed tools.
- No per-tool `approval_mode` entries. In Codex, `approval_mode = "approve"` means "never ask", not "ask". The `writes` mode also hides the "Allow and don't ask me again" button, which only `auto` mode shows. That button writes `approval_mode = "approve"` for the tool into `config.toml`, which is this repository's file.
- The 1Password reference goes in the personal mapping `secrets/.config/secrets/1password.env`, beside the email one. The loader reads that file from the personal account `vandelden`, where the `Familie` vault lives.
- `HEADROOM.md` extends the existing "Home MCP servers" section: one more name in the heading and the intro, one more `claude mcp add` command. The existing sentence "run `unlock` before `claude`, or the server sends the literal `${VAR}` text and gets a 401" covers acceptance criterion 5 for Claude.
- Acceptance criterion 5 differs for Codex: with `HA_MCP_GATE_TOKEN` unset, Codex does not send a request. It reports `Environment variable HA_MCP_GATE_TOKEN for MCP server 'homeassistant' is not set`, and the session continues without the Home Assistant tools. Claude sends the literal `${HA_MCP_GATE_TOKEN}` and gets the 401. Both mean no access without `unlock`.
- Tests read `config.toml` and `HEADROOM.md` as text, the same way `test/guard_parity_test.rb` reads `config.toml`. Ruby has no TOML parser in its standard library, and a TOML gem is a new dependency.

## Integration points

- 1Password: item `Familie/HomeAssistantMcp`, field `HA_MCP_GATE_TOKEN`, personal account. Read only.
- `secrets` / `unlock`: `zsh/.config/zsh/functions/secrets.zsh` and the `unlock` alias in `zsh/.config/zsh/aliases.zsh`. No change.
- Codex 0.160.1 MCP client: `bearer_token_env_var` reads the variable at session start and sends `Authorization: Bearer <value>`.
- The gate at `http://ha-mcp.home.arpa/mcp` (repository `eirvandelden/ha-mcp`, Caddy in front of `ghcr.io/homeassistant-ai/ha-mcp:8.4.0`). No change.
- Claude user-scope MCP config in `~/.claude.json`. Not in the repository; Etienne runs the documented command.
- CI: `.github/workflows/dotfiles-tests.yml` runs every `test/*_test.rb`. No change; the new test file is picked up.
- `codex/.codex/HEADROOM.md` is a symlink to `claude/.claude/HEADROOM.md`. Edit the source only.

## Files that change

- `secrets/.config/secrets/1password.env` — add `HA_MCP_GATE_TOKEN=op://Familie/HomeAssistantMcp/HA_MCP_GATE_TOKEN` under the email line.
- `codex/.codex/config.toml` — add this table after the last `[mcp_servers.fizzy.tools.*]` table and before `[mcp_servers.node_repl]`:

  ```toml
  [mcp_servers.homeassistant]
  url = "http://ha-mcp.home.arpa/mcp"
  bearer_token_env_var = "HA_MCP_GATE_TOKEN"
  # Ask before every tool ha-mcp does not mark read-only: service calls, automations, scenes, scripts.
  default_tools_approval_mode = "writes"
  ```

- `claude/.claude/HEADROOM.md` — heading `### Home MCP servers (email, fizzy, homeassistant)`; intro names `[mcp_servers.homeassistant]` too; add to the code block:

  ```bash
  claude mcp add --scope user --transport http homeassistant http://ha-mcp.home.arpa/mcp \
    --header 'Authorization: Bearer ${HA_MCP_GATE_TOKEN}'
  ```

- `test/secrets_loader_test.rb` — one new test that runs the repository's real personal mapping through the loader.
- `test/home_assistant_mcp_test.rb` — new file: the Codex config and `HEADROOM.md` checks.

## Order of work

1. Write `SecretsLoaderTest#test_the_personal_mapping_unlocks_the_home_assistant_gate_token`. Run `ruby -Itest test/secrets_loader_test.rb -n test_the_personal_mapping_unlocks_the_home_assistant_gate_token`. Watch it fail: no `export HA_MCP_GATE_TOKEN=` line.
2. Add the mapping line to `1password.env`. Run the test green, then the whole `test/secrets_loader_test.rb`. Commit: test and mapping together.
3. Write the three Codex tests in `test/home_assistant_mcp_test.rb`. Run the file. Watch them fail: no `[mcp_servers.homeassistant]` table.
4. Add the table to `codex/.codex/config.toml`. Run the file green.
5. Check that Codex accepts the config: copy the worktree's `codex/.codex/config.toml` into a scratch directory, then run `CODEX_HOME=<scratch> codex mcp get homeassistant --json` and `CODEX_HOME=<scratch> codex mcp list`. Expect no config error and the `homeassistant` server with its URL and `HA_MCP_GATE_TOKEN`. Commit: test file and config.
6. Write the two `HEADROOM.md` tests in `test/home_assistant_mcp_test.rb`. Watch them fail: no section names `homeassistant`.
7. Edit `claude/.claude/HEADROOM.md`. Run the file green. Commit: tests and doc.
8. Run every test as CI does: `for file in test/*_test.rb; do ruby -Itest "$file" || break; done`. Let lefthook's pre-commit linters run on each commit and fix every finding. Re-read the full diff against `main`.
9. Check the gate refuses a caller without a token: `curl -s -o /dev/null -w '%{http_code}\n' -X POST http://ha-mcp.home.arpa/mcp`. Expect `401`.
10. Push the branch and open the pull request. The live checks in `## Proof` run after merge, because the config goes live only from the main checkout.

## Risks

- `writes` trusts ha-mcp's `readOnlyHint`. A future image with a write tool marked read-only would run that tool without asking. The image is pinned at 8.4.0 in `eirvandelden/ha-mcp`; re-check the annotations when that pin moves.
- Rejected: `default_tools_approval_mode = "prompt"` plus 33 `approval_mode = "approve"` read entries. It is long, and every new read tool would prompt until listed.
- Rejected: no setting (`auto`). The prompts are the same today, but its "Allow and don't ask me again" button writes `approval_mode = "approve"` into this repository's `config.toml` and silently stops a write tool asking.
- The 7 mixed tools (`ha_manage_backup`, `ha_manage_updates`, `ha_manage_app`, `ha_manage_energy_prefs`, `ha_manage_pipeline`, `ha_manage_radio`, `ha_manage_theme`) ask even for their read actions. Accepted.
- The main checkout has uncommitted edits to `codex/.codex/config.toml`. `git pull` refuses to update a file with local changes, so Etienne must commit or set those edits aside before the pull. The intent leaves those edits out of scope.
- The Codex desktop app rewrites `~/.codex/config.toml`. The email and fizzy tables survive those rewrites, so this table should too.
- A Codex or Claude process started outside an `unlock`ed shell (for example the desktop app from the Dock) has no token. The Home Assistant server then fails to start, as email and fizzy do today.
- No step prints the token. Checks test that the variable is set, never its value.
- Found, not changed: the fizzy write tools carry `approval_mode = "approve"`, which means Codex never asks before them. A separate change can decide that.

## Out of scope

- Deploying or changing the ha-mcp server or its gate.
- Claude permission rules for the Home Assistant tools.
- Automating `claude mcp add` in `install.sh`, or a Claude plugin that ships the server.
- Running the Claude registration command on this machine.
- The failing GitHub MCP server (401) and the uncommitted edits in the main checkout.
- Moving or changing the email or fizzy setup, including the fizzy `approve` entries.

## Proof

- After `unlock`, the shell has `HA_MCP_GATE_TOKEN` set → `test/secrets_loader_test.rb` `test_the_personal_mapping_unlocks_the_home_assistant_gate_token`; live: `unlock && [[ -n $HA_MCP_GATE_TOKEN ]] && echo set`.
- A new Codex session after `unlock` lists the tools and reads an entity's state without approval → `test/home_assistant_mcp_test.rb` `test_codex_reaches_home_assistant_through_the_gate_with_the_unlocked_token`; live, after merge and pull: `unlock`, start `codex`, `/mcp` lists `homeassistant` tools, ask for the state of an entity (for example `sun.sun`), and `ha_get_state` runs with no prompt.
- Turning on a light, and creating, editing or deleting an automation, scene or script, asks first → `test/home_assistant_mcp_test.rb` `test_codex_asks_before_every_home_assistant_tool_that_is_not_read_only` and `test_no_home_assistant_tool_skips_the_approval_prompt`; live: ask Codex to turn on a light, then to create an automation; each shows an approval prompt; decline both.
- After the registration command, a new Claude session after `unlock` shows the server connected and reads an entity's state → `test/home_assistant_mcp_test.rb` `test_headroom_registers_home_assistant_for_claude_with_the_token_left_unexpanded`; live: Etienne runs the command with no Claude session open, `grep -c 'Bearer \${HA_MCP_GATE_TOKEN}' ~/.claude.json` prints `1`, then `unlock`, start `claude`, `/mcp` shows `homeassistant` connected, ask for the state of an entity.
- Without `unlock`, the gate answers 401, and `HEADROOM.md` says to run `unlock` first → `test/home_assistant_mcp_test.rb` `test_headroom_says_to_unlock_before_starting_claude_for_home_assistant`; live: the `curl` in step 9 prints `401`; `env -u HA_MCP_GATE_TOKEN codex` reports the variable is not set for `homeassistant`.

Per changed file, the unit tests expected:

- `secrets/.config/secrets/1password.env`: `SecretsLoaderTest#test_the_personal_mapping_unlocks_the_home_assistant_gate_token` (exports `HA_MCP_GATE_TOKEN`, reads `op://Familie/HomeAssistantMcp/HA_MCP_GATE_TOKEN --account vandelden`).
- `codex/.codex/config.toml`: `HomeAssistantMcpTest#test_codex_reaches_home_assistant_through_the_gate_with_the_unlocked_token` (URL and `bearer_token_env_var`), `#test_codex_asks_before_every_home_assistant_tool_that_is_not_read_only` (`default_tools_approval_mode = "writes"`), `#test_no_home_assistant_tool_skips_the_approval_prompt` (no `[mcp_servers.homeassistant.tools.*]` table sets `approval_mode = "approve"`).
- `claude/.claude/HEADROOM.md`: `HomeAssistantMcpTest#test_headroom_registers_home_assistant_for_claude_with_the_token_left_unexpanded` (the `claude mcp add ... homeassistant http://ha-mcp.home.arpa/mcp` command with the single-quoted `'Authorization: Bearer ${HA_MCP_GATE_TOKEN}'` header), `#test_headroom_says_to_unlock_before_starting_claude_for_home_assistant` (the `###` section that names `homeassistant` tells the reader to run `unlock` before `claude`).

Test setup: the loader test reuses `SecretsLoaderTest`'s stub `op` and temporary `XDG_CONFIG_HOME`, and copies the repository's real `1password.env` into it. The other tests read repository files as text: a small helper splits `config.toml` into `[table]` sections and `HEADROOM.md` into `###` sections. No network, no 1Password, no real token.

---
Domain skills applied: dotfiles-maintenance (edit stow sources, never symlink targets; `HEADROOM.md` is shared through a symlink), dependencies (no TOML gem).
