# Intent: Review report test ignores the machine's global git hooks

Author: Etienne van Delden. Status: accepted (2026-10-02). Type: bug.

## Problem

`test/review_report_check_test.rb` errors on this machine, on `main` and on every branch. The test `test_a_change_folder_passes_when_main_gains_a_commit_after_the_branch_point` commits to `main` inside a temporary repository. The global `core.hooksPath` runs the dotfiles lefthook config there, and its `no-push-to-main` pre-commit hook blocks that commit. The suite is red for a reason unrelated to the code under test.

## Proposed outcome

The full test suite is green on a machine with these dotfiles installed. Tests that build temporary git repositories do not depend on the user's global git config or hooks.

## Affected users and systems

The dotfiles test suite, run locally and in CI. Any other test that runs `git commit` in a temporary repository has the same exposure.

## Constraints

- Do not weaken or remove `no-push-to-main`. It stays in force for real repositories.
- Do not skip or delete the failing test.
- Pre-existing failure under playbook rule 25: fix it on this branch, then rebase `personal-agent-autonomy` on top.

## Open questions

None.
