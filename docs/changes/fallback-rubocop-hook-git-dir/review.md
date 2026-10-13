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

- [x] Nit: The pre-commit comment says the gem's git call "reads the project repository". That holds only in a linked worktree, where `GIT_DIR` is absolute. In a main checkout git exports a relative `.git`, which resolves against the gem's directory, so the call finds no repository. Both break the version; the comment names only one — `lefthook.yml:27` → fixed (Name both ways a leaked GIT_DIR breaks the gem version)
- [x] Nit: The push tests ignore the result of the setup commit made with `hooks: false`. If that commit fails, the test fails later on `1 file inspected` or on the push status, which hides the real cause — `test/lefthook_rubocop_git_gem_test.rb:104` and `:123` → dismissed: the bugfix test guard protects the committed reproduction test, and Etienne chose to keep it unchanged.
- [x] Nit: `restore_dynamic_gemspec` takes `Dir.glob(...).first` without a guard. If a Bundler release changes the checkout layout, the test errors with a `TypeError` on `nil` instead of a message that names the missing checkout — `test/lefthook_rubocop_git_gem_test.rb:205` → dismissed: the bugfix test guard protects the committed reproduction test, and Etienne chose to keep it unchanged.
- [x] Nit: `shared_built` is set only after the whole shared build succeeds. If `bundle install` fails, the next test runs `init_and_commit` again on the already-committed gem repository, `git commit` fails with nothing to commit, and every later test reports that error instead of the first cause — `test/lefthook_rubocop_git_gem_test.rb:179` → dismissed: the bugfix test guard protects the committed reproduction test, and Etienne chose to keep it unchanged.
- [x] Nit: Plan step 8 says to commit the test and the fix together as one logical change. The branch has them as two commits (c51fce47 tests, 4aacbdc3 fix). This matches the implement skill's split mode, but the plan text and the history disagree — `docs/changes/fallback-rubocop-hook-git-dir/plan.md:58` → dismissed: the implement skill's split mode commits the tests and the fix separately, on purpose; the history follows the skill.

## Round 2 — 2026-10-13T07:38Z — 3d6f95de

No `REVIEW.md` or `REVIEW.local.md` at the repository root, so the default passes from `new-repo-setup/references/REVIEW.md` apply.

Checks run:

- `test/lefthook_rubocop_git_gem_test.rb`: 6 runs, 35 assertions, 0 failures (44 s).
- `yamllint lefthook.yml` and `rubocop test/lefthook_rubocop_git_gem_test.rb`: clean.
- `git merge-tree` of HEAD and `origin/main`: merges clean. `origin/main` changes neither `lefthook.yml`, the hook shims nor any `test/lefthook_*` file since the branch point.
- `origin/fallback-rubocop-hook-git-dir` is at 436def72, the pre-rebase intent and plan only. No pull request exists yet.

Changes since round 1: 4dfd6a71 rewords the pre-commit comment to name both the absolute and the relative `GIT_DIR` case; 3d6f95de closes Nits 2–4. All round 1 findings are closed.

Bugs: nothing Important found. Both `run` block scalars keep `unset GIT_DIR` on the first line, so a lefthook split of a long `{staged_files}` or `{push_files}` list repeats it in each chunk. Tags, globs, flags and `stage_fixed` are unchanged.

Security: nothing found.

Compliance: unchanged from round 1. Criteria 1–5 each map to the named test in `plan.md`'s `## Proof`, and all six tests exist and pass. Criteria 6–9 follow after the merge by design. No existing test was weakened, skipped or deleted. Only the two planned files changed, plus the change folder.

- [x] Nit: The branch is 79 commits behind `origin/main`. Playbook rule 20 asks for a rebase onto the latest `main` before the push; the remote branch also needs `--force-with-lease`, because it still holds the pre-rebase 436def72 — `lefthook.yml:27` → fixed (rebased onto origin/main ccb0f437; push uses --force-with-lease)
- [x] Nit: The test's header comment still says the gem's git call "reads the project's repository". Round 1 corrected the same wording in `lefthook.yml` to name the relative `.git` case too. The test runs only in a linked worktree, so the sentence is true for the test, but not as the general cause it states — `test/lefthook_rubocop_git_gem_test.rb:9` → dismissed: the bugfix test guard protects the committed reproduction test, and Etienne chose to keep it unchanged; the sentence holds for the linked worktree the test uses.

## Round 3 — 2026-10-13T08:45Z — b13ab605

No `REVIEW.md` or `REVIEW.local.md` at the repository root, so the default passes from `new-repo-setup/references/REVIEW.md` apply.

Checks run:

- `git fetch origin`: the merge base is `origin/main` ccb0f437, so the branch is 0 commits behind. `origin/fallback-rubocop-hook-git-dir` still holds the pre-rebase 436def72, so the next push needs `--force-with-lease`, as round 2 recorded.
- `git range-diff` against round 2's 3d6f95de: the fix and the comment commits are identical after the rebase. Since round 2, only `review.md` changed.
- `test/lefthook_rubocop_git_gem_test.rb`: 6 runs, 35 assertions, 0 failures (33 s).
- With `LEFTHOOK_BIN` unset, after the rebase: `lefthook_global_hooks_sync_test.rb`, `lefthook_local_hooks_test.rb`, `lefthook_posix_sh_test.rb`, `lefthook_pull_hooks_test.rb` and `rubocop_fallback_test.rb` all pass. These are the tests that read `lefthook.yml` or the hook shims.
- `yamllint lefthook.yml` and `rubocop test/lefthook_rubocop_git_gem_test.rb`: clean.

Bugs: nothing Important found. The diff to `lefthook.yml` is unchanged from round 2.

Security: nothing found.

Compliance: unchanged from round 2. Criteria 1–5 each map to the named test in `plan.md`'s `## Proof`, and all six tests exist and pass. Criteria 6–9 follow after the merge by design. No existing test was weakened, skipped or deleted. Only the two planned files changed, plus the change folder. All round 1 and round 2 findings are closed.

- [x] Nit: Plan step 9 says "Push, and open a pull request against `origin`". The playbook now says only `finish` opens a pull request, after it removes the change folder, and the consent guard refuses `gh pr create` while the folder exists. Open the pull request through `finish`, and carry the round 1 red output (criterion 5) into its body — `docs/changes/fallback-rubocop-hook-git-dir/plan.md:59` → fixed (no code change: /finish opens the pull request, and its body carries the round 1 red output)
