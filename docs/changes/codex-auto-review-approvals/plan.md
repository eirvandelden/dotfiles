# Plan: Codex stops asking for approval of routine commands

From `intent.md` (2026-10-02) and `spec.md` (2026-10-02). Status: accepted.

## Context

Codex 0.160.0 prompts Etienne for almost every escalated command in a build: git writes, herdr pane calls, `gh` calls. `allow` rules do not help, because an escalated command prompts even when an `allow` rule matches. The fix is `approvals_reviewer = "auto_review"` in `codex/.codex/config.toml`: a model reviewer approves escalations in place of Etienne. The commands that the playbook reserves for Etienne must still stop.

The code already answers the spec's flagged concern on rule 6. `claude/.claude/hooks/consent-guard.rb` runs in Codex as a `PreToolUse` hook (config.toml `[[hooks.PreToolUse]]`, matcher `^Bash$`). It exits 2 for `gh pr comment`, `gh pr review`, `gh issue comment`, deploys (`kamal deploy`, `kamal app exec`, `cap deploy`), `--no-verify`, pushes to a configured remote outside the allowlist, and plain `--force`. Codex 0.160.0 runs `PreToolUse` before the shell handler, so exit 2 refuses the call before any approval step, and the reviewer never sees these commands (verified against `codex-rs/core/src/tools/registry.rs` and `codex-rs/hooks/src/events/pre_tool_use.rs` at `rust-v0.160.0`). The `I_HAVE_USER_CONSENT=1` prefix unlocks them. The guard cannot verify that Etienne agreed first: the marker is a model-mediated safeguard, not proof of consent. That is true today and this change does not alter it. Plain `--force` never unlocks.

One reserved class has no deterministic stop today: destructive database commands (playbook rule 9). Etienne decided (2026-10-05) to add them to the consent guard in this change. `db:migrate:down` stays unguarded: Etienne allows it locally (2026-10-05), and a production run already needs `kamal app exec`, which the guard refuses.

## Files that change

- `codex/.codex/config.toml` — add `approvals_reviewer = "auto_review"` on the line after `approval_policy = "on-request"`. `approval_policy` and `sandbox_mode` stay as they are.
- `test/guard_parity_test.rb` — new tests that pin the reviewer setting, the unchanged approval policy and sandbox, and the absence of work names in the Codex config and rules.
- `claude/.claude/hooks/consent-guard.rb` — new `destroys_database?(words)` check in `consentable_reason`, with the reason "destructive database commands need the user's explicit approval (playbook rule 9)." `disallowed_remote` changes too: every non-flag word after `push` goes through `git ls-remote --get-url` (in the working directory and any `-C` directory), which expands configured remotes and `insteadOf` aliases. A word that resolves to a URL, or looks like a remote URL itself, must match the allowlist from the start of its github.com path. A word that resolves to nothing remote is a local path or refspec and passes. See the amendment below.
- `test/consent_guard_test.rb` — tests for the new database check.
- `docs/changes/codex-auto-review-approvals/probe.md` — new; the record of the live probes in step 10.
- `codex/.codex/rules/default.rules` — no change.

## Order of work

