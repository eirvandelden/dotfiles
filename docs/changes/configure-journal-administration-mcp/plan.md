# Plan: Register the journal_administration MCP server in Claude Code and Codex

From `intent.md` (2026-10-11). Status: accepted.

## Design decisions

- Codex block, placed directly after `[mcp_servers.homeassistant]` and before `[mcp_servers.node_repl]` in `codex/.codex/config.toml`:

  ```toml
  [mcp_servers.journal]
  url = "http://finances.home.arpa/mcp"
  bearer_token_env_var = "JOURNAL_ASSISTANT_TOKEN"
  # Run every journal tool, writes included, without asking.
  default_tools_approval_mode = "approve"
  ```

- `default_tools_approval_mode = "approve"` is added, beyond the two lines the intent lists. Etienne chose this on 2026-10-11 during planning. Reason: `approve` asks for no tool; `writes` asks for every tool not marked read-only; `auto` (no setting) decides per tool from the tool's annotations, so some journal writes would still go to the automatic reviewer (`approvals_reviewer = "auto_review"`). That contradicts "run all of them freely". `auto` also shows an "Allow and don't ask me again" button that writes `approval_mode = "approve"` tables into this repository's `config.toml`. `approve` at server level matches the intent's stance and TREK's existing default. No `[mcp_servers.journal.tools.*]` tables, so the intent's "no tool-level override" still holds.
- `HEADROOM.md` extends the existing "Home MCP servers" section: heading becomes `### Home MCP servers (email, fizzy, homeassistant, journal)`, the intro sentence names `[mcp_servers.journal]` too, and the bash block gets one more command, after homeassistant:

  ```bash
  claude mcp add --scope user --transport http journal http://finances.home.arpa/mcp \
    --header 'Authorization: Bearer ${JOURNAL_ASSISTANT_TOKEN}'
  ```

  The existing sentence "run `unlock` before `claude` …" already covers journal.
- `secrets/.config/secrets/1password.env` gets `JOURNAL_ASSISTANT_TOKEN=op://Familie/JournalAdministration/assistant_token` beside the `HA_MCP_GATE_TOKEN` line. The loader reads the personal mapping from the `vandelden` account, where the `Familie` vault lives. The implementer must not print the file; append or edit by exact line only.
- Tests: a new `test/journal_mcp_test.rb`, shaped like `test/home_assistant_mcp_test.rb` (files read as text, no TOML gem), plus one new test in `test/secrets_loader_test.rb`. The three small helpers (`setting`, `codex_tables`, `headroom_section_naming`) are copied, not extracted into a shared module: extracting is a refactor of an unrelated test, out of scope here.

## Integration points

- Codex reads `~/.codex/config.toml`, a stow link to `codex/.codex/config.toml`. Codex reads the token from `JOURNAL_ASSISTANT_TOKEN`; unset, it reports the variable is missing and starts without the journal tools.
- Claude: `~/.claude.json`, written by the one-time `claude mcp add` command Etienne runs himself with no Claude session open. Not dotfiles-managed.
- `unlock` / `secrets`: `zsh/.config/zsh/functions/secrets.zsh` and the `unlock` alias. No change.
- 1Password item `Familie/JournalAdministration`, field `assistant_token`, personal account. Etienne creates it. Read only.
- The journal_administration app at `http://finances.home.arpa/mcp`. No change.

## Files that change

- `test/journal_mcp_test.rb` — new; proves the Codex block and the HEADROOM command.
- `codex/.codex/config.toml` — add the `[mcp_servers.journal]` block above.
- `claude/.claude/HEADROOM.md` — heading, intro sentence, one `claude mcp add` command.
- `test/secrets_loader_test.rb` — one new test that runs the repository's real personal mapping through the loader.
- `secrets/.config/secrets/1password.env` — one mapping line.

## Order of work

1. Write `JournalMcpTest#test_codex_declares_journal_with_its_url_and_token_variable`. Run `ruby -Itest test/journal_mcp_test.rb -n test_codex_declares_journal_with_its_url_and_token_variable`. Watch it fail: `config.toml has no [mcp_servers.journal] table`.
2. Write `#test_codex_runs_every_journal_tool_without_asking` and `#test_no_journal_tool_has_its_own_approval_override`. Add the Codex block. Run the three tests green. Commit test and config together.
3. Write `#test_headroom_registers_journal_for_claude_with_the_token_left_unexpanded` and `#test_headroom_says_to_unlock_before_starting_claude_for_journal`. Watch them fail (no `###` section names `journal`). Edit `HEADROOM.md`. Run green, plus `ruby -Itest test/home_assistant_mcp_test.rb` (the section it reads changes heading). Commit.
4. Write `SecretsLoaderTest#test_the_personal_mapping_resolves_the_journal_assistant_token_from_1password`. Run it alone; watch it fail (no `export JOURNAL_ASSISTANT_TOKEN=`). Add the mapping line. Run green, then the whole `test/secrets_loader_test.rb`. Commit.
5. Run the full suite as CI does, stopping with a non-zero exit at the first failing file: `bash -c 'set -eo pipefail; for f in test/*_test.rb; do ruby -Itest "$f"; done'`. Run `rubocop` on both test files and `markdownlint` with the no-hardwrap rule on `HEADROOM.md`. Grep the full diff for anything token-shaped: only `op://` references and `${JOURNAL_ASSISTANT_TOKEN}` may appear.
6. Re-read the full diff (rule 21). Push.
7. Live checks, by Etienne after merge, pull, and creating the 1Password item: see Proof.

## Risks

