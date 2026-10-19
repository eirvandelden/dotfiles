# Plan: Fun agent voice

From `intent.md` (2026-10-19). Status: accepted.

## Design decisions

- One `SessionStart` hook, one data file, both tools. The hook is `claude/.claude/hooks/agent-voice.rb`; the data is `claude/.claude/agent-voice.yml`. The hook reads the data file beside itself, `File.expand_path("../agent-voice.yml", __dir__)`. Ruby's `__dir__` follows the stow link to the real file, so the same path works from the worktree and from `~/.claude/hooks/`. The `AGENT_VOICE_DATA` environment variable overrides the path, for tests only. Claude calls it from `settings.json`; Codex calls the same script from an inline `[[hooks.SessionStart]]` table in `config.toml`. This is the pattern the consent guard and test guard already use: one script under `claude/.claude/hooks/`, called by both tools.
- Both tools add a `SessionStart` hook's plain stdout to the model context. Claude: the existing `core-values.rb full` hook works this way. Codex: the hooks documentation (learn.chatgpt.com/docs/hooks) says "Plain text on `stdout` is added as extra developer context", and the hook gets one JSON object on stdin with `session_id`, `cwd` and `source`.
- Personal or work is decided by the session's `origin` remote, read with `git -C <cwd> remote get-url origin`, and matched with `RemoteMatcher.personal?` from `claude/.claude/hooks/remote_matcher.rb`. This is the same test `auto-accept` and `finish` already use. Work repositories and repositories without `origin` print nothing: no persona, no flavour. Fail closed. Directories outside git count as personal and get a persona (decided by Etienne).
- The persona pick is random per session but stable within one: the index is a hash of `session_id` (`Zlib.crc32(session_id) % personas.size`). Resume and compaction keep the same `session_id`, so the persona does not change mid-session, and the hook needs no state file. A new session gets a new id, so two sessions in a row can differ. `/clear` and `fork` greet or continue with whatever persona their `session_id` gives; the plan does not promise a new pick on `/clear`, because neither tool documents a new id for it. A fork can get a different persona than its parent. A missing `session_id` falls back to `Random.rand`.
- `source` decides the greeting. `startup` and `clear` tell the agent to open its first reply with a greeting. `resume`, `compact` and `fork` tell it to speak as this persona and not greet again.
- The data file holds two things: the ten personas (`name`, `emoji`, `tone`, `catchphrases`, at most 4 catchphrases each) and the voice rules (the cap, the exemptions, the never-themed list). The hook prints the rules and only the picked persona's style sheet. No canned line pool.
- The persona text is written in the style of each character, with short catchphrases. Catchphrases stay short so the data file does not reproduce copyrighted game scripts at length; most of them are well-known one-liners ("Zug zug", "Stay awhile and listen", "Do or do not").
- The playbook exemption goes into `agents.md` §7 rule 1 as one sub-bullet. It applies only when the `agent-voice` hook gave the session a persona; a session without one keeps all output plain. It also states the cap and the never-themed list in one line. `core-values.yml` does not mirror rule 1 today, so it does not change.
- The hook follows `core-values.rb` on failure: it always exits 0, and a missing or broken data file warns on stderr instead of going quiet.

## Integration points

- Claude Code `SessionStart` hooks in `claude/.claude/settings.json`, matcher `^(startup|resume|clear|compact|fork)$` (the same regex as the herdr state hook there), command `"$HOME/.claude/hooks/agent-voice.rb"`, timeout 10.
- Codex hooks in `codex/.codex/config.toml`: `[[hooks.SessionStart]]` with the same matcher `^(startup|resume|clear|compact|fork)$` and the same command. Both tools match the same sources. `~/.codex/hooks.json` belongs to herdr and stays untouched.
- `RemoteMatcher` in `claude/.claude/hooks/remote_matcher.rb`, required with `require_relative`, the way `auto-accept` requires it.
- Stow: `~/.claude/hooks/` holds per-file links, so the new hook and data file appear on the machine only after Etienne restows the `claude` package. Rule 12 forbids the agent to run stow.
- Codex hook trust: `config.toml` keeps `[hooks.state]` trusted hashes per hook. A new hook needs one trust approval in Codex on first run.

## Files that change

