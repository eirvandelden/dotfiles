# Plan: Review-report test commits on main despite the branch guard

From `intent.md` (2026-10-12). Status: accepted.

## Context

`test/review_report_check_test.rb` builds a temporary git repository and calls git through one private helper, `git(*arguments)` (line 131). Every commit in the setup goes through `write_and_commit`, which calls that helper. The helper sets `commit.gpgsign`, `user.email` and `user.name`, but not `core.hooksPath`. The global git config sets `core.hooksPath = ~/.config/git/hooks`, so lefthook's global hooks run on each commit in the temporary repository. The main/master guard refuses the commit `advance main` in `test_a_change_folder_passes_when_main_gains_a_commit_after_the_branch_point`, and the helper raises `git commit --quiet -m advance main failed`.

Measured on 2026-10-12 at `35f8c1c9`: `ruby -Itest test/review_report_check_test.rb` gives 9 runs, 1 error, in 54.8 s.

## Design decisions

- Add `-c core.hooksPath=/dev/null` to the `git` helper itself, not to the one failing test. Every git call in this file then skips the hooks. This matches the idiom in `test/worktree_pane_test.rb:198`, `test/worktree_create_test.rb:371` and `test/agent_worktree_test.rb:114`. No test in this file is about hooks, so no test loses coverage.
- Side effect: the file runs in about 6 s instead of about 55 s, because lefthook no longer runs on every setup commit. A trial in a scratch copy confirmed 9 runs, 0 failures, 0 errors, 5.97 s.
- No test body, test name or assertion changes. The `run_script` call to `review-report-fresh` stays as it is; that script only reads git state and triggers no hooks.
- The second acceptance criterion is proven by a one-off mutation check, not by a new committed test. The existing test already is the regression test; the mutation shows that it still guards the behaviour once it can run. A trial in a scratch copy confirmed it: with `own_commit_range` forced to return `nil`, the test fails with "last code commit: \"initial\" ... no review.md".

## Integration points

- `git/.config/git/worktree-tools/review-report-fresh` — the script under test. Read only.
- The global lefthook hooks in `~/.config/git/hooks` — bypassed by the test, not changed.
- `rubocop` with `rubocop/.rubocop.yml` — lints the changed test file. The repository root has no `.rubocop.yml`.

## Files that change

- `test/review_report_check_test.rb` — the private `git` helper (lines 131–134) gains `"-c", "core.hooksPath=/dev/null"` before the other `-c` options. Wrap the argument list so each line stays under 120 characters, in the same style as `test/worktree_pane_test.rb:198`.

No other file changes.

## Order of work

1. Run the acceptance test as it is: `ruby -Itest test/review_report_check_test.rb -n test_a_change_folder_passes_when_main_gains_a_commit_after_the_branch_point`. Watch it error with `git commit --quiet -m advance main failed`. This is the failing walking skeleton; the test already exists.
2. Add `"-c", "core.hooksPath=/dev/null"` to the `git` helper.
3. Run the same single test. Watch it pass.
4. Run the full file: `ruby -Itest test/review_report_check_test.rb`. Expect 9 runs, 0 failures, 0 errors.
5. Mutation check in a temporary copy, never in the worktree. The test finds the script by a path relative to itself, so copy the three trees it needs: `tmp=$(mktemp -d) && cp -R test git claude "$tmp"/`. In `$tmp/git/.config/git/worktree-tools/review-report-fresh`, change `return nil if base_branch.nil?` in `own_commit_range` to `return nil`. Run `ruby -Itest test/review_report_check_test.rb -n test_a_change_folder_passes_when_main_gains_a_commit_after_the_branch_point` from `$tmp`. Watch it fail with "no review.md", and record that output as evidence for the second criterion. Then remove `$tmp`. `git status` in the worktree must still show only the test file changed.
6. Run `rubocop -c rubocop/.rubocop.yml test/review_report_check_test.rb`. Fix any offence in the code, never with a disable comment.
7. Run the full suite once, in the loop that `.github/workflows/dotfiles-tests.yml` uses: `for file in test/*_test.rb; do ruby -Itest "$file"; done`. A failure in `test/conductor_scripts_test.rb`, if that file exists on the branch, belongs to intent `conductor-scripts-env-local` and is out of scope. Report it; do not fix it here.
8. Re-read the diff. Commit the test file alone: `test: skip global hooks in review-report check setup`.

## Risks

- A future test in this file that wants to exercise hooks would get none. Accepted: the file tests `review-report-fresh`, which runs as a script, not as a hook. Such a test would pass its own `-c` option.
- A mutation left in a tracked file would ship a broken script. Step 5 mutates only a temporary copy, so the worktree's `review-report-fresh` is never touched.
- Rejected: `--no-verify` on the `commit` call only. It skips `pre-commit` and `commit-msg` but leaves other hooks (for example `post-checkout`) running, and the repository already uses `core.hooksPath=/dev/null` for this purpose.
- Rejected: `LEFTHOOK=0` in the environment. `test/lefthook_posix_sh_test.rb` and `test/lefthook_global_hooks_sync_test.rb` use it, but those files test lefthook itself. Here it would couple a non-hook test to one hook manager; `core.hooksPath=/dev/null` disables every hook whatever installed them.
- Rejected: committing on a branch other than `main` in the test. That changes what the test proves, which the intent forbids.

## Out of scope

- `git/.config/git/worktree-tools/review-report-fresh` itself.
- `test/conductor_scripts_test.rb` (intent `conductor-scripts-env-local`).
- The main/master branch guard and the global hooks.
- The same missing option in other test files.

## Proof

- `ruby -Itest test/review_report_check_test.rb` passes on a machine with the global guard installed → `test/review_report_check_test.rb` `test_a_change_folder_passes_when_main_gains_a_commit_after_the_branch_point`, and the full file run in step 4.
- The test still fails if `review-report-fresh` stops accepting a change folder when `main` gains a commit after the branch point → check: the mutation in step 5 of `## Order of work` (`own_commit_range` returns `nil`, in a temporary copy), run against `test/review_report_check_test.rb` `test_a_change_folder_passes_when_main_gains_a_commit_after_the_branch_point`, must fail with "no review.md".

Per changed file, the unit tests expected:

- `test/review_report_check_test.rb`: no new tests. All nine existing tests pass unchanged, with the same assertions.

Test setup: the existing temporary repository from `setup`; the only change is that its git calls skip the global hooks.

---
Domain skills applied: None (no Ruby production code, no Rails; test-only change in the dotfiles repository).

## Critique

### Round 1 (codex exec -p terra)

- The plan names a repository `.rubocop.yml`, but none exists at the root; the config is `rubocop/.rubocop.yml` → fixed (Integration points and step 6 now use `rubocop -c rubocop/.rubocop.yml`)
- The plan says no test uses `LEFTHOOK=0`, but `test/lefthook_posix_sh_test.rb:63` and `test/lefthook_global_hooks_sync_test.rb:136` do → fixed (Risks now says it couples a non-hook test to one hook manager)
- Step 5 mutates the tracked `review-report-fresh` and restores it with `git checkout --`, which conflicts with the intent's out-of-scope script and can discard edits → fixed (step 5 now mutates a temporary copy of `test`, `git` and `claude`, and the Proof line says so)
- Step 7 says to report a failing `conductor_scripts_test.rb` but not fix it, against playbook rule 25 → dismissed: rule 25 is met by the separate intent `conductor-scripts-env-local`, which fixes that test in its own worktree and pull request; the intent lists it as out of scope, so fixing it here would bundle two changes
