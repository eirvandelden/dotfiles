# Review: configure-journal-administration-mcp

## Round 1 — 2026-10-13T11:23Z — dc773b3a

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the reviewer's default Bugs, Security and Compliance passes apply.

Checks run: `test/journal_mcp_test.rb` (5 runs, 0 failures), `test/secrets_loader_test.rb` (5 runs, 0 failures), `test/home_assistant_mcp_test.rb` (5 runs, 0 failures), `rubocop` on both changed test files (no offenses). Full suite: every file green except `test/review_report_check_test.rb`, which errors in `test_a_change_folder_passes_when_main_gains_a_commit_after_the_branch_point` (`git commit --quiet -m advance main failed`). This branch touches neither that test nor any hook file, so the failure is outside this change. `markdownlint-cli2` did not run: the worktree has no `node_modules` and `npx --no-install` refused to fetch it. The lefthook `no-hardwrap` check covers `HEADROOM.md` on commit, and every added line there is one line per paragraph.

Bugs: none found. The Codex block sits between `[mcp_servers.homeassistant]` and `[mcp_servers.node_repl]`, as planned. The `claude mcp add` command keeps the header in single quotes, so zsh does not expand the token into `~/.claude.json`.

Security: the diff holds no plaintext secret. The only new `1password.env` line maps to an `op://` reference, and a grep of the diff found no token-shaped literal and no work references. Two accepted risks stay as the plan records them: `default_tools_approval_mode = "approve"` lets Codex run `start_budget` (self-declared destructive) and the five other writes without a prompt, and the bearer token travels over plain `http` on the home network, the same as email, fizzy and homeassistant.

Compliance:

- Codex declares `[mcp_servers.journal]` at the URL with `bearer_token_env_var`, next to the other home servers, no tool-level override → `test_codex_declares_journal_with_its_url_and_token_variable`, `test_no_journal_tool_has_its_own_approval_override`.
- HEADROOM names journal and holds the one-time `claude mcp add … journal …` command → `test_headroom_registers_journal_for_claude_with_the_token_left_unexpanded`, `test_headroom_says_to_unlock_before_starting_claude_for_journal`.
- `1password.env` maps `JOURNAL_ASSISTANT_TOKEN` to `op://Familie/JournalAdministration/assistant_token`, no plaintext secret → `test_the_personal_mapping_resolves_the_journal_assistant_token_from_1password`, plus the diff grep above.
- After `unlock`, `$JOURNAL_ASSISTANT_TOKEN` holds the real token → mapping proven against a stubbed `op` only; the live check is manual, by Etienne, as the plan states.
- Every test named in the plan's `## Proof` exists, including `test_codex_runs_every_journal_tool_without_asking`. No existing test was weakened, skipped or deleted.

Findings: none.
