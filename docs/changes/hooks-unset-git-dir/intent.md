# Intent: Global git hooks run lefthook without GIT_DIR

Author: Etienne van Delden. Status: accepted. Type: bug fix.

## Problem

Git exports `GIT_DIR` to its hooks. In a linked worktree it is the absolute path of the worktree's git directory. The global `pre-commit` and `pre-push` shims in `git/.config/git/hooks/` pass it on to lefthook and every command lefthook runs. A repository with its own `lefthook.yml` (cityofbrass) runs `rv run bundle exec rubocop`. Bundler then checks a gem from a git source against the project's repository instead of the gem's own checkout, and fails: "Your bundle is locked to exception_notification-campfire-once (0.1.0.pre.git.8472c72) ... can no longer be found in that source". Commits and pushes from a cityofbrass worktree fail. The dotfiles `lefthook.yml` already unsets `GIT_DIR` per command, but only repositories without their own `lefthook.yml` use it.

## Proposed outcome

The `pre-commit` and `pre-push` shims unset `GIT_DIR` before they call lefthook. Lefthook and its commands find the repository from the working directory. A commit and a push from a cityofbrass worktree pass the hook.

## Affected users and systems

- `git/.config/git/hooks/pre-commit`, `git/.config/git/hooks/pre-push`.
- Every repository and worktree that uses the global hooks path.

## Scope

In: the two shims, a test in `test/lefthook_local_hooks_test.rb`.

Out: the other shims (`commit-msg`, `post-*`, `prepare-commit-msg`); the per-command `unset GIT_DIR` lines in the dotfiles `lefthook.yml`, which stay; `GIT_INDEX_FILE` and `GIT_WORK_TREE`, which stay set.

## Acceptance criteria

- In a linked worktree, a lefthook command run by `pre-commit` sees no `GIT_DIR`.
- In a linked worktree, a lefthook command run by `pre-push` sees no `GIT_DIR`.
- The existing hook tests stay green.
- Manual: a commit in `cityofbrass/.worktrees/56-monster-powers` passes the rubocop hook.

## Decisions

- Etienne chose the shim fix over a per-repository `lefthook.yml` fix and over skipping the hook (2026-11-06).
