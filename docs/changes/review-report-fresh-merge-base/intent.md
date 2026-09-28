# Intent: scope `review-report-fresh`'s code-commit check to the branch

Author: coordinating agent (handoff). Status: accepted. Type: bugfix.

## Problem

`review-report-fresh` looks at all commits reachable from `HEAD` to find the "last code commit."
On a fresh branch with only `docs/changes/<slug>/` artifacts committed, main's own latest commit
still counts as code on the branch, so the push is refused even though the branch itself has
touched no code yet.

## Proposed outcome

The check only considers commits between the merge-base with the base branch and `HEAD`. A
branch with no code commits of its own passes regardless of `review.md`, matching spec.md §4:
artifact-only commits are not code.

## Affected users and systems

`git/.config/git/worktree-tools/review-report-fresh` (the `lefthook.yml` pre-push hook) and its
test, `test/review_report_check_test.rb`.

## Constraints

Base branch resolution must match `start-review.sh`: `origin/HEAD`, falling back to local `main`
or `master`. Everything else in the script's contract (review must be at least as new as the
last code commit; working tree clean outside the folder) stays the same.

## Open questions

None.
