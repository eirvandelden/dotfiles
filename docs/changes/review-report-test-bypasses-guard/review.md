# Review: review-report-test-bypasses-guard

## Round 1 — 2026-10-13T08:32:56Z — e886dd2b

No `REVIEW.md` or `REVIEW.local.md` at the repository root; the reviewer agent's default passes (Bugs, Security, Compliance) apply.

Checks run at `e886dd2b`:

- `ruby -Itest test/review_report_check_test.rb`: 9 runs, 21 assertions, 0 failures, 0 errors.
- `rubocop -c rubocop/.rubocop.yml test/review_report_check_test.rb`: no offenses.
- Baseline: the `origin/main` version of the test file, in a scratch copy, errors with `git commit --quiet -m advance main failed`.
- Mutation: in a scratch copy, `own_commit_range` changed to `return nil`; the target test fails with "no review.md" (1 runs, 1 failures).

Bugs: none found. The helper is the only git entry point in the file, so every setup call skips hooks. `run_script` stays without the option, and `review-report-fresh` only reads git state.

Security: none found. Test-only change; no new commands, inputs or secrets.

Compliance:

- Criterion 1 (the test file passes with the global guard installed) → `test/review_report_check_test.rb` `test_a_change_folder_passes_when_main_gains_a_commit_after_the_branch_point`; verified above.
- Criterion 2 (the test still fails if `review-report-fresh` stops accepting a change folder after main advances) → one-off mutation check from plan step 5; reproduced above.
- Plan `## Proof`: no new tests named; all nine existing tests exist with unchanged names and assertions.
- No test weakened, skipped or deleted. Only the private `git` helper changed.

Findings:

- [x] Nit: Plan step 5 says to record the mutation output as evidence for criterion 2, but no commit or file on the branch records it; this round now holds a reproduction — `docs/changes/review-report-test-bypasses-guard/plan.md:36` → dismissed: this round records the mutation reproduction (1 runs, 1 failures, "no review.md"), and the delivery account repeats it; a separate evidence file adds nothing.
