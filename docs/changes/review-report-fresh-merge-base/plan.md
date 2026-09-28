# Plan: scope `review-report-fresh`'s code-commit check to the branch

From `intent.md` and `spec.md` (2026-09-28). Status: accepted.

## Context

`git/.config/git/worktree-tools/review-report-fresh` (the `lefthook.yml` pre-push hook) refuses
a push when a `docs/changes/<slug>/` folder's `review.md` is not at least as new, in commits, as
the last commit touching anything outside that folder. Its `code_commit` helper currently looks
at *all* history reachable from `HEAD` for the last commit touching paths outside the folder.
That includes the branch's own parent commit (the tip of `main` at branch time) whenever that
commit touched code — which it almost always does. So a brand-new branch with only
`intent.md`/`spec.md` committed gets refused: the parent commit shows up as "last code commit"
even though the branch itself hasn't touched any code. Observed 2026-09-25 on `stage-handoffs`,
first push ever.

Fix: restrict the search to `<merge-base-with-base-branch>..HEAD`, exclusive of the merge-base
itself — the same range `git log` conventionally uses to mean "what this branch added." Base
branch resolution mirrors `herdr/.config/herdr/scripts/start-review.sh` (lines 24-33): local
`origin/HEAD` first, then local `main`, then local `master`. If none resolve, fall back to the
current unrestricted behavior rather than erroring.

## Files that change

- `git/.config/git/worktree-tools/review-report-fresh` — add base-branch resolution and a
  commit range, thread it through `code_commit`.
- `test/review_report_check_test.rb` — three new cases proving the range restriction; six
  existing cases must stay green unmodified.

## Order of work

1. Add a failing acceptance-level test to `test/review_report_check_test.rb`:
   `main` gets a real code commit as its tip, a fresh branch is cut from there, and only an
   artifact file is committed on the branch. Run it, watch it fail (current code reports the
   branch-point commit as "last code commit").
2. In `review-report-fresh`, add `resolved_base_branch` (mirrors `start-review.sh`'s
   `origin/HEAD` → local `main` → local `master` order, using `git symbolic-ref` and
   `git rev-parse --verify --quiet refs/heads/<name>`).
3. Add `merge_base(base)`, returning the merge-base SHA with `HEAD`, or `nil` if `base` is `nil`
   or the `git merge-base` call fails.
4. Extend `latest_commit` to accept an optional range argument (`"<sha>..HEAD"`) inserted into
   the `git log` invocation ahead of the `--` pathspec separator.
5. Change `code_commit` to take the range and pass it through; compute the range once at the top
   of the script from `resolved_base_branch` + `merge_base`, `nil` when either step comes back
   empty. `review_commit` keeps searching unrestricted history — a review can predate the
   merge-base range and still count as covering nothing.
6. Run the new test, confirm it goes green. Add the other two cases from `spec.md`'s acceptance
   criteria (code commit on the branch with no `review.md` → exit 1; `review.md` added after →
   exit 0) reusing the same main-has-code / fresh-branch setup, confirm green.
7. Run the full `test/review_report_check_test.rb` file, then the full `test/` suite.
8. Lint (project's Ruby linter, whatever `lefthook.yml`/`Rakefile` in this repo already runs on
   `.rb` files under `test/` and `git/.config/git/worktree-tools/`).
9. Re-read the diff; commit as one logical change (small, domain-language message, per `agents.md`
   rule 18/21).

## Risks

- Rejected alternative: restrict by "commits not on `main`" via `git rev-list HEAD ^main`
  instead of merge-base range. Equivalent in the common case but doesn't match
  `start-review.sh`'s own resolution order (would silently prefer `main` over `origin/HEAD`),
  and the spec calls for mirroring that script exactly.
  Rejected alternative: hardcode `origin/main`. Breaks in a repo whose default branch is
  `master`, and breaks in a single-branch clone with no `origin` at all (the existing test setup
  has no `origin` — see below), which `start-review.sh` already handles by falling back to local
  branches.
- The test repos in `test/review_report_check_test.rb` are plain `git init` temp dirs with no
  `origin` remote, so `resolved_base_branch` will exercise only the local-`main` fallback path,
  never the `origin/HEAD` path. That branch is still worth having (real repos in this monorepo
  do have `origin`), just not directly covered by this test file. No new test infra needed since
  `start-review.sh`'s equivalent logic is unit-untested too.
- If `git merge-base` fails (e.g. a base branch that shares no history with `HEAD` — shouldn't
  happen in practice since every worktree branches off `origin/<default>`), fall back to
  unrestricted history rather than crashing, matching the "no base branch resolves" fallback.

## Proof

- Acceptance: "a branch with only artifact commits, cut from a `main` that already has code,
  passes with no `review.md`" → `test/review_report_check_test.rb`
  `test_a_change_folder_with_no_code_commits_of_its_own_passes`
- Acceptance: "the same branch, once it adds a code commit of its own with no `review.md`,
  fails" → `test/review_report_check_test.rb`
  `test_a_code_commit_on_the_branch_itself_still_requires_a_review`
- Acceptance: "the same branch, once `review.md` is added after that code commit, passes" →
  already covered by the existing `test_a_review_committed_after_the_last_code_commit_passes`
  (identical shape once code_commit is branch-scoped; no new test needed).
- Remaining five existing cases in `test/review_report_check_test.rb` stay green. The sixth,
  `test_a_change_folder_with_no_review_fails`, asserted the exact bug this change fixes (a
  docs-only branch, cut from a `main` with real code, refused for lack of a review it never
  needed) — renamed to `test_a_change_folder_with_no_code_commits_of_its_own_passes` and its
  assertion flipped to success. Flagged to and confirmed with the user before changing it.

Per changed file, the unit tests expected, named as behaviour:
- `git/.config/git/worktree-tools/review-report-fresh`: covered entirely by the acceptance-level
  cases above — the script has no separate unit-test seam (it's a single top-to-bottom script,
  consistent with its existing test file, which is acceptance-only).

Test setup: reuse the existing `write_and_commit`/`git`/`run_script` helpers already in
`test/review_report_check_test.rb`. Adjust the shared `setup` so `main`'s tip is a real code
commit before `claims-status` is cut from it, rather than the current empty `--allow-empty`
commit — no existing test asserts anything about that commit being empty.

## Out of scope

Everything else in `worktree-tools/`. The `review` and `finish` skills. Any other script.
`start-review.sh` itself is read, not modified — only mirrored.
