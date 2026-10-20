# Plan: gclean skips worktree branches and sweeps merged worktrees

From `intent.md`. Status: accepted.

1. Add `test/gclean_test.rb`: a temporary repository with a merged branch, an unmerged branch and a merged branch checked out in a worktree. It runs `gclean` in zsh with a stubbed `worktree-sweep`. Watch it fail against the alias.
2. Replace the `gclean` alias in `zsh/.config/zsh/aliases.zsh` with a `gclean` function in `zsh/.config/zsh/functions/worktree.zsh`. It runs `worktree-sweep`, deletes merged branches with `git branch -d` except worktree branches, `main` and `master`, then runs `git remote prune origin`.
3. Run the test, then verify by hand in this repository.