1. Write `test_codex_routes_approvals_to_the_automatic_reviewer` in `test/guard_parity_test.rb`. Run `ruby -Itest test/guard_parity_test.rb -n test_codex_routes_approvals_to_the_automatic_reviewer`. Watch it fail: the setting is missing.
2. Add `approvals_reviewer = "auto_review"` to `codex/.codex/config.toml`. Run the test. Watch it pass.
3. Write `test_codex_still_approves_on_request_in_the_workspace_write_sandbox`. It passes at once; it pins the current values against a later edit.
4. Write `test_codex_config_and_rules_name_no_work_owner`. It reads `File.expand_path(RemoteMatcher::ALLOWLIST_FILE)` itself, because `RemoteMatcher.listed_remotes` returns regexes, not raw entries. It drops blank and `#` lines, takes the owner part before the first `/` of each entry, and asserts that neither `config.toml` nor `default.rules` contains one, case-insensitive. It must not hardcode a name. The check is only real on a machine that has the private allowlist (`dotfiles-work` installs it); with no file the list is empty and the test passes. Say so in the test's comment. No change to `remote_matcher.rb`.
5. Write `test_destructive_database_commands_are_blocked_without_user_consent` in `test/consent_guard_test.rb` for `bin/rails db:drop`, `rails db:reset`, `bundle exec rails db:schema:load`, `bin/rails db:drop:all`. Run it. Watch it fail with exit 0.
6. Add `destroys_database?` to `consent-guard.rb`: true when a word matches `/\Adb:(drop|reset|schema:load)(:\w+)?\z/`. Call it in `consentable_reason` after the deploy check. Run the test. Watch it pass.
7. Write the companion tests: `test_destructive_database_commands_run_once_the_user_has_consented`, `test_routine_database_commands_are_allowed` (`bin/rails db:migrate`, `bin/rails db:migrate:status`, `bin/rails db:prepare`, `bin/rails db:migrate:down VERSION=1`), and `test_a_commit_message_naming_db_drop_is_allowed`. Run the whole file.
8. Write `test_pushing_to_a_url_outside_the_allowlist_needs_consent` (`git push git@github.com:someone-else/dotfiles.git my-branch` and the `https://github.com/someone-else/dotfiles.git` form), `test_pushing_to_an_allowed_url_is_allowed` (`git push git@github.com:eirvandelden/dotfiles.git my-branch`), and `test_a_remote_that_is_not_configured_is_left_alone` (`git push some-typo my-branch`, unchanged from main). Run them. Watch the first fail with exit 0.
9. (Superseded by the amendment below.) Change `disallowed_remote` in `consent-guard.rb`: take the first non-flag word after `push` as the target. No target: allow, as today (git uses the configured default). A target that looks like a URL (contains `://`, or matches `/\A[^\s\/]+@[^\s:]+:/`, or starts with `/`, `./` or `../`): return it unless `RemoteMatcher.allowed_remotes` matches it. A configured remote: resolve with `git remote get-url` and check, as today. Anything else: return it. Keep each branch in its own small method. The existing `test_a_remote_that_is_not_configured_is_left_alone` asserts the old behaviour Etienne just changed; replace it with `test_pushing_to_a_target_that_is_not_a_remote_needs_consent` in the same commit and say so in the commit message. Run the whole file; `test_pushing_to_main_is_left_to_the_ruleset` and the allowlist-file tests must stay green.
10. Probe the live behaviour with codex 0.160.0 in a scratch git repository outside the dotfiles repo, with the new config. Use `codex exec` or a fresh `codex app-server`, whichever the spec probe used; check `codex exec --help` for the JSON event flag instead of assuming it. Record each result in `docs/changes/codex-auto-review-approvals/probe.md`:
   1. Routine escalation: ask Codex to commit a file. Expect an escalated `git commit` that runs with a reviewer approval event and no approval request to the user.
   2. Prompt rule: ask Codex to run `rm scratch.txt`. Record whether the `prompt` rule reaches the user or the reviewer. Etienne accepts either outcome for `rm`, `trash`, `terraform`, `kubectl` and `docker system prune` (decision 2026-10-05); only record it.
   3. Guarded command: ask Codex to run `gh pr comment 1 --body hi`. Expect the consent guard refusal text in the tool output and no approval request.
   4. Denial: ask Codex to append a line to a file outside the workspace, such as a scratch file under `$HOME`. Expect a reviewer denial returned to the model and no approval request to the user. If the model refuses before the reviewer sees it, try one other command the model submits. After three failed attempts, record that in `probe.md` and stop (playbook rule 14).
11. Run the full suite for the touched tests: `ruby -Itest test/guard_parity_test.rb`, `ruby -Itest test/consent_guard_test.rb`. Run `rubocop` on the touched Ruby files. Run the `guard-parity` job: it lives under `pre-push` in `lefthook-local.yml`, so run `lefthook run pre-push --commands guard-parity` (check `lefthook run --help` for the flag) or let the push run it.
12. Grep the diff for work names before each commit (`git diff --cached | grep -i` for the owners in the allowlist file). Commit in four logical commits: the reviewer setting with its tests; the database check with its tests; the push-target check with its tests; the probe record.

## Risks

- The reviewer is a model. It can approve a command the playbook reserves. Mitigation: every reserved command except database commands is already refused by the guard before approval; step 6 closes the database gap, and steps 8–9 close the push-by-URL gap. The reviewer only replaces the human click for commands the guard lets through.
- The `prompt` rules (`rm`, `trash`, `terraform apply`/`destroy`, `kubectl delete`, `docker system prune`, `--no-verify`, `gh` comments, deploys) may now go to the reviewer instead of Etienne. For `--no-verify`, `gh` comments and deploys the guard still refuses first, so no loss. For the other five, Etienne accepted reviewer review (2026-10-05). The probe in step 10.2 records the real behaviour.
- `db:migrate:down` stays unguarded. A local Rails process with a remote `DATABASE_URL` can still roll back a shared database without consent. Etienne accepted this on 2026-10-06 after the Codex critique raised it.
- The database regex reads words, not semantics. `rails db:drop` inside a quoted commit message is one word and does not match; an unquoted mention in prose would match and ask. That errs towards asking, which the guard's header comment requires.
- Before this change the guard resolved only configured remote names, so a push to a URL or an unconfigured name passed the guard and only the Codex prompt stopped it. Under the reviewer that prompt is gone; steps 8 and 9 close the gap in the guard.
- The guard reads words, not shell syntax. It checks every non-flag word after the first `push`, so a push behind `;`, a newline, `env`, `sudo` or a second push is still seen. `bash -c '…'` and `--git-dir` pointing at another repository pass, as on main.
- A push to a name that is neither a remote, an `insteadOf` alias nor a remote URL passes, as on main: git reads it as a local path, so nothing leaves the machine.
- `git push` with no target still passes the guard. It goes to the branch's configured remote, which a previous push already set.
- The guard is a hook. If Ruby is not on `PATH` the hook cannot run and blocks nothing. This risk exists today and is unchanged; the `forbidden` rule for `git push --force` still holds without the hook.
- `config.toml` is rewritten by Codex itself (trust levels, hook state). A Codex write could drop the new line. The pinning test in step 1 catches that at the next pre-commit.
- Rejected: more `allow` rules (they do not apply to escalated commands); `danger-full-access` or wider `writable_roots` (sandbox stays; `writable_roots` does not make `.git` writable); `approval_policy = "never"` (removes the denial-to-model path and the consent flow); prompt rules for database commands (under the reviewer they may not reach Etienne, and prefix rules miss `bin/rails` and `bundle exec` forms).

