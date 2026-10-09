# Review: fallback-rubocop-hook-git-dir

## Round 1 — 2026-10-09T08:34Z — 4aacbdc3

No `REVIEW.md` or `REVIEW.local.md` at the repository root, so the default passes from `new-repo-setup/references/REVIEW.md` apply.

Checks run:

- `test/lefthook_rubocop_git_gem_test.rb` on this branch: 6 runs, 0 failures (21 s).
- The same file against the pre-fix `lefthook.yml` (commit c51fce47, in a scratch copy): 5 failures, each with `Unable to find gem house-style`; the canary passes. Criterion 5 holds.
- `yamllint lefthook.yml` and `rubocop test/lefthook_rubocop_git_gem_test.rb`: clean.
- Full suite with `LEFTHOOK_BIN` unset: the only stable failure is the known, out-of-scope `test_a_change_folder_passes_when_main_gains_a_commit_after_the_branch_point`. `test/herdr_worker_scripts_test.rb` had one error in the full run and passed on an isolated rerun; it does not touch the changed files. The run stopped before `worktree_create_test.rb`, `worktree_pane_test.rb` and `worktree_viewer_test.rb` finished; none of them read `lefthook.yml`.

Bugs: nothing Important found. The `unset GIT_DIR` runs only inside the job's shell, so lefthook's own `stage_fixed` re-staging keeps git's environment, and the test for criterion 2 proves it.

Security: nothing found.

Compliance, criteria to proof:

- Criterion 1 → `test_committing_a_clean_ruby_file_passes_after_rubocop_inspects_it`.
- Criterion 2 → `test_committing_a_fixable_offense_commits_the_fixed_file_with_nothing_unstaged`.
- Criterion 3 → `test_pushing_a_clean_ruby_file_passes_after_rubocop_inspects_it`.
- Criterion 4, commit → `test_an_unfixable_offense_blocks_the_commit`.
- Criterion 4, push → `test_an_unfixable_offense_blocks_the_push`.
- Criterion 5 → `test_the_fixture_reproduces_the_bug_when_git_dir_leaks`, plus the red run above. The red output still has to go in the pull request body (plan step 9).
- Criteria 6–9 → after the merge, per the plan's "After the merge" section. Not in this diff by design.

Every test named in `plan.md`'s `## Proof` exists. No existing test was weakened, skipped or deleted. Only the two planned files changed, plus the change folder.

- [ ] Nit: The pre-commit comment says the gem's git call "reads the project repository". That holds only in a linked worktree, where `GIT_DIR` is absolute. In a main checkout git exports a relative `.git`, which resolves against the gem's directory, so the call finds no repository. Both break the version; the comment names only one — `lefthook.yml:27` →
- [ ] Nit: The push tests ignore the result of the setup commit made with `hooks: false`. If that commit fails, the test fails later on `1 file inspected` or on the push status, which hides the real cause — `test/lefthook_rubocop_git_gem_test.rb:104` and `:123` →
- [ ] Nit: `restore_dynamic_gemspec` takes `Dir.glob(...).first` without a guard. If a Bundler release changes the checkout layout, the test errors with a `TypeError` on `nil` instead of a message that names the missing checkout — `test/lefthook_rubocop_git_gem_test.rb:205` →
- [ ] Nit: `shared_built` is set only after the whole shared build succeeds. If `bundle install` fails, the next test runs `init_and_commit` again on the already-committed gem repository, `git commit` fails with nothing to commit, and every later test reports that error instead of the first cause — `test/lefthook_rubocop_git_gem_test.rb:179` →
- [ ] Nit: Plan step 8 says to commit the test and the fix together as one logical change. The branch has them as two commits (c51fce47 tests, 4aacbdc3 fix). This matches the implement skill's split mode, but the plan text and the history disagree — `docs/changes/fallback-rubocop-hook-git-dir/plan.md:58` →