- `test/agent_voice_test.rb` — new. Runs the hook against temporary git repositories, and checks the wiring in `settings.json` and `config.toml`.
- `claude/.claude/agent-voice.yml` — new. The ten personas and the voice rules.
- `claude/.claude/hooks/agent-voice.rb` — new, executable. Reads stdin JSON, checks origin, picks the persona, prints the instructions.
- `claude/.claude/settings.json` — one more `SessionStart` entry.
- `codex/.codex/config.toml` — one `[[hooks.SessionStart]]` table next to the existing `[[hooks.PreToolUse]]` tables, with a one-line comment.
- `agents.md` — one sub-bullet under §7 rule 1 for the flavour-line exemption.

## Order of work

1. Write `test/agent_voice_test.rb` `test_a_personal_repository_session_gets_a_persona_with_a_greeting`. Run it, watch it fail because the hook does not exist.
2. Add `claude/.claude/agent-voice.yml` with the ten personas and the rules. Lint it with `yamllint`.
3. Add `claude/.claude/hooks/agent-voice.rb` (executable) until step 1 passes.
4. Add the remaining hook tests one at a time, red then green: work origin, no origin, outside git (gets a persona), stable pick per session id, different picks across ids, no greeting on resume and compact, every persona present with tone and catchphrases, rules text, data file failures.
5. Add the wiring tests for `settings.json` and `config.toml`. Watch them fail, then add the two hook entries.
6. Add the exemption test for `agents.md`, watch it fail, then add the sub-bullet.
7. Run `ruby test/agent_voice_test.rb`, then the full suite (`for f in test/*_test.rb; do ruby "$f" || exit 1; done`), `rubocop` on the new Ruby files, `yamllint` on the YAML, and markdownlint on `agents.md`.
8. Verify by hand in the worktree: pipe a fake `SessionStart` JSON into the hook for this repository (personal), for a temporary repository with a non-personal origin, and for `/tmp`. Then run `claude -p --settings <tmp settings with the worktree hook path> "Hello"` twice: in this worktree, where the reply must open in character with emoji, and in a temporary repository with a non-personal origin, where it must have no flavour. Then try the same two Codex runs with `codex exec -c` overriding `hooks.SessionStart` to the worktree hook path. If Codex skips the hook because it is not trusted yet, record that, and leave the live Codex check for after stow and trust (see Out of scope). Record all output as evidence.
9. Re-read the diff. Commit in small steps: data and hook with tests, then the wiring, then the playbook line.

## Risks

- The model can ignore or overuse the instructions. Hooks cannot enforce "at most 2 flavour lines". The rules text is explicit and short, and it states the never-themed list. Accepted: the intent asks for improvised lines, not a filter.
- The Claude "Concise" output style and the terse rule push against flavour. The injected text says the flavour lines are exempt from both, and the playbook says the same, so the instructions agree.
- Codex may not run the new hook until it is trusted, and Codex rewrites `config.toml` (it adds `[hooks.state]` hashes). Before commit, grep the `config.toml` diff for work names (memory: the repository is public).
- Codex `fork` gets a new `session_id`, so a fork can switch persona. Accepted; the fork gets no greeting.
- Sessions outside a git repository get no persona. That is fail-closed; see the report for the open decision.
- Rejected: a `UserPromptSubmit` hook that injects the persona every prompt. It costs tokens every turn and pushes flavour into every reply, against the cap. Rejected: a state file per session. The hash of `session_id` gives the same stability with no state.
- Rejected: putting persona text in `agents.md`. Work sessions also load the playbook, and the hook keeps the persona out of them.

## Proof

- A new session in a personal repository opens with one or two in-character lines that carry emoji → `test/agent_voice_test.rb` `test_a_personal_repository_session_gets_a_persona_with_a_greeting`, plus check: step 8 `claude -p` run in this worktree.
- Two sessions started in a row can open with different personas → `test/agent_voice_test.rb` `test_different_sessions_can_get_different_personas`.
- Finishing a task adds one short in-character done line after the plain summary → `test/agent_voice_test.rb` `test_the_rules_ask_for_a_done_line_after_the_plain_summary`.
- A reply that is neither a greeting nor a done line has no more than 2 flavour lines, and most replies have none → `test/agent_voice_test.rb` `test_the_rules_cap_flavour_at_two_lines_and_keep_most_replies_plain`.
- A session in a work repository shows no flavour line → `test/agent_voice_test.rb` `test_a_work_repository_session_prints_nothing`, `test_a_repository_without_origin_prints_nothing`, `test_a_session_outside_git_prints_nothing`, plus check: step 8 `claude -p` run in the non-personal repository.
- A commit message, a PR body, a command or a failing test's error output contains no flavour → `test/agent_voice_test.rb` `test_the_rules_keep_code_commands_errors_commits_and_pr_text_plain`.
- An ordinary reply that has no flavour line may still carry an emoji → `test/agent_voice_test.rb` `test_the_rules_allow_emoji_in_ordinary_replies`.
- A security warning or destructive-action confirmation is plain, complete and has no emoji → `test/agent_voice_test.rb` `test_the_rules_keep_security_warnings_and_destructive_confirmations_plain`.
- Codex sessions behave the same way → `test/agent_voice_test.rb` `test_codex_runs_the_same_hook_on_session_start`, `test_claude_and_codex_match_the_same_sources`, plus check: step 8 `codex exec` runs, or the same runs after stow and trust when Codex skips an untrusted hook.

