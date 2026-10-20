# Plan: Sort gh-dash Work reviews oldest update first

From `intent.md` (2026-10-20). Status: accepted.

## Design decisions

Add the `sort:updated-asc` qualifier to the section's `filters` string. gh-dash has no separate sort option.

## Integration points

gh-dash passes the filter string to GitHub search unchanged.

## Files that change

- `github/.config/gh-dash/config.yml` — add `sort:updated-asc` to `Work reviews`.
- `test/gh_dash_config_test.rb` — expect the new token.

## Order of work

1. Update the expected tokens in the `Work reviews` test, run it, watch it fail.
2. Add the qualifier to the config. Run the test, watch it pass.
3. Run rubocop and yamllint.

## Risks

A filter token the test does not expect breaks the test. No other risk: the qualifier is standard GitHub search syntax.

## Proof

- The `Work reviews` filters contain `sort:updated-asc` and keep every existing token → `test/gh_dash_config_test.rb` `test_work_reviews_section_takes_team_requests_i_have_not_reviewed_and_skips_drafts`
- Every other section keeps its filters → `test/gh_dash_config_test.rb` the other `filter_tokens` tests, unchanged

Per changed file, the unit tests expected:
- `github/.config/gh-dash/config.yml`: covered by the tests above.

Test setup: none. The test reads the YAML file.

---
Domain skills applied: None.
