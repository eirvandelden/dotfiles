# Review: review-report-fresh-merge-base

## Round 1 — 2026-09-28T11:38:16Z — 82b87524

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the default passes (Bugs, Security, Compliance) from `claude/.claude/skills/new-repo-setup/references/REVIEW.md` were used. `test/review_report_check_test.rb` is green (7 runs, 0 failures); `rubocop` reports no offenses on both changed files. No uncommitted changes.

Bugs: none found. Security: none found — every git call passes arguments as an array, no shell interpolation.

Compliance, acceptance criteria against tests:

- Docs-only branch, `main` gains a commit after the branch point, no `review.md`, passes — missing as an automated test (see first finding). Verified by hand in a scratch repo: exit 0.
- Same branch adds its own code commit, no `review.md`, fails — `test_a_code_commit_on_the_branch_itself_still_requires_a_review`.
- `review.md` added after that code commit, passes — `test_a_review_committed_after_the_last_code_commit_passes`.
- Six existing cases stay green — five unchanged and green; the sixth was flipped (see second finding).

Plan `## Proof` tests: both named tests exist.

- [ ] Important: No test builds spec acceptance criterion 1 as written — "`main` itself gaining a further commit after the branch point". The renamed test cuts the branch from a `main` whose tip already has code, but `main` never advances after the branch point in any test, so the merge-base path where `main` and `HEAD` diverge is never exercised — `test/review_report_check_test.rb:33` →
- [ ] Important: The flip of `test_a_change_folder_with_no_review_fails` (confirmed with the user, per plan) also dropped its `assert_match(%r{/review}, stderr)` check, and no remaining test asserts the "Run /review, then push again." hint in the refusal message. The new refusal test at line 74 could carry that assertion — `test/review_report_check_test.rb:74` →
- [ ] Important: Spec acceptance criterion 4 still says all six existing cases stay green; the plan records one was renamed and inverted instead. spec.md and plan.md disagree on what was promised — `docs/changes/review-report-fresh-merge-base/spec.md:41` →
- [ ] Nit: The `origin/HEAD` branch of `resolved_base_branch` is untested (plan accepts this). A stale local `origin/<default>` — not fetched since the branch was rebased onto a newer local `main` — gives an older merge-base, and main's code commits in between would count as the branch's own, causing a false refusal. Conservative, not unsafe — `git/.config/git/worktree-tools/review-report-fresh:47` →
- [ ] Nit: A stacked branch resolves its base as `origin/HEAD`, not its parent branch, so the parent branch's code commits count as its own and need a review. Conservative, and matches `start-review.sh`, but not stated in spec.md — `git/.config/git/worktree-tools/review-report-fresh:46` →
