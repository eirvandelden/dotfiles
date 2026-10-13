# Plan: Conductor scripts test passes again

From `intent.md` (2026-10-12). Status: accepted.

## Gate before implementation

This plan treats the test as stale, not the scripts as broken. Both acceptance criteria in `intent.md` assume the opposite, so neither can hold as written. The coordinator must get Etienne's answers below before the implement stage starts. If any answer is "yes", this plan is void and needs a new plan for that behaviour.

1. Must `setup` write a `DATABASE_NAME` to `.env.local` again? #48 removed this on purpose.
2. Must `run` source `.env.local` before it starts the server again? #48 removed this on purpose.
3. Must `archive` load `DATABASE_NAME` again, and use it for `rails db:drop`? #48 removed both on purpose. Loading the value does not require the drop; these can be answered separately.
4. If all three answers are "no": replace the two acceptance criteria in `intent.md` with the two replacement lines under `## Proof`, and accept the amended intent.

Resolved: Etienne answered "No, #48 stands" on 2026-10-12. The amended `intent.md` carries the replacement criteria and was accepted on 2026-10-13. Implementation may start.

## Cause

Systematic debugging, done while writing this plan, on `origin/main` `174043a8`:

- `ruby -Itest git/.config/git/worktree-tools/test/conductor_scripts_test.rb` gives 3 runs, 2 failures, 1 error, as `intent.md` states.
- `git/.config/git/worktree-tools/test/conductor_scripts_test.rb` arrived in #28 (`1cde559e`, 2026-04-17). It tests the scripts of that time: `setup` writes `DATABASE_NAME` to `.env.local` and runs `rails db:prepare`; `run` loads `.env.local`; `archive` loads `.env.local` and runs `rails db:drop`.
- The test was already partly wrong before #48. It creates `Gemfile.lock`, so the `setup` of #28 ran `rv ci`, not `bundle install`. Its expected `DATABASE_NAME=myapp_myapp_development install --quiet` log line did not match that script either.
- #48 (`eb296b4c`, 2026-05-29, "stable AI URLs with puma-dev personal defaults") removed the database behaviour on purpose. Its commit message: "Simplify Conductor scripts to worktree-setup only (no DB/secrets)" and "archive cleans .context/ instead of dropping a database". The diff deletes `load_env_local`, `workspace_database_name` and `load_database_name` from the scripts.
- #48 rewrote the scripts' own test, `conductor/.config/conductor/scripts/test/scripts_test.rb`, for the new behaviour. It missed the second test file in `worktree-tools/test/`. The rewritten test is green: 7 runs, 0 failures.
- Two READMEs document the current behaviour as intended. `conductor/.config/conductor/scripts/README.md`: "No database or dependency setup — handle those in your project's own setup steps if needed." `git/.config/git/worktree-tools/README.md:264`: "**Does not** install dependencies, load secrets, create databases, or write `.env.local`."
- Each current failure follows directly: `setup` never writes `.env.local`; `run` never sources it; `archive` never calls `bundle`, so the stub never creates `bundle.log`.

Conclusion: the scripts match their documented, deliberate behaviour. The test is stale.

## Design decisions

- Delete `git/.config/git/worktree-tools/test/conductor_scripts_test.rb`. Rewriting its three tests to assert the current behaviour would duplicate `conductor/.config/conductor/scripts/test/scripts_test.rb`, which already covers `setup`, `run` and `archive`.
- Before the deletion, pin the #48 decision in the scripts' own test, so the stale expectation cannot quietly return and no `.env.local` coverage is lost. Add three tests to `conductor/.config/conductor/scripts/test/scripts_test.rb`:
  - `setup` leaves an existing `.env.local` byte for byte unchanged.
  - `run` does not export `DATABASE_NAME` from `.env.local` to `bin/dev`. A project that needs it loads `.env.local` itself, for example in `bin/dev` or its copied `bin/run`.
  - `archive` runs no database command: neither `bundle` nor `rails` gets called.
- No change to the scripts. No change to either README; both already describe the current behaviour.

## Integration points

