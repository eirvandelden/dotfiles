# Intent: Faster test suite

Author: Etienne van Delden de la Haije. Status: accepted (2026-10-19). Type: chore. Delivery: autonomous.

## Problem

A full local run of `test/*_test.rb` takes about 30 minutes on Etienne's Mac, so nobody runs the whole suite before a push. CI runs the same files in 204 seconds. Measurements on 2026-10-19 found these causes:

- The files run one at a time, on a 12-core machine. Microsoft Defender (MDM-managed, no exclusions) adds a delay to every process start and file write, and the suite starts thousands of short processes. Most of each file's wall time is waiting, not CPU.
- Running files side by side is not safe today. `stop_hanging_stubs` in `test/worktree_sweep_test.rb` kills whole process groups. When test files share one process group, that kill stops the other files: in a run of six at a time, five unrelated files died in the same second, and all of them pass alone.
- `LefthookBinary.locate` prefers `which lefthook`, which on this Mac is the RubyGems wrapper script (75 ms per call) instead of the native binary (13 ms). `branch_guard_test.rb` drops from 126 s to 95 s with the native binary.
- `test/isolated_git_test.rb` runs all of `test/review_report_check_test.rb` again in a child process, which costs about 25 seconds.
- The `gh` and `herdr` stubs in `test/delivery_harness.rb` are Ruby programs. Each stubbed call pays about 33 ms of RubyGems start-up.

## Proposed outcome

One command runs every `test/*_test.rb` file in parallel and finishes the full suite in under 8 minutes on Etienne's Mac. CI uses the same command. Parallel runs pass as reliably as one-at-a-time runs, and the individual files keep working with `ruby -Itest test/<file>_test.rb`.

## Affected users and systems

- Etienne and the agents that run the suite before a push.
- The `Dotfiles tests` GitHub Actions workflow (`.github/workflows/dotfiles-tests.yml`).
- The test helpers `test/lefthook_binary.rb`, `test/delivery_harness.rb`, and the tests `test/worktree_sweep_test.rb` and `test/isolated_git_test.rb`.

## Constraints

- No new gems, packages or system tools. The runner uses only Ruby's standard library.
- Approved permission (rule 13): edit the test step of `.github/workflows/dotfiles-tests.yml` so CI calls the new runner. No other workflow change.
- No test may be skipped, deleted or weakened to gain speed (rule 14). Each test keeps checking the behaviour it checks today.
- CI runs on Linux with the native lefthook binary on `PATH`; that path must keep working.
- Defender configuration and the machine's installed gems are out of reach; the fix lives in the repository.

## In scope

- A: a test runner that runs every `test/*_test.rb` file in its own process and its own process group, several at a time, and fails when any file fails. Fix the process-group kill in `test/worktree_sweep_test.rb` so it never reaches a process outside the test's own stubs.
- B: `LefthookBinary` returns the native lefthook binary before a RubyGems wrapper script.
- C: `test/isolated_git_test.rb` checks the same guarantee without running another whole test file.
- D: the `gh` and `herdr` stubs in `test/delivery_harness.rb` no longer pay the RubyGems start-up cost.
- CI's test step calls the new runner.

## Out of scope

- Test files outside `test/` (`git/.config/git/worktree-tools/test`, `conductor/.config/conductor/scripts/test`, `claude/.claude/test`).
- Defender exclusions and `gem cleanup` on the machine.
- Other speed work, such as `git init --template=` or rewriting the scripts under test.
- The lefthook pre-push or pre-commit configuration.

## Acceptance criteria

- Running the new command on Etienne's Mac runs every `test/*_test.rb` file and finishes in under 8 minutes.
- When one test file fails, the command exits non-zero and names that file; a full green run exits zero.
- Three full parallel runs in a row pass, including `test/worktree_sweep_test.rb` alongside the other files.
- `test/worktree_sweep_test.rb` with a hanging fetch stops the hanging stub and leaves every process outside its own stubs running.
- On a machine where `lefthook` on `PATH` is a RubyGems wrapper, the lefthook tests use the native binary.
- `test/isolated_git_test.rb` still fails when the global no-push-to-main hook breaks a commit in a test, and passes otherwise, without running another whole test file.
- A `gh` or `herdr` stub call in the delivery harness starts without loading RubyGems.
- The `Dotfiles tests` CI workflow runs the suite through the new command and stays green.
- `ruby -Itest test/<file>_test.rb` still runs one file on its own.

## Open questions

None.
