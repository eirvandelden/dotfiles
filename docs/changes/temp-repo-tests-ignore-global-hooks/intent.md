# Intent: temporary-repo tests ignore the machine's global git setup

Author: Etienne van Delden de la Haije. Status: accepted (2026-10-12). Type: bugfix. Delivery: autonomous.

## Problem

Several dotfiles tests create a temporary git repository and commit in it. Those commits pick up the machine's global git setup. On Etienne's machine the global `no-push-to-main` hook blocks a commit to `main`, so `test/review_report_check_test.rb` errors on every run, also on `main`. CI passes, because CI has no global hooks. A review sandbox also saw six such tests fail, because a commit there tried to reach the 1Password signing agent. A green local suite therefore depends on the machine, not on the code.

## Proposed outcome

Every test that commits in a temporary repository gives the same result on Etienne's machine, in a sandbox and in CI. Global hooks and commit signing never run inside those temporary repositories.

## Affected users and systems

- Etienne and agents running the dotfiles test suite locally, in worktrees and in review sandboxes.
- Every `test/*_test.rb` file that runs `git commit` in a temporary repository.
- CI, which must stay green.

## Constraints

- The tests keep testing what they test today. No test gets weaker, skipped or deleted.
- The global hooks and the signing setup on the machine stay unchanged. Only the tests change.
- No permissions are needed under playbook rules 8, 9, 11, 12 or 13.

## In scope

- Make every temporary-repository commit in the dotfiles tests ignore global hooks and commit signing.
- A regression check that fails when a temporary-repository commit would run a global hook.

## Out of scope

- The hook scripts themselves, and the global git configuration.
- Tests that do not commit in a temporary repository.
- Tests whose purpose is to exercise the hooks; they keep running the hooks they test.

## Acceptance criteria

- With the global `no-push-to-main` hook active, `test/review_report_check_test.rb` passes on Etienne's machine.
- With commit signing turned on globally and no signing agent reachable, every temporary-repository test still passes.
- The full suite passes locally on Etienne's machine and in CI.
- A new temporary-repository test that forgets the setup is caught by a test, not by a failure on someone's machine.

## Open questions

None.
