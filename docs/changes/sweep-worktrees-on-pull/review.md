# Review: Sweep merged worktrees on pull

## Round 1 — 2026-10-09 08:27 UTC — bb90957d

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the default policy from `claude/.claude/skills/new-repo-setup/references/REVIEW.md` applies. Checks run: `test/worktree_sweep_test.rb` (14 runs), `test/worktree_sweep_on_pull_test.rb` (10 runs), `test/worktree_create_test.rb` (28 runs) and `test/lefthook_pull_hooks_test.rb` (13 runs) are green. RuboCop on the 7 changed Ruby files and `yamllint lefthook.yml` report no offenses.

- [ ] Important: The background `git fetch origin <default>` runs in the main checkout and overwrites that checkout's `FETCH_HEAD` (per worktree, checked with git 2.54.0). A second `git pull` in the main checkout while it is on a feature branch can read the sweep's `FETCH_HEAD` between its own fetch and its merge, and then merge `origin/<default>` into the feature branch instead of the branch's upstream. The window is short, but the result is a wrong merge with no message. `git fetch --no-write-fetch-head origin <default>` (checked: works on git 2.54.0) updates `origin/<default>` without that side effect, for the sweep and for `worktree-create` alike — `git/.config/git/worktree-tools/lib/repository.rb:46` → fixed (Keep the sweep's fetch away from FETCH_HEAD)
- [ ] Important: Plan step 12 asks for a human verification in a scratch clone, with "the commands and output" recorded for the review. Neither the change folder nor the commit messages hold that record, so playbook rule 22's evidence is missing — `docs/changes/sweep-worktrees-on-pull/plan.md:57` →
- [ ] Nit: A clean, merged, locked worktree (`git worktree lock`) has its herdr pane closed and `worktree-remove` run before `git worktree remove` refuses it. That order predates this change, but the pull sweep now repeats it on every pull, silently in the background — `git/.config/git/worktree-tools/lib/sweep.rb:86` →
- [ ] Nit: `test_waits_for_a_running_sweep_before_it_fetches_or_creates` proves the wait with a fixed `sleep 2`. When an assertion inside the lock block fails, the block releases the lock and `worktree-create` keeps running while `teardown` deletes its directories — `test/worktree_create_test.rb:296` → fixed (Anchor the lock-wait tests on the lock and stop the waiter in teardown)

Compliance:

- `git pull` on `main` removes `.worktrees/foo`, its branch and its pane → `test_a_pull_on_main_in_the_main_checkout_removes_a_merged_worktree_its_branch_and_its_pane`
- A pull that moves a feature branch inside `.worktrees/bar` removes `.worktrees/foo` → `test_a_pull_that_rebases_a_feature_branch_inside_a_worktree_removes_another_merged_worktree`
- The pull returns at once; the worktree goes shortly after → `test_the_pull_returns_while_the_sweep_is_still_running`
- Dirty, open-PR, never-pushed and detached worktrees remain → `test_dirty_open_pr_never_pushed_and_detached_worktrees_survive_the_pull_sweep`
- A pull inside the merged worktree keeps it → `test_a_pull_inside_a_merged_worktree_keeps_that_worktree`
- Repository A never touches repository B → `test_a_pull_in_one_repository_leaves_another_repositorys_worktrees_alone`
- Own config without a reference removes nothing → `test_a_repository_with_its_own_config_and_no_reference_starts_no_sweep`
- `remotes` reference sweeps → `test_a_repository_that_references_the_global_config_through_remotes_sweeps_on_pull`; `extends` → `test_a_repository_that_extends_the_global_config_sweeps_on_pull`
- `gh` logged out: the pull succeeds with no sweep output → `test_with_gh_logged_out_the_pull_succeeds_and_prints_no_sweep_output`
- `worktree-first` still sweeps → `test_sweep_closes_the_pane_rooted_in_a_merged_worktree_before_removing_it` (existing, unchanged)
- Every unit test the plan's `## Proof` names exists. The three `--detach` cases are two tests: "returns before the sweep finishes" and "prints nothing" share `test_with_detach_it_returns_before_the_sweep_finishes_and_prints_nothing`.
- No existing test was weakened, skipped or deleted. The `worktree_create_test.rb` change only extracts `create_environment` from `run_script`.
- Every file the plan names changed as described; nothing unplanned. `Repository#touch_lock` is an extra public method; decision 7 calls for its behaviour.

Security: nothing found. Branch names reach `git` and `gh` as argument arrays, never through a shell. The lock file lives in the git common directory.