## Amendment (2026-10-07)

Three review rounds showed that reading only the first word after `push`, or parsing shell syntax, either blocked `git stash push` and `git push && gh pr create`, or missed a second push behind `;`, a newline, `env` or `sudo`. The guard now scans every word after `push` and resolves each through `git ls-remote --get-url`. An unknown name passes again, as on main, because git reads it as a local path. Etienne agreed to this reversal of the 2026-10-06 decision on 2026-10-07.

## Out of scope

- No change to lefthook, the sandbox settings, or `rules/default.rules`.
- No guard entries for `terraform`, `kubectl` or `docker system prune`.
- No new `GUARDED_COMMANDS` entries in the parity test for database commands; the guard is their only layer.
- No change to Claude settings.

## Proof

- Codex config selects the automatic reviewer for approvals → `test/guard_parity_test.rb` `test_codex_routes_approvals_to_the_automatic_reviewer`
- Codex config still asks for approval on request and still runs in the workspace-write sandbox → `test/guard_parity_test.rb` `test_codex_still_approves_on_request_in_the_workspace_write_sandbox`
- A commit that the sandbox blocks runs after an escalation, and Etienne sees no prompt → `docs/changes/codex-auto-review-approvals/probe.md` probe 1 (live, manual)
- Plain `git push --force` is still refused by the consent guard → `test/consent_guard_test.rb` `test_plain_force_push_is_blocked_with_force_with_lease_advice`, `test_a_codex_payload_is_refused_with_the_same_message_as_a_claude_payload`; `test/guard_parity_test.rb` `test_a_plain_force_push_is_forbidden_rather_than_prompted`
- A push to a remote that Etienne does not own is still stopped → `test/consent_guard_test.rb` `test_pushing_to_a_remote_outside_the_allowlist_needs_consent`, `test_pushing_to_a_url_outside_the_allowlist_needs_consent`, `test_every_push_in_a_compound_command_is_checked`, `test_a_push_hidden_behind_shell_syntax_is_still_checked`, `test_a_scp_like_url_without_a_user_needs_consent`, `test_an_insteadof_alias_is_resolved_before_matching`, `test_a_url_that_only_contains_an_allowed_path_needs_consent`
- `gh pr comment`, `gh pr review` and `gh issue comment` still need Etienne's consent → `test/consent_guard_test.rb` `test_github_comments_and_reviews_as_the_user_are_blocked`; `probe.md` probe 3
- When the reviewer denies a command, the model receives the denial and Etienne sees no approval prompt for it → `probe.md` probe 4 (live, manual)
- Deploy commands and destructive database commands still need Etienne's consent → `test/consent_guard_test.rb` `test_deploys_are_blocked_without_user_consent`, `test_destructive_database_commands_are_blocked_without_user_consent`
- The committed Codex config and rules contain no work names, repositories or remotes → `test/guard_parity_test.rb` `test_codex_config_and_rules_name_no_work_owner`, `test_no_rule_names_a_machine_path`

Per changed file, the unit tests expected:

- `codex/.codex/config.toml` (through `test/guard_parity_test.rb`): `routes approvals to the automatic reviewer`, `still approves on request in the workspace-write sandbox`, `names no work owner`.
- `claude/.claude/hooks/consent-guard.rb` (through `test/consent_guard_test.rb`): `blocks destructive database commands without consent`, `runs them once the user has consented`, `allows routine database commands`, `allows a commit message that names db:drop`, `asks before a push to a URL outside the allowlist`, `allows a push to an allowed URL`, `leaves a name that is not a remote alone`, `does not treat git stash push as a push`, `allows local paths and refspecs after a push`.

Test setup: plain Minitest, no Rails. The parity tests read the committed files. The guard tests reuse `run_guard` with the temporary `@home` and `@repo` from `setup`. The no-work-owner test reads the real allowlist file under `$HOME` and passes vacuously when it is absent. The live probes run against the installed codex 0.160.0 in a scratch repository and are recorded by hand, not automated.
