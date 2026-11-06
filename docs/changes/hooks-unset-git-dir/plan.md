# Plan: Global git hooks run lefthook without GIT_DIR

From `intent.md` (2026-11-06). Status: accepted.

## Design

Not affected: one `unset GIT_DIR` line in two shell shims. No objects, signatures or invariants change.

## Design decisions

- Unset `GIT_DIR` in the shim, after `set_global_config` and before `call_lefthook`. `set_global_config` runs `git rev-parse --show-toplevel`, which still works with `GIT_DIR` set; lefthook then finds the repository from the hook's working directory, the work tree root.
- Leave `GIT_INDEX_FILE` set: `git commit -a` and `git commit <path>` point it at a temporary index that lefthook must read.

## Integration points

Every repository and worktree on the global hooks path (`~/.config/git/hooks`, stowed from `git/.config/git/hooks`).

## Files that change

- `git/.config/git/hooks/pre-commit`, `git/.config/git/hooks/pre-push` — add `unset GIT_DIR` before `call_lefthook`.
- `test/lefthook_local_hooks_test.rb` — two tests in a linked worktree of the fixture repository.

## Order of work

1. Write the two tests: a logging lefthook stub records `${GIT_DIR-unset}`. Run them; both fail.
2. Add the line to both shims. Run them; both pass.
3. Run `ruby test/lefthook_local_hooks_test.rb` and `ruby test/hook_scripts_test.rb`, then the repository's full test and lint checks.
4. Manual: in the cityofbrass phase C worktree, commit one file through the hook; it passes.

## Risks

- A lefthook command that relies on `GIT_DIR`. None of the dotfiles or cityofbrass commands do; they already unset it or never read it.

## Proof

- In a linked worktree, a lefthook command run by `pre-commit` sees no `GIT_DIR` → `test/lefthook_local_hooks_test.rb` `test_pre_commit_runs_lefthook_without_git_dir_in_a_linked_worktree`
- In a linked worktree, a lefthook command run by `pre-push` sees no `GIT_DIR` → `test/lefthook_local_hooks_test.rb` `test_pre_push_runs_lefthook_without_git_dir_in_a_linked_worktree`
- The existing hook tests stay green → check: `ruby test/lefthook_local_hooks_test.rb`
- A commit in the cityofbrass phase C worktree passes the rubocop hook → manual: `git commit` in `cityofbrass/.worktrees/56-monster-powers`

---
Domain skills applied: None.