- `conductor/.config/conductor/scripts/{setup,run,archive}`: read only, not changed.
- Nothing runs either test file automatically. `lefthook.yml` and `lefthook-local.yml` do not reference them. No CI runs them (out of scope per `intent.md`). Outside this change folder, `git grep` finds no reference to `conductor_scripts_test.rb`.

## Files that change

- `conductor/.config/conductor/scripts/test/scripts_test.rb` — three new tests: `test_setup_leaves_env_local_unchanged`, `test_run_does_not_export_database_name_from_env_local` and `test_archive_runs_no_database_command`. They reuse the file's helpers (`rails_workspace`, `write_executable`, `run_script`, `command_log`).
- `git/.config/git/worktree-tools/test/conductor_scripts_test.rb` — deleted; it tests behaviour #48 removed.

## Order of work

1. Run `ruby -Itest git/.config/git/worktree-tools/test/conductor_scripts_test.rb`. Watch it fail: 3 runs, 2 failures, 1 error. This is the walking skeleton; the red file is the failing acceptance check.
2. Write `test_setup_leaves_env_local_unchanged`. In a `rails_workspace`, write `.env.local` with `EXISTING=value\n`, stub `worktree-setup`, run `setup`, and assert the file content is still exactly `EXISTING=value\n`.
3. Write `test_run_does_not_export_database_name_from_env_local`. Use `rails_workspace(..., bin_dev: true)`, whose `bin/dev` logs `PORT`; overwrite that `bin/dev` so it also logs `DATABASE_NAME=${DATABASE_NAME:-}`. Write `.env.local` with `DATABASE_NAME=workspace_db\n`. Run `run`. Assert `command_log` includes `DATABASE_NAME=` with an empty value and does not include `workspace_db`.
4. Write `test_archive_runs_no_database_command`. Stub `bundle` and `rails` with `write_executable`, each logging `<name> $*` to `@log_file`. Write `.env.local` with `DATABASE_NAME=workspace_db\n`. Run `archive`. Assert `command_log` has no line that starts with `bundle` or `rails`.
5. Run `ruby conductor/.config/conductor/scripts/test/scripts_test.rb`: 10 runs, 0 failures, 0 errors.
6. Prove each new test can fail, without touching tracked files. Copy the whole `conductor/.config/conductor/scripts/` directory, `test/` included, to a scratch directory outside the repository. In the copy, overwrite one script with its #28 version, for example `git show 1cde559e:conductor/.config/conductor/scripts/archive > <scratch>/scripts/archive`, and `chmod +x` it. Run the copied test file, `ruby <scratch>/scripts/test/scripts_test.rb -n <test name>`; its `SCRIPT_DIR` resolves to the copy. Watch the matching new test fail. Do this for `setup`, `run` and `archive`. The #28 `setup` calls `git worktree list`, `rv ci` and `bundle exec rails`; if it cannot get far enough in the sandbox to write `.env.local`, edit the copied current `setup` to append a line to `.env.local` instead, and record that.
7. Delete `git/.config/git/worktree-tools/test/conductor_scripts_test.rb` with `git rm`.
8. Run every other file in `git/.config/git/worktree-tools/test/` one at a time with `ruby -Itest <file>`. All must be green; report any failure that exists on `main` too, rather than fix it here.
9. Scratch workspace check: under the session scratchpad, make a Rails-shaped workspace with `.env.local` holding `DATABASE_NAME=workspace_db`, a `bin/dev` that prints `DATABASE_NAME`, and logging `bundle` and `rails` stubs on `PATH`. Run the real `run` and `archive` scripts there. Record the output as evidence in the change folder's review or pull request body: `run` prints `DATABASE_NAME=` and `archive` calls neither stub.
10. Lint: `rubocop conductor/.config/conductor/scripts/test/scripts_test.rb`. Fix every offence without disable comments.
11. Commit in two commits, each one logical change: first the three new tests, then the deletion of the stale file. Both commit messages name #48 as the reason.

## Risks

