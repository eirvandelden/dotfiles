# Review: hooks-unset-git-dir

## Round 1 — 2026-11-06T19:55Z — 1799a57b

No `REVIEW.md` or `REVIEW.local.md` in the repository; the reviewer's default passes ran (Bugs, Security, Compliance, Design).

Checks: `ruby test/lefthook_local_hooks_test.rb` 15 runs green; `ruby test/hook_scripts_test.rb` 4 runs green; rubocop clean on the test file. `bin/test`: 114 files, 1 failed, `test/secrets_loader_test.rb` with 5 failures; the same 5 fail on an export of `origin/main`, so they predate this branch and are not findings here (rule 25 still asks for a separate fix). The two new tests fail on `origin/main`'s hook scripts (`GIT_DIR=<repo>/.git/worktrees/linked`) and pass on this branch, so the regression tests come first as rule 3 asks. Shellcheck reports SC2166 on line 3 of both hook scripts; that line predates the branch and lefthook's `*.{sh,bash}` glob does not cover these files.

Compliance:

- In a linked worktree, a lefthook command run by `pre-commit` sees no `GIT_DIR` → `test_pre_commit_runs_lefthook_without_git_dir_in_a_linked_worktree`.
- In a linked worktree, a lefthook command run by `pre-push` sees no `GIT_DIR` → `test_pre_push_runs_lefthook_without_git_dir_in_a_linked_worktree`.
- The existing hook tests stay green → `ruby test/lefthook_local_hooks_test.rb`, green; no existing test weakened, skipped or deleted.
- Manual: a commit in `cityofbrass/.worktrees/56-monster-powers` passes the rubocop hook → missing, see the second finding.
- Every test named in `plan.md`'s `## Proof` exists.

Findings:

- [x] Important: The unconditional `unset GIT_DIR` breaks every repository used through `--git-dir`/`--work-tree` without a `.git` in the work tree (the bare-repository dotfiles pattern). Git exports `GIT_DIR` there too; once it is gone, lefthook runs `git rev-parse` from the work tree, gets "fatal: not a git repository", exits 128, and the commit is refused. Reproduced in the scratchpad: `git --git-dir=gd --work-tree=wt commit` fails with this branch's `pre-commit` and succeeds with `origin/main`'s. `plan.md`'s Risks names only commands that read `GIT_DIR`, not this case. Unset it only when discovery from the working directory finds the same repository (for example when `$_root/.git` exists), or record the case as accepted in `plan.md` — `git/.config/git/hooks/pre-commit:86`, `git/.config/git/hooks/pre-push:86` → fixed (Keep GIT_DIR for a work tree without a .git entry)
- [x] Important: The manual acceptance criterion has no evidence. `~/.config/git/hooks/pre-commit` links into the main checkout, which is on `main` without `unset GIT_DIR`, so the cityofbrass commits at 20:52 +0100 today did not run this branch's hook scripts. Commit in `cityofbrass/.worktrees/56-monster-powers` with this branch's hook scripts on the hooks path (for example `git -c core.hooksPath=<this worktree>/git/.config/git/hooks commit`) and record the result — `docs/changes/hooks-unset-git-dir/intent.md:28` → fixed (Record the manual hook evidence in the plan)
