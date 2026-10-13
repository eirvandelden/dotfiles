# Intent: Conductor scripts test passes again

Author: Etienne van Delden de la Haije. Status: accepted. Type: bugfix. Delivery: autonomous.

## Problem

`git/.config/git/worktree-tools/test/conductor_scripts_test.rb` is red on `origin/main` (`174043a8`, 2026-10-12): 2 failures and 1 error.

- `test_setup_preserves_env_local_and_exports_workspace_database_name`: `.env.local` holds only `EXISTING=value`; the expected `DATABASE_NAME=myapp_myapp_development` is missing.
- `test_run_loads_database_name_from_env_local`: the run script prints `DATABASE_NAME=` instead of `DATABASE_NAME=workspace_db`.
- `test_archive_loads_database_name_from_env_local`: `workspace/bundle.log` does not exist (`Errno::ENOENT`).

Planning found the cause: the test is stale. #48 (`eb296b4c`, 2026-05-29) removed all `DATABASE_NAME` and `.env.local` handling from `setup`, `run` and `archive` on purpose (no database or secrets in workspaces; `archive` cleans `.context/` instead of dropping a database). It updated `conductor/.config/conductor/scripts/test/scripts_test.rb` but missed this file. Etienne confirmed on 2026-10-12 that #48 stands.

## Proposed outcome

The stale test is gone, and today's behaviour is pinned by tests in the maintained scripts test, so it cannot silently drift back. The scripts and READMEs stay as they are.

## Affected users and systems

- The Conductor `setup`, `run` and `archive` scripts that this test covers, and the test itself.
- Conductor workspaces that rely on `DATABASE_NAME` from `.env.local`.

## Constraints

- Playbook rule 25: a red test is fixed in its own worktree and pull request.
- A failing test is never weakened, skipped or deleted to get green; a test changes only when it is shown to be stale.
- Approved permissions for autonomous delivery: none.

## In scope

- Tests that pin the #48 behaviour: `setup` leaves `.env.local` unchanged, `run` exports no `DATABASE_NAME` from it, `archive` runs no database command.
- Removing the stale `conductor_scripts_test.rb`.

## Out of scope

- `test/review_report_check_test.rb` (intent `review-report-test-bypasses-guard`).
- Adding the worktree-tools tests to CI (Etienne dismissed that on 2026-10-09).
- Other Conductor behaviour not exercised by these three tests.

## Acceptance criteria

- The stale `conductor_scripts_test.rb` is gone, and `ruby conductor/.config/conductor/scripts/test/scripts_test.rb` passes: 10 runs, 0 failures, 0 errors.
- In a scratch workspace whose `.env.local` sets `DATABASE_NAME`, `run` prints `DATABASE_NAME=` (not exported) and `archive` calls neither `bundle` nor `rails`; the new tests fail against the pre-#48 scripts.

## Open questions

None.
