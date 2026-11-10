# Review: guard-hook-bypasses

## Round 1 — 2026-10-13T09:45Z — 8d1a39d5

No `REVIEW.md` or `REVIEW.local.md` exists at the repository root, so the reviewer's default passes ran: Bugs, Security, Compliance.

- [x] Important: `GUARDED_COMMANDS` lacks `%w[git config --rename-section core]`. Plan decision 10 lists it, and critique round 3 closes its finding as "fixed (decision 10 adds `git config --rename-section core` to `GUARDED_COMMANDS` …)". Only `--remove-section core` is in the list, so the parity test does not catch a later allow rule that loosens `git config --rename-section core`. The Codex prompt rule itself exists and works: `codex execpolicy check` gives `prompt` for `git config --rename-section core core2`. — `test/guard_parity_test.rb:24` → fixed (Guard git config --rename-section core in the parity test)
- [x] Nit: The evidence from plan steps 8 and 9 (the `codex execpolicy check` output and the scratch-repository guard runs) is not recorded on the branch, and §7a asks for recorded evidence. Re-run here with codex-cli 0.162.1: every step-8 command gives the decision the plan expects (`prompt` for the eight guarded forms, no rule for `git config --get core.hooksPath` and `lefthook dump`, `allow` for `git push -n origin feature`). — `docs/changes/guard-hook-bypasses/plan.md:83` → dismissed: this round re-ran and records the step-8 decisions, the implement report holds the step-9 guard runs, and the delivery account repeats both.
- [x] Nit: A heredoc commit body is unquoted, so its lines become words. `git commit -F - <<'EOF'` with the body line `Refuse LEFTHOOK=0 and git commit -n` now asks (probed against the worktree's guard). The `-m "$(cat <<'EOF' … EOF)"` form stays one quoted word and goes through. This is the safe direction and the same class as `--no-verify` on main, but the new routes widen it. Consider one line under the plan's Risks so the next reader does not take it for a bug. — `claude/.claude/hooks/hook_bypass.rb:44` → fixed (docs: record the heredoc body risk in the guard-hook-bypasses plan)

### Bugs

No defect found beyond the above. Probed `HookBypass.reason` against edge forms: `git config --file x core.hooksPath y`, `-f`, `--add`, `set --global`, `--global unset`, `--unset-all CORE.HOOKSPATH`, `--remove-section CORE`, `git -C dir commit -n`, `npx lefthook install`, `git rebase --no-verify` all ask; `git config --show-origin --get core.hooksPath`, `git log -n 5`, `git commit -m n` and `git notes add -m x` go through.

### Security

No secrets, no new network calls, no new dependencies. The change only widens what the guard asks about. The known gaps (`sh -c`, `eval`, `GIT_CONFIG_GLOBAL`/`HOME`/`XDG_CONFIG_HOME`, sequencer commits, the mixed `--force-with-lease a; --force b`) are out of scope or accepted risks in `intent.md` and `plan.md`.

### Compliance

Acceptance criteria against tests in `test/consent_guard_test.rb`:

- `git commit -n -m "x"` waits → `test_commit_n_waits_for_consent`
- `git push -n origin feature` goes through → `test_a_push_dry_run_runs_without_a_question`
- `LEFTHOOK=0`, `LEFTHOOK=false`, `export LEFTHOOK=0;` wait → `test_turning_lefthook_off_waits_for_consent`
- `LEFTHOOK_EXCLUDE=…` waits → `test_excluding_a_lefthook_command_waits_for_consent`
- `git -c core.hooksPath=/dev/null commit` waits → `test_overriding_core_hooks_path_for_one_command_waits_for_consent`
- `GIT_CONFIG_PARAMETERS` and `GIT_CONFIG_COUNT`/`GIT_CONFIG_KEY_0` wait → `test_setting_core_hooks_path_through_the_environment_waits_for_consent`
- `git config core.hooksPath /dev/null` and `--global --unset` wait → `test_writing_or_unsetting_core_hooks_path_waits_for_consent`; section forms → `test_removing_or_renaming_the_core_section_waits_for_consent`
- `git config --get core.hooksPath` goes through → `test_reading_core_hooks_path_runs_without_a_question`
- `git commit-tree …` and `git update-ref …` wait → `test_plumbing_that_skips_the_commit_hooks_waits_for_consent`
- `lefthook install`/`uninstall` wait; `lefthook dump` goes through → `test_installing_or_uninstalling_lefthook_waits_for_consent`, `test_lefthook_dump_runs_without_a_question`
- `I_HAVE_USER_CONSENT=1 git commit -n` goes through → `test_commit_n_runs_once_the_user_has_consented`
- `git commit --no-veri` waits → `test_an_abbreviated_no_verify_waits_for_consent`
- `LEFTHOOK_BIN=true` and `LEFTHOOK_CONFIG=…` wait → `test_replacing_lefthook_or_its_config_waits_for_consent`
- `git push --force …; echo done` refused → `test_a_plain_force_push_chained_to_another_command_is_refused`
- `git push --force-with-lease …; echo done` goes through → `test_a_force_with_lease_push_chained_to_another_command_is_allowed`
- `git commit -m "explain why LEFTHOOK=0 is refused"` goes through → `test_a_message_naming_a_hook_switch_runs_without_a_question`
- Codex prompts for each prefix-expressible route, parity passes → `test/guard_parity_test.rb` coverage tests plus `test_a_codex_payload_is_refused_with_the_same_message_as_a_claude_payload`; parity list incomplete, see the Important finding

Every test the plan's `## Proof` names exists, including all 22 unit tests in `test/hook_bypass_test.rb` and `test_a_hook_skip_chained_or_substituted_still_waits_for_consent`. No existing test was weakened, skipped or deleted; the only edit to an existing test adds two commands to the Codex-payload test.

### Checks run

- `test/consent_guard_test.rb` 130 runs, `test/hook_bypass_test.rb` 22 runs, `test/guard_parity_test.rb` 9 runs: all green.
- `rubocop` on the five touched Ruby files: no offenses.
- Other test files: green except `test/review_report_check_test.rb` (known red on main, plan step 10) and `test/worktree_create_test.rb`, `test/worktree_pane_test.rb`, `test/worktree_viewer_test.rb`. Those three fail in setup on `git commit` because 1Password commit signing returns "agent returned an error" on this machine. A plain commit in a fresh scratch repository fails the same way, so it is environmental and not from this branch.

## Round 2 — 2026-10-20T14:18Z — 3d95e377

No `REVIEW.md` or `REVIEW.local.md` exists at the repository root, so the reviewer's default passes ran: Bugs, Security, Compliance. The branch contains `origin/main`.

- [x] Important: `test/hook_bypass_test.rb` does not `require_relative "isolated_git"`, so `test/isolated_git_test.rb` `test_every_test_file_requires_the_helper` fails ("Expected [\"hook_bypass_test.rb\"] to be empty"). CI runs every `test/*_test.rb`, so the branch turns it red. — `test/hook_bypass_test.rb:4` → fixed (Require isolated_git in the HookBypass test)
- [x] Important: `lefthook add pre-commit` goes through without a question, and it does the same harm as `lefthook install`. Probed in a sandbox (`GIT_CONFIG_GLOBAL` with `core.hooksPath` set to a scratch directory, lefthook 2.2.2): it renamed the global `pre-commit` shim to `pre-commit.old` and wrote lefthook's stock hook in its place, the 2026-10-06 incident the intent cites. `lefthook_install?` and the Codex rule `["lefthook", ["install", "uninstall"]]` know only `install` and `uninstall`. — `claude/.claude/hooks/hook_bypass.rb:95` → fixed (Ask before lefthook add and a quoted switch inside backticks)
- [x] Nit: The quote-aware scan's lookbehind `(?<![^\s;&|(])` does not accept a backtick, while decision 4 treats a backtick as substitution punctuation. ``echo `LEFTHOOK_CONFIG="/a b" git commit -m x` `` goes through; the same command inside `$( … )` or `{ …; }` asks. — `claude/.claude/hooks/hook_bypass.rb:11` → fixed (Ask before lefthook add and a quoted switch inside backticks)
- [x] Nit: `git fast-import` writes commits and moves branches without any git hook, the same class as `commit-tree` and `update-ref`, and goes through. The intent lists only those two; consider a follow-up. — `claude/.claude/hooks/hook_bypass.rb:90` → dismissed: out of scope; the accepted intent names commit-tree and update-ref only. Recorded as a follow-up candidate in the delivery account.

### Bugs

Beyond the above, probed the worktree's guard with a Claude payload: `$(LEFTHOOK_CONFIG="/a b" git commit …)`, `{ LEFTHOOK_CONFIG="/a b" git commit …; }`, `git -C . config core.hooksPath …`, `git config --global core.hooksPath ''`, `git --config-env core.hooksPath=NOPE commit`, `GIT_CONFIG_KEY_0="core.hooksPath" … git commit`, `git -c 'core.hooksPath=/tmp/a b' commit` and the bare read `git config core.hooksPath` ask. `git config --get core.hooksPath`, `git log -n 5` and `git commit -m 'it is git commit -n'` go through. `git commit --no-verify=1` goes through, but git refuses a value on a boolean option, so it skips nothing.

### Security

No secrets, no new network calls, no new dependencies. The change only widens what the guard asks about. The `lefthook add` gap above is the only new route found that defeats the main guard.

### Compliance

Round 1's Important finding holds as fixed: `GUARDED_COMMANDS` holds `%w[git config --rename-section core]`, and the parity test passes. The acceptance-criteria mapping from round 1 is unchanged: no test changed since, and each test it names still passes. Every test `plan.md`'s `## Proof` names exists. No existing test was weakened, skipped or deleted. The plan's Risks gained the heredoc line from round 1.

### Checks run

- `test/consent_guard_test.rb` 141 runs, `test/hook_bypass_test.rb` 22 runs, `test/guard_parity_test.rb` 12 runs: all green.
- `rubocop` on the five touched Ruby files: no offenses.
- Every other `test/*_test.rb`: green, except `test/isolated_git_test.rb` (the first finding).
