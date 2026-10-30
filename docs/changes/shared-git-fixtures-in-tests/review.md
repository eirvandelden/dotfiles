# Review: shared-git-fixtures-in-tests

## Round 1 — 2026-10-30 09:59:51Z — db7e2859

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the reviewer's default passes ran. Checks: `bin/test` 92 files, 0 failed; `rubocop` on the 29 touched Ruby files, no offenses; `GIT_TRACE=1 bin/test test/deliver_test.rb` shows 2 `git init` lines (baseline 60); no `dotfiles-test*` directory left in `$TMPDIR` after the run.

Compliance, acceptance criteria from `intent.md`:

- `bin/test` ends green → full run above, 0 failed.
- Fewer than 60 `git init` lines for `deliver_test.rb` → measured 2.
- Two tests in either order → `test/git_fixture_test.rb` `test_two_tests_that_share_a_fixture_pass_in_either_order`.
- At most one run root after INT then KILL → `test/test_runner_test.rb` `test_a_runner_killed_after_an_interrupt_leaves_one_run_root`.
- Run root removed after a normal run → `test/test_runner_test.rb` `test_a_run_puts_each_file_under_one_run_root_and_removes_it`.
- A test that changes hooks, config, stash, reflog or worktrees gets its own repository → `test/git_fixture_test.rb` `test_hooks_config_stash_and_worktrees_changed_in_one_copy_stay_out_of_the_next`.
- Unit tests of the fixture helper → all 14 tests named in `plan.md` `## Proof` exist in `test/git_fixture_test.rb`; both `delivery_harness_test.rb` tests and `test_an_interrupt_removes_the_run_root` exist.
- No existing assertion was removed, weakened or skipped in the diff.

- [ ] Important: `GLOSSARY.md` adds the four new terms (Fixture copy, Git fixture, Original, Run root), but `plan.md` says Etienne has not agreed them and that they go to the report as `Decision needed:`; the glossary skill adds a term only after Etienne agrees it. Either get the agreement and update `plan.md:11` and `plan.md:181`, or take the terms out of this branch — `GLOSSARY.md:6` → fixed (Plan: record the agreed glossary terms and the herdr test helpers)
- [ ] Nit: `HerdrWorkerScriptsTest.run_git` and `.init_repository` are new public class methods that `plan.md` `### Signatures` does not list; they have inline RBS signatures, but they are test helpers only — `test/herdr_worker_scripts_test.rb:20` → fixed (Plan: record the agreed glossary terms and the herdr test helpers)
- [ ] Nit: `GitFixture#original` registers a new `Minitest.after_run` hook on every build attempt, so a failed build followed by a retry leaves two hooks for one fixture; harmless because `remove` checks the directory, but one registration per fixture is cleaner — `test/git_fixture.rb:42` → fixed (Register the GitFixture cleanup hook once per fixture)

## Round 2 — 2026-10-30 10:06:07Z — e712b516

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the reviewer's default passes ran. Checks: `bin/test` 92 files, 0 failed; `rubocop` on the 29 touched Ruby files, no offenses; `GIT_TRACE=1 bin/test test/deliver_test.rb` shows 2 `git init` lines (baseline 60); no `dotfiles-test*` directory left in `$TMPDIR` after the full run.

Round 1 fixes hold: `GLOSSARY.md` and `plan.md:11`/`plan.md:194` now agree that Etienne agreed the four terms; `plan.md` `### Signatures` lists `HerdrWorkerScriptsTest.run_git` and `.init_repository`; `GitFixture#initialize` registers the `Minitest.after_run` hook once (`test/git_fixture.rb:21`), and the failed-build test still passes.

Bugs: none found. `repoint` matches the original's path only before `/` or a line end, and copies sit beside the original, so no copy path contains it. `worktree_creatable!` in `herdr_worker_scripts_test.rb` replaces the setup repository; every caller calls it first, before it touches `@repo`. `lefthook_pull_hooks_test.rb` no longer sets `user.name` in pusher and puller, but `setup_env` and `pull_env` give the identity, and `pull_logged` empties the log before each pull, so the dropped clone-time hook run changes no assertion.

Security: none found. Test code and `bin/test` only; no new input reaches a shell.

Compliance: every acceptance criterion maps to the test or check that Round 1 lists, and all of them still pass. All Proof tests in `plan.md` exist. No assertion was removed, weakened or skipped.

Design: no unsigned public method, no Law of Demeter chain, no N+1 loop. `seed` in the four worktree test fixtures names the clone that pushes the first commit, the meaning that `plan.md:14` keeps; it is not the original.

Nothing found.