- `approve` means `start_budget` (self-declared destructive) and the other five writes run with no check in Codex. Chosen on purpose (intent out-of-scope list; planning answer 2026-10-11).
- Claude Code still prompts before each journal tool unless `claude/.claude/settings.json` allows `mcp__journal__*`. The intent keeps `settings.json` out of scope, so Claude asks; Codex does not. Asymmetry accepted, not fixed here.
- A Codex or Claude process started outside an `unlock`ed shell (for example from the Dock) has no token. The journal server then fails to start, as the other home servers do today.
- `finances.home.arpa` resolves only on the home network. Away from home the server fails to connect; no change can fix that here.
- Rejected: no approval setting (`auto`) — see Design decisions. Rejected: `writes`, like homeassistant — contradicts the intent's "run freely".
- Rejected: extracting the test helpers shared with `home_assistant_mcp_test.rb` — orthogonal refactor; propose it as a separate branch if wanted.

## Proof

- Codex declares `[mcp_servers.journal]` at `http://finances.home.arpa/mcp` with `bearer_token_env_var = "JOURNAL_ASSISTANT_TOKEN"`, next to the other home servers, with no tool-level override → `test/journal_mcp_test.rb` `test_codex_declares_journal_with_its_url_and_token_variable`, `test_no_journal_tool_has_its_own_approval_override` (configuration text only); manual proof, by Etienne after the 1Password item exists: `unlock`, start `codex`, `/mcp` lists `journal` tools, ask for an account balance and the read runs with no prompt.
- HEADROOM's "Home MCP servers" section names journal and holds the one-time `claude mcp add … journal …` command → `test/journal_mcp_test.rb` `test_headroom_registers_journal_for_claude_with_the_token_left_unexpanded`, `test_headroom_says_to_unlock_before_starting_claude_for_journal` (documentation text only); manual proof: Etienne runs the command with no Claude session open, `grep -c 'Bearer \${JOURNAL_ASSISTANT_TOKEN}' ~/.claude.json` prints `1`, then `unlock`, start `claude`, `/mcp` shows `journal` connected.
- `1password.env` maps `JOURNAL_ASSISTANT_TOKEN` to `op://Familie/JournalAdministration/assistant_token`, and the diff holds no plaintext secret → `test/secrets_loader_test.rb` `test_the_personal_mapping_resolves_the_journal_assistant_token_from_1password`; plus the diff grep in step 5.
- After `unlock` in a fresh shell, `$JOURNAL_ASSISTANT_TOKEN` holds the real token → `test/secrets_loader_test.rb` `test_the_personal_mapping_resolves_the_journal_assistant_token_from_1password` (mapping resolution against a stubbed `op` only; it cannot prove the real token); manual proof, by Etienne: `unlock && [[ -n $JOURNAL_ASSISTANT_TOKEN && $JOURNAL_ASSISTANT_TOKEN != '${JOURNAL_ASSISTANT_TOKEN}' ]] && echo set` prints `set` (avoids echoing the token itself).

Per changed file, the unit tests expected:

- `codex/.codex/config.toml`: `JournalMcpTest#test_codex_declares_journal_with_its_url_and_token_variable` (URL and `bearer_token_env_var`), `#test_codex_runs_every_journal_tool_without_asking` (`default_tools_approval_mode = "approve"`), `#test_no_journal_tool_has_its_own_approval_override` (no `[mcp_servers.journal.tools.*]` table exists).
- `claude/.claude/HEADROOM.md`: `JournalMcpTest#test_headroom_registers_journal_for_claude_with_the_token_left_unexpanded` (the exact two-line command with the single-quoted header), `#test_headroom_says_to_unlock_before_starting_claude_for_journal`.
- `secrets/.config/secrets/1password.env`: `SecretsLoaderTest#test_the_personal_mapping_resolves_the_journal_assistant_token_from_1password` (stdout has `export JOURNAL_ASSISTANT_TOKEN=`; `op` was called with `op://Familie/JournalAdministration/assistant_token --account vandelden`).

Test setup: the loader test reuses `SecretsLoaderTest`'s stub `op` and temporary `XDG_CONFIG_HOME`, and copies the repository's real `1password.env` into it, as the home-assistant test does. The other tests read repository files as text. No network, no 1Password, no real token.

## Out of scope

- Creating the 1Password item; running `claude mcp add` on this machine; stowing.
- Per-tool approval tables; `claude/.claude/settings.json`; `codex/.codex/rules/default.rules`.
- The journal_administration app.
- Refactoring shared helpers out of `test/home_assistant_mcp_test.rb`.

---
Domain skills applied: dotfiles-maintenance (stow-managed paths, edit sources not links), rails-testing (Minitest, behaviour-named tests). No conflicts.

## Critique

### Round 1 (codex exec -p terra)

- Step 5's `ruby … || break` loop exits zero after a failed test file → fixed (step 5 now runs the loop under `bash -c 'set -eo pipefail; …'`, so the first failure exits non-zero)
- The rationale for `approve` misdescribed `auto` as "every tool without readOnlyHint"; `auto` is annotation-driven per tool → fixed (Design decisions now states: `approve` asks for none, `writes` asks for every non-read-only tool, `auto` decides per tool from annotations)
- Test names and Proof claimed the tests prove Codex reaches journal with a real unlocked token, but they only read config text and use a stubbed `op` → fixed (tests renamed to `test_codex_declares_journal_with_its_url_and_token_variable` and `test_the_personal_mapping_resolves_the_journal_assistant_token_from_1password`; Proof marks them as configuration and mapping checks and keeps `unlock`, `/mcp` and a benign journal read as separate manual proof)
