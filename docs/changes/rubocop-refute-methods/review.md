# Review: rubocop-refute-methods

## Round 1 — 2026-09-29T13:34Z — 5e121e01

Suite state: every `test/*_test.rb` green except the 2 known local-only failures in `test/lefthook_pull_hooks_test.rb` (`test_pull_does_not_overwrite_hook_scripts`, `test_pull_with_local_commit_uses_rebase_path_and_migrates`), which predate this branch. `test/rubocop_fallback_test.rb` passes locally (2 runs, 0 skips). `rubocop -c rubocop/.rubocop.yml` on the 14 touched `.rb` files: no offenses.

Bugs: nothing found. The 13 helper removals map one-to-one onto `refute` / `refute_match`; explicit failure messages move across, and only the auto-built defaults were dropped, which Minitest already prints.

Security: nothing found.

Compliance:

- Plain Minitest file gets no `Rails/RefuteMethods` / `Rails/AssertNot` offense — `test/rubocop_fallback_test.rb` `test_fallback_reports_no_rails_assertion_offense_in_a_plain_minitest_file`.
- Autocorrect leaves `refute`, `refute_match`, `assert !` unchanged — `test/rubocop_fallback_test.rb` `test_fallback_autocorrect_leaves_refute_and_assert_bang_unchanged`.
- No test file defines `assert_not` / `assert_no_match`, suite passes — `git grep -n 'def assert_not\b\|def assert_no_match' test` prints nothing; suite green apart from the known failures.
- `assert_not_logged` fails on a match, passes on no match — existing `test/editor_test.rb` tests cover the passing case; failing case is the one-time mutation check (plan step 4), not a committed test, as the plan's Proof section says.
- `refute_command_ran` fails when the command ran, passes when it didn't — `test/lefthook_pull_hooks_test.rb:111` covers the passing case; failing case is the one-time mutation check (plan step 4), as the Proof section says.
- Rails projects with `config/rails.yml` still get both cops — no automated test, accepted in spec; the gem is not touched by the diff.
- Tests named in `plan.md` `## Proof`: both `test/rubocop_fallback_test.rb` tests exist with the exact names.
- Weakened, skipped or deleted tests: none. Only local helper methods were deleted, no test methods.

Findings:

- [ ] Nit: the offense test can pass without RuboCop ever inspecting the fixture. `run_fallback` only skips on exit status 2 and discards stderr otherwise, so a RuboCop run that prints nothing to stdout for any other reason (a cop crash reported on stderr, the file being excluded) gives an empty offense list and a green test. The RED step showed it failing before the fix, so it works today; an assertion that the fixture was inspected would keep it from going vacuous later — `test/rubocop_fallback_test.rb:68` →
- [ ] Nit: the autocorrect test compares the whole fixture file, so any other fallback cop that autocorrects the fixture in the future (for example a frozen-string-literal or style cop) fails it with a message that looks like the Rails assertion bug coming back — `test/rubocop_fallback_test.rb:54` →
- [ ] Nit: sentence break typo in plan step 4.1: "(for example `/nvim/`), For `refute_command_ran`" — `docs/changes/rubocop-refute-methods/plan.md:37` →
