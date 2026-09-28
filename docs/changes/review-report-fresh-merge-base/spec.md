# Spec: scope `review-report-fresh`'s code-commit check to the branch

From `intent.md` (2026-09-25). Status: accepted.

## Requirements

- `code_commit` considers only commits in the range `<merge-base>..HEAD`, never all history
  reachable from `HEAD`.
- The merge-base is computed against a base branch resolved the same way `start-review.sh`
  resolves it: `origin/HEAD` (via `git symbolic-ref --short refs/remotes/origin/HEAD`), falling
  back to local `main`, then local `master`.
- No base branch resolves (no `origin/HEAD`, no local `main` or `master`): fall back to the
  script's current behavior (all history reachable from `HEAD`), so the check still degrades to
  something rather than crashing.
- When there is no code commit in that range, the script exits 0 regardless of `review.md`.
- All other behavior is unchanged: a code commit newer than `review.md` (or no `review.md` at
  all) still refuses; uncommitted files outside the change folder still refuse; an
  artifact-only edit still passes.

## Design decisions

- Resolve the base branch once, at the top of the script, the same way `folder` and
  `folder_in_head?` already gate early exits — a missing base branch is not fatal to the whole
  script.

## Integration points

- `git/.config/git/worktree-tools/review-report-fresh` (the script).
- `herdr/.config/herdr/scripts/start-review.sh` (the base-branch resolution to mirror, not to
  share code with — different language, same order).
- `test/review_report_check_test.rb` (extended coverage).

## Acceptance criteria

- A branch off `main` with only `docs/changes/<slug>/intent.md` committed, and `main` itself
  gaining a further commit after the branch point, passes with no `review.md`.
- The same branch, once it adds a code commit of its own with no `review.md`, fails.
- The same branch, once `review.md` is added after that code commit, passes.
- The six existing cases in `test/review_report_check_test.rb` stay green (they use a single
  branch off `main` with no further `main` commits, so the merge-base and `HEAD` history
  coincide there).

---
Domain skills applied: None (dotfiles tooling, not Rails/Ruby-on-Rails domain code).
