# Intent: Repository tests ignore the developer's own git setup

Author: Etienne van Delden de la Haije. Status: accepted. Type: bugfix. Delivery: autonomous.

## Problem

Eleven test files at the repository root run `git` in temporary repositories without isolating git from the machine they run on: `agent_worktree`, `change_folder`, `consent_guard`, `guard_parity`, `herdr_worker_scripts`, `review_report_check`, `test_guard`, `vendored_skills`, `worktree_create`, `worktree_pane`, `worktree_viewer`. Their `git commit` calls read Etienne's real global git config: commit signing through the 1Password SSH agent, the global hooks in `~/.config/git/hooks` with the dotfiles lefthook fallback (including `no-push-to-main`), and anything else set there.

On Etienne's machine this makes tests fail for reasons that have nothing to do with the code under test. On 2026-10-08 and 2026-10-09, `review_report_check_test.rb`, `worktree_create_test.rb`, `worktree_pane_test.rb` and `herdr_worker_scripts_test.rb` errored: a temporary-repository commit failed (`git commit --quiet -m advance main failed`, `1Password: agent returned an error`, `fatal: ambiguous argument 'HEAD'`). The other files pass only while 1Password is unlocked and no global hook objects. CI passes because its runner has no such global config.

Separately, two tests in `lefthook_local_hooks_test.rb` (`test_pre_commit_calls_lefthook_with_no_auto_install`, `test_pre_push_calls_lefthook_with_no_auto_install`) error with `Errno::ENOENT … commands.log` when the caller's environment sets `LEFTHOOK_BIN`: the shim prefers `$LEFTHOOK_BIN` over the logging stub on `PATH`. Same root cause: a test inherits the developer's environment.

## Proposed outcome

Every test file at the repository root gives the same result on Etienne's machine as on CI, whatever his global git config, global hooks, 1Password state or `LEFTHOOK_BIN` say. A failing test means the code under test is wrong.

## Affected users and systems

- Etienne and any agent running the suite locally (`for f in test/*_test.rb; do ruby -Itest "$f"; done`), including pre-push hooks and review panes.
- CI (`.github/workflows/dotfiles-tests.yml`): must stay green, unchanged.

## Constraints

- Test files and test helpers only. No change to production scripts, `lefthook.yml`, the git config, or `.github/workflows/`.
- No test is skipped, deleted or weakened to pass (playbook rule 14).
- No dependency added.
- Autonomous delivery (playbook §7a): agents carry the change to a verified PR; Etienne approves this intent and the merge.

## In scope

- The eleven test files named under Problem: their git commands run with no global or system git config from the machine (or with a test-owned one), so signing, global hooks and other global settings do not apply.
- `lefthook_local_hooks_test.rb`: the two logging-stub tests do not inherit `LEFTHOOK_BIN`.
- A shared test helper if three or more files need the same isolation (rule of three).

## Out of scope

- The lefthook test files that already set `GIT_CONFIG_GLOBAL` (`lefthook_global_hooks_sync`, `lefthook_pull_hooks`, `lefthook_posix_sh`), except the `LEFTHOOK_BIN` fix in `lefthook_local_hooks`.
- The leaked `GIT_DIR` problem in the fallback rubocop hook (separate branch `fallback-rubocop-hook-git-dir`).
- Making the suite faster.

## Acceptance criteria

1. With a global git config that turns on commit signing through a program that always fails, every test file at the repository root passes.
2. With a global `core.hooksPath` whose hooks always fail, every test file at the repository root passes.
3. With `LEFTHOOK_BIN` set to a real lefthook binary in the environment, `lefthook_local_hooks_test.rb` passes.
4. On CI the suite stays green.

## Flagged concerns

None.

## Open questions

None.
