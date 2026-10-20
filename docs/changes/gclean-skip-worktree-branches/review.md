# Review: gclean skips worktree branches and sweeps merged worktrees

## Round 1 — 2026-10-20T20:56:56Z — 2f46e23c

The repository has no `REVIEW.md` or `REVIEW.local.md`; the default Bugs, Security and Compliance passes apply. `ruby test/gclean_test.rb` passes (6 runs, 0 failures) and `rubocop` reports no offenses on the test.

Bugs: no Important finding. Security: nothing found; branch names are quoted and git refuses refnames that start with `-`.

Compliance, acceptance criteria from `intent.md`:

- No `branch '+' not found` and no `used by worktree` error: `test_keeps_a_merged_branch_checked_out_in_a_worktree`.
- Delete merged local branches: `test_deletes_a_merged_branch`.
- Keep branches with unpushed work: `test_keeps_a_branch_with_unmerged_work`.
- Never touch a branch checked out in a worktree: `test_keeps_a_merged_branch_checked_out_in_a_worktree`.
- Sweep merged worktrees like `worktree-sweep`: `test_sweeps_merged_worktrees_before_deleting_branches` (stubbed sweep).
- `plan.md` has no `## Proof` list; the test file it names in step 1 exists. No existing test was weakened, skipped or deleted.

- [ ] Nit: `--merged=HEAD` measures "merged" against the caller's HEAD, as the old alias did. From a stacked feature worktree, `gclean` deletes the stack's base branch once it is merged into its upstream. From a main checkout that is behind `origin/main`, branches that `worktree-sweep` judged merged stay. Consider measuring against the default branch that `worktree-sweep` fetches — `zsh/.config/zsh/functions/worktree.zsh:18` → fixed (Measure gclean against origin's default branch)
- [ ] Nit: `test_sweeps_merged_worktrees_before_deleting_branches` proves that the sweep runs, not that it runs before the branch deletion. A stub that removes a merged worktree, followed by an assertion that its branch is gone, would prove the order — `test/gclean_test.rb:65` → fixed (Measure gclean against origin's default branch)
- [ ] Nit: `test_keeps_main_and_the_current_branch` asserts only `main`, which is also the current branch. A current branch other than `main` is not covered by its own test — `test/gclean_test.rb:57` → fixed (Measure gclean against origin's default branch)

## Round 2 — 2026-10-20T21:14:51Z — 4b7f2e89

`ruby test/gclean_test.rb` passes (8 runs, 12 assertions, 0 failures). `rubocop` reports no offenses on the test. `shellcheck -S warning -s bash` passes on `worktree.zsh` and `aliases.zsh`. markdownlint did not run: this worktree has no `node_modules`.

The three round 1 nits hold. `gclean` measures against `origin/HEAD`, which `worktree-sweep` has just fetched. `test_deletes_the_branch_of_a_worktree_that_the_sweep_removed` proves the order. `test_keeps_the_current_branch` covers a current branch other than `main`.

Bugs: no finding. `git branch -D` deletes only branches inside the default branch, so no commit is lost. Without `origin/HEAD` it measures against HEAD, the same set that `git branch -d` accepted before. No other file references `gclean`.

Security: nothing found. Branch names come from `for-each-ref` and stay quoted.

Compliance: every acceptance criterion in `intent.md` keeps its test. `plan.md` step 2 names `git branch -d`; the code uses `-D` after the round 1 fix, and the function comment gives the reason. No test was weakened, skipped or deleted.

No open finding.
