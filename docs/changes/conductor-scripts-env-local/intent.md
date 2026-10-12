# Intent: Conductor scripts test passes again

Author: Etienne van Delden de la Haije. Status: accepted. Type: bugfix. Delivery: autonomous.

## Problem

`git/.config/git/worktree-tools/test/conductor_scripts_test.rb` is red on `origin/main` (`174043a8`, 2026-10-12): 2 failures and 1 error.

- `test_setup_preserves_env_local_and_exports_workspace_database_name`: `.env.local` holds only `EXISTING=value`; the expected `DATABASE_NAME=myapp_myapp_development` is missing.
- `test_run_loads_database_name_from_env_local`: the run script prints `DATABASE_NAME=` instead of `DATABASE_NAME=workspace_db`.
- `test_archive_loads_database_name_from_env_local`: `workspace/bundle.log` does not exist (`Errno::ENOENT`).

It is not yet known whether the scripts or the tests are wrong.

## Proposed outcome

The cause is found with systematic debugging. Whichever side is wrong gets fixed: the scripts, or a stale test. If the scripts' intended behaviour is unclear, the coordinator raises it to Etienne instead of choosing.

## Affected users and systems

- The Conductor `setup`, `run` and `archive` scripts that this test covers, and the test itself.
- Conductor workspaces that rely on `DATABASE_NAME` from `.env.local`.

## Constraints

- Playbook rule 25: a red test is fixed in its own worktree and pull request.
- A failing test is never weakened, skipped or deleted to get green; a test changes only when it is shown to be stale.
- Approved permissions for autonomous delivery: none.

## In scope

- Finding the cause of the three failures and fixing it.

## Out of scope

- `test/review_report_check_test.rb` (intent `review-report-test-bypasses-guard`).
- Adding the worktree-tools tests to CI (Etienne dismissed that on 2026-10-09).
- Other Conductor behaviour not exercised by these three tests.

## Acceptance criteria

- `ruby -Itest git/.config/git/worktree-tools/test/conductor_scripts_test.rb` passes: 3 runs, 0 failures, 0 errors.
- A Conductor workspace whose `.env.local` sets `DATABASE_NAME` gets that value in `run` and `archive`, shown in a real or scratch workspace.

## Open questions

None.
