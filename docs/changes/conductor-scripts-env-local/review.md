# Review: conductor-scripts-env-local

## Round 1 — 2026-10-13T08:37Z — 5ccd024e

The repository has no `REVIEW.md` or `REVIEW.local.md`, so this round uses the reviewer's default passes: Bugs, Security, Compliance.

- [ ] Important: `test_run_does_not_export_database_name_from_env_local` depends on the caller's environment. `run_script` merges `base_env` into the parent `ENV`, so a `DATABASE_NAME` already exported in the shell reaches `bin/dev`. Verified: `DATABASE_NAME=leaked ruby conductor/.config/conductor/scripts/test/scripts_test.rb -n test_run_does_not_export_database_name_from_env_local` fails with `Expected "DATABASE_NAME=leaked\n" to include "DATABASE_NAME=\n"`. Workspaces that load `.env.local` through direnv or a shell hook hit this. Unset the variable for this run (a `nil` value in the env hash unsets it in `Open3`). — `conductor/.config/conductor/scripts/test/scripts_test.rb:97` →
- [ ] Nit: Plan steps 6 and 9 say to record the mutation and scratch-workspace evidence in this folder or the pull request body. The branch records neither. The pull request body must carry it; the results of this round, below, can serve. — `docs/changes/conductor-scripts-env-local/plan.md:56` →

### Bugs

Nothing beyond the Important finding. Each new test goes through `run_script`, which flunks on a non-zero exit, so no test passes on a crashed script. `refute_match(/^(bundle|rails)\b/, ...)` anchors per line, as intended.

### Security

Nothing found. The diff touches only tests; no secrets, no external input.

### Compliance

- Criterion 1, stale file gone and scripts test green: holds. `git ls-files git/.config/git/worktree-tools/test/conductor_scripts_test.rb` prints nothing. `ruby conductor/.config/conductor/scripts/test/scripts_test.rb` gives 10 runs, 22 assertions, 0 failures, 0 errors.
- Criterion 2, `run` prints `DATABASE_NAME=`: `test_run_does_not_export_database_name_from_env_local` (subject to the Important finding).
- Criterion 2, `archive` calls neither `bundle` nor `rails`: `test_archive_runs_no_database_command`.
- Criterion 2, the new tests fail against the pre-#48 scripts: verified in a scratch copy with the `eb296b4c^` scripts.
  - `run`: fails, `Expected "DATABASE_NAME=workspace_db\n" to include "DATABASE_NAME=\n"`.
  - `archive`: fails, `Expected /^(bundle|rails)\b/ to not match "bundle exec rails db:drop\n"`.
  - `setup`: the pre-#48 script exits 1 in the sandbox before it writes `.env.local` (bundler `NameError: uninitialized constant Gem::NameTuple`). With the plan's fallback, the current `setup` plus one line that appends to `.env.local`, the test fails on the byte diff `+DATABASE_NAME=x`.
- Proof tests: all three named tests exist with the planned names.
- Deleted test: `git/.config/git/worktree-tools/test/conductor_scripts_test.rb`. The accepted intent scopes this deletion, and the plan shows the file is stale since #48. Not a finding.
- Files changed match the plan's list; no unplanned file. Two commits, one logical change each, both naming #48.
- Plan step 8: every other file in `git/.config/git/worktree-tools/test/` is green (caddy 13, config 24, file_cleaner 6, git_alias 1, post_checkout_hook 1, remove 1 runs; 0 failures, 0 errors).
- Lint: `rubocop conductor/.config/conductor/scripts/test/scripts_test.rb` reports no offences.

Totals: 1 Important, 1 Nit.
