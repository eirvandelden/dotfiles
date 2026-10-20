# Review: guard-hook-bypasses

## Round 1 — 2026-10-13T09:45Z — 8d1a39d5

No `REVIEW.md` or `REVIEW.local.md` exists at the repository root, so the reviewer's default passes ran: Bugs, Security, Compliance.

- [ ] Important: `GUARDED_COMMANDS` lacks `%w[git config --rename-section core]`. Plan decision 10 lists it, and critique round 3 closes its finding as "fixed (decision 10 adds `git config --rename-section core` to `GUARDED_COMMANDS` …)". Only `--remove-section core` is in the list, so the parity test does not catch a later allow rule that loosens `git config --rename-section core`. The Codex prompt rule itself exists and works: `codex execpolicy check` gives `prompt` for `git config --rename-section core core2`. — `test/guard_parity_test.rb:24` →
- [ ] Nit: The evidence from plan steps 8 and 9 (the `codex execpolicy check` output and the scratch-repository guard runs) is not recorded on the branch, and §7a asks for recorded evidence. Re-run here with codex-cli 0.162.1: every step-8 command gives the decision the plan expects (`prompt` for the eight guarded forms, no rule for `git config --get core.hooksPath` and `lefthook dump`, `allow` for `git push -n origin feature`). — `docs/changes/guard-hook-bypasses/plan.md:83` →
- [ ] Nit: A heredoc commit body is unquoted, so its lines become words. `git commit -F - <<'EOF'` with the body line `Refuse LEFTHOOK=0 and git commit -n` now asks (probed against the worktree's guard). The `-m "$(cat <<'EOF' … EOF)"` form stays one quoted word and goes through. This is the safe direction and the same class as `--no-verify` on main, but the new routes widen it. Consider one line under the plan's Risks so the next reader does not take it for a bug. — `claude/.claude/hooks/hook_bypass.rb:44` →

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
