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

- [x] Important: No test builds spec acceptance criterion 1 as written — "`main` itself gaining a further commit after the branch point". The renamed test cuts the branch from a `main` whose tip already has code, but `main` never advances after the branch point in any test, so the merge-base path where `main` and `HEAD` diverge is never exercised — `test/review_report_check_test.rb:33` → fixed (Pin merge-base path and restore review hint assertion)
- [x] Important: The flip of `test_a_change_folder_with_no_review_fails` (confirmed with the user, per plan) also dropped its `assert_match(%r{/review}, stderr)` check, and no remaining test asserts the "Run /review, then push again." hint in the refusal message. The new refusal test at line 74 could carry that assertion — `test/review_report_check_test.rb:74` → fixed (Pin merge-base path and restore review hint assertion)
- [x] Important: Spec acceptance criterion 4 still says all six existing cases stay green; the plan records one was renamed and inverted instead. spec.md and plan.md disagree on what was promised — `docs/changes/review-report-fresh-merge-base/spec.md:41` → fixed (Align spec.md with plan.md on the renamed test and base resolution)
- [x] Nit: The `origin/HEAD` branch of `resolved_base_branch` is untested (plan accepts this). A stale local `origin/<default>` — not fetched since the branch was rebased onto a newer local `main` — gives an older merge-base, and main's code commits in between would count as the branch's own, causing a false refusal. Conservative, not unsafe — `git/.config/git/worktree-tools/review-report-fresh:47` → fixed (Align spec.md with plan.md on the renamed test and base resolution)
- [x] Nit: A stacked branch resolves its base as `origin/HEAD`, not its parent branch, so the parent branch's code commits count as its own and need a review. Conservative, and matches `start-review.sh`, but not stated in spec.md — `git/.config/git/worktree-tools/review-report-fresh:46` → fixed (Align spec.md with plan.md on the renamed test and base resolution)

## Round 2 — 2026-09-28T11:58:05Z — 33e90960

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the default passes from `claude/.claude/skills/new-repo-setup/references/REVIEW.md` were used. `test/review_report_check_test.rb` is green (8 runs, 20 assertions, 0 failures); `rubocop` reports no offenses on both changed files. No uncommitted changes.

Bugs: no Important findings. Security: none found — every git call passes arguments as an array, no shell interpolation.

Compliance, acceptance criteria against tests:

- Docs-only branch, `main` gains a commit after the branch point, no `review.md`, passes — `test_a_change_folder_passes_when_main_gains_a_commit_after_the_branch_point`.
- Same branch adds its own code commit, no `review.md`, fails — `test_a_code_commit_on_the_branch_itself_still_requires_a_review` (now also asserts the "/review" hint).
- `review.md` added after that code commit, passes — `test_a_review_committed_after_the_last_code_commit_passes`.
- Five existing cases unchanged and green; the sixth renamed to `test_a_change_folder_with_no_code_commits_of_its_own_passes` and inverted, as spec.md now records.

Plan `## Proof` tests: all named tests exist. No existing test was skipped or deleted beyond the recorded, user-confirmed inversion.

- [x] Nit: A dangling `origin/HEAD` (symbolic ref set, but `refs/remotes/origin/<default>` missing, e.g. after a remote default-branch rename plus prune) still resolves via `git symbolic-ref`, then `git merge-base` fails and `own_commit_range` returns nil. The script falls back to unrestricted history without trying local `main`/`master`, so the original false refusal returns. Verified in a scratch repo: `symbolic-ref` exits 0, `merge-base` exits 128. Conservative, and `start-review.sh` shares the order — `git/.config/git/worktree-tools/review-report-fresh:47` → fixed (Fall through to local main/master when origin/HEAD is dangling)
- [x] Nit: plan.md's "Files that change" still says "three new cases" and "six existing cases must stay green unmodified", which contradicts its own `## Proof` section (two new cases, one renamed and inverted) — `docs/changes/review-report-fresh-merge-base/plan.md:27` → dismissed: change artifacts are removed by finish; wording and wrapping do not outlive this branch
- [x] Nit: The script's header comment still lists only two exit-0 cases (no change folder in HEAD, fresh review); a branch with no code commits of its own is now a third. The new paragraph below implies it but does not say the script exits 0 — `git/.config/git/worktree-tools/review-report-fresh:4` → fixed (Fall through to local main/master when origin/HEAD is dangling)
- [x] Nit: intent.md, spec.md and plan.md are hard-wrapped; playbook rule 26 asks for one line per paragraph and list item in markdown prose — `docs/changes/review-report-fresh-merge-base/spec.md:1` → dismissed: change artifacts are removed by finish; wording and wrapping do not outlive this branch