- Etienne may still want some of the `DATABASE_NAME` handling, for example for a personal project with a database per workspace. The gate asks about each script separately; any "yes" voids this plan. Rejected as the default here because #48 removed the behaviour on purpose, documented it twice, and dropped a `rails db:drop` that ran on every workspace removal.
- Rejected: rewriting the stale file in place to assert the current behaviour, which keeps "3 runs" in criterion 1 literally true. It duplicates the scripts test and games the criterion.
- Rejected: moving the stale file's assertions into the scripts test unchanged. They would stay red.
- Rejected: proving the new tests can fail by overwriting the tracked scripts and restoring them with `git checkout`. Step 6 uses a scratch copy, so no tracked file is at risk.
- Step 6 may not be able to run the #28 `setup` in the sandbox. The fallback in step 6 still proves the assertion can fail.
- Nothing runs these tests automatically, so a future stale test can go unnoticed again. Adding them to a hook or CI is out of scope per `intent.md`.

## Out of scope

- `test/review_report_check_test.rb` (intent `review-report-test-bypasses-guard`).
- Adding the worktree-tools or Conductor tests to CI or lefthook.
- Any change to the Conductor scripts or their READMEs.
- Other Conductor behaviour not exercised by the three stale tests.

## Proof

- `ruby -Itest git/.config/git/worktree-tools/test/conductor_scripts_test.rb` passes: 3 runs, 0 failures, 0 errors → cannot hold, since the file is deleted as stale; gate question 4. Replacement: `git ls-files git/.config/git/worktree-tools/test/conductor_scripts_test.rb` prints nothing, and `ruby conductor/.config/conductor/scripts/test/scripts_test.rb` passes with 10 runs, 0 failures, 0 errors.
- A Conductor workspace whose `.env.local` sets `DATABASE_NAME` gets that value in `run` and `archive` → contradicts #48; gate questions 2 and 3. Replacement: `conductor/.config/conductor/scripts/test/scripts_test.rb` `test_setup_leaves_env_local_unchanged`, `test_run_does_not_export_database_name_from_env_local` and `test_archive_runs_no_database_command`, plus check: the scratch workspace run in step 9, with its output recorded.

Per changed file, the unit tests expected, named as behaviour:

- `conductor/.config/conductor/scripts/test/scripts_test.rb`: `setup leaves an existing .env.local unchanged`, `run does not export DATABASE_NAME from .env.local to bin/dev`, `archive runs no database command`.
- `git/.config/git/worktree-tools/test/conductor_scripts_test.rb`: deleted; no tests.

Test setup: the existing helpers in `scripts_test.rb` — a temporary `HOME`, a `PATH` of the stub `bin` directory plus `/usr/bin:/bin`, executable stubs that log to `commands.log`. No new helpers.

---
Domain skills applied: systematic-debugging, rails-testing, dotfiles-maintenance.

## Critique

### Round 1 (codex exec -p terra)

- Blocker: deleting the file makes both accepted acceptance criteria impossible, and the gate only acknowledged the conflict → fixed (gate question 4 now requires Etienne to replace the criteria in `intent.md` with the Proof replacements and accept the amended intent before implement starts)
- The cause analysis misstated the #28 `setup`: with `Gemfile.lock` present it ran `rv ci`, not `bundle install` → fixed (Cause now says the test was partly wrong before #48, verified with `git show 1cde559e:conductor/.config/conductor/scripts/setup`)
- Deleting the file loses the only `.env.local` regression for `run`, and the current `run` test never observes `DATABASE_NAME` → fixed (added `test_run_does_not_export_database_name_from_env_local` before the deletion)
- "never calls bundle" does not prove "never drops a database", since a script could call `rails db:drop` directly → fixed (renamed to `test_archive_runs_no_database_command`; it stubs both `bundle` and `rails` and asserts neither runs)
- The mutation check overwrote tracked scripts and restored them with `git checkout`, which risks unstaged work → fixed (step 6 now copies the scripts directory, tests included, to a scratch directory and mutates only the copy)
- The claim that `git grep` finds no reference was false, since `intent.md` names the file → fixed (Integration points now scope the claim to files outside this change folder)
- The gate offered a false choice: restoring `DATABASE_NAME` loading does not require restoring the `archive` database drop → fixed (gate now asks about `setup`, `run` and `archive` separately, and question 3 separates loading from dropping)