Per changed file, the unit tests expected:

- `claude/.claude/hooks/agent-voice.rb`: `test_the_same_session_keeps_its_persona`, `test_resume_and_compact_keep_the_persona_without_a_greeting`, `test_a_session_without_an_id_still_gets_a_persona`, `test_a_missing_data_file_warns_instead_of_going_quiet`, `test_malformed_data_warns_instead_of_going_quiet`, `test_unparseable_stdin_warns_and_prints_nothing`.
- `claude/.claude/agent-voice.yml`: `test_all_ten_personas_have_a_tone_and_catchphrases`.
- `claude/.claude/settings.json`: `test_claude_runs_the_hook_on_session_start`, `test_the_hook_reads_its_data_beside_itself_through_a_link`.
- `codex/.codex/config.toml`: `test_codex_runs_the_same_hook_on_session_start`.
- `agents.md`: `test_the_playbook_exempts_flavour_lines_only_when_a_persona_was_given`.

Test setup: `require_relative "isolated_git"`. The hook reads the repository's `claude/.claude/agent-voice.yml` by default; the failure tests point `AGENT_VOICE_DATA` at a missing or broken file in a temporary directory. The link test symlinks the hook into a temporary directory and runs it from there. Each test makes a temporary repository via `git init` plus `git remote add origin` with `git@github.com:eirvandelden/example.git` (personal) or `git@github.com:someone-else/example.git` (not personal). The hook runs with `Open3.capture3(env, HOOK, stdin_data: json)`. The ten persona names are a constant in the test, copied from `intent.md`.

## Out of scope

- Any persona outside the ten in `intent.md`, and any setting to pick a persona by hand.
- A pool of canned lines.
- Flavour in work repositories, or in commit messages, PR text, code, commands, error output, security warnings and destructive-action confirmations.
- Changes to `~/.codex/hooks.json` (herdr owns it), to `core-values.yml`, and to any CI workflow.
- Running `stow`. Etienne restows `claude` after merge so `~/.claude/hooks/agent-voice.rb` and `~/.claude/agent-voice.yml` exist, then approves the new hook once in Codex. The live Codex check runs then if step 8 could not run it.

---
Domain skills applied: dotfiles-maintenance, ruby-style.

## Critique

### Round 1 (codex exec -p terra)

- Personal scope is too narrow: a session with no origin or outside git gets no voice, and a work checkout under a personal fork counts as personal → dismissed: `RemoteMatcher.personal?` is the classifier `auto-accept` and `finish` already use for personal scope, and intent.md names repositories as the unit. Fail closed matches the "no flavour in work repositories" rule. Sessions outside git: Etienne decided they count as personal and get a persona.
- The live Claude check cannot pass before stow, because the hook reads `$HOME/.claude/agent-voice.yml` → fixed (the hook reads the data file beside itself through `__dir__`, which follows the stow link; `AGENT_VOICE_DATA` overrides it for tests; a link test added)
- Fork handling differs between the tools and the plan claims a fork keeps its persona → fixed (both tools now match the same five sources, fork included; the plan says a fork may get a different persona and does not greet; `test_claude_and_codex_match_the_same_sources` added)
- Codex behaviour is not verified live, and the Claude check skips a work repository → fixed (step 8 adds a Claude run in a non-personal repository and two `codex exec -c` runs, with a fallback to after stow and trust when Codex skips an untrusted hook)
- The global playbook exemption can weaken the work-repository rule → fixed (the exemption applies only when the hook gave the session a persona; the test name changed to match)
- `/clear` is assumed to give a new session id → fixed (the plan no longer promises a new pick on `/clear`; the acceptance criterion depends only on new sessions)
