# Review: gh-dash-work-reviews-oldest-first

## Round 1 — 2026-10-20T19:24Z — 00adcf07

No findings.

Checks: `ruby test/gh_dash_config_test.rb` 12 runs, 0 failures. RuboCop and yamllint clean on the touched files. No `REVIEW.md` in the repository, so the reviewer defaults applied.

Bugs: gh-dash v4.26.2 builds the PR query as `is:pr archived:false <filters> sort:updated` (`internal/data/prapi.go:477`). GitHub search keeps the first `sort:` qualifier, so `sort:updated-asc` from the filters wins. Verified with `gh api graphql` against that exact query shape: results come back oldest update first.

Security: nothing. The diff adds one search qualifier and no new work references.

Compliance:

- The `Work reviews` filters contain `sort:updated-asc` and keep every existing token → `test_work_reviews_section_takes_team_requests_i_have_not_reviewed_and_skips_drafts`, present.
- Every other section keeps its filters → the other `filter_tokens` tests, present and unchanged.
- Every test named in `plan.md`'s Proof exists. No test was weakened, skipped or deleted.
