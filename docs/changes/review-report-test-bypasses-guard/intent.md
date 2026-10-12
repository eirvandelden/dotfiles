# Intent: Review-report test commits on main despite the branch guard

Author: Etienne van Delden de la Haije. Status: accepted. Type: bugfix. Delivery: autonomous.

## Problem

`test/review_report_check_test.rb` has one test that errors on this machine: `test_a_change_folder_passes_when_main_gains_a_commit_after_the_branch_point`. Its setup commits on `main` in a temporary repository. The global hooks apply to that repository, so the main/master guard refuses the commit, and the test fails with "git commit --quiet -m advance main failed". It still fails on `origin/main` (`174043a8`, 2026-10-12).

## Proposed outcome

The test's setup commits skip the hooks, as other tests already do with `git -c core.hooksPath=/dev/null`. The test passes on a machine with the guard installed, and its assertion about the review report stays unchanged.

## Affected users and systems

- `test/review_report_check_test.rb` in the dotfiles repository.
- Anyone running the dotfiles suite on a machine with the global hooks.

## Constraints

- Playbook rule 25: a red test is fixed in its own worktree and pull request.
- The test keeps proving the same behaviour of `review-report-fresh`; only the setup changes.
- Approved permissions for autonomous delivery: none.

## In scope

- How the test's setup creates its commits.

## Out of scope

- `review-report-fresh` itself.
- `conductor_scripts_test.rb` (intent `conductor-scripts-env-local`).
- The branch guard.

## Acceptance criteria

- `ruby -Itest test/review_report_check_test.rb` passes on a machine with the global guard installed.
- The test still fails if `review-report-fresh` stops accepting a change folder when `main` gains a commit after the branch point.

## Open questions

None.
