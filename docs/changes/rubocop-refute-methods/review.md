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

## Round 2 — 2026-09-29T15:05Z — 4a5e1a36

Suite state: every `test/*_test.rb` green except the known local-only failures in `test/lefthook_pull_hooks_test.rb`. `test/rubocop_fallback_test.rb`: 2 runs, 13 assertions, 0 skips. `rubocop -c rubocop/.rubocop.yml test/rubocop_fallback_test.rb`: no offenses.

Round 1 nits:

- Nit 1 (vacuous offense test) resolved by `2b3b9943`: the JSON report must list exactly `test/sample_test.rb` as inspected, and stderr must be empty, so an excluded file or a cop crash now fails the test.
- Nit 2 (whole-file comparison) resolved by `2b3b9943`: the autocorrect test checks only that the three assertion lines survive.
- Nit 3 (plan typo) resolved by `b39aa867`.

CI step (`4a5e1a36`): the `gem install` line covers everything `rubocop/.rubocop.yml` loads — `inherit_gem: rubocop-rails-omakase` (whose own `plugins:` are `rubocop-performance` and `rubocop-rails`, both installed too) and all eight entries under `plugins:`. Nothing missing.

Bugs: nothing found beyond the findings below.

Security: nothing found. The new step installs gems from rubygems.org without version pins, which the plan records as an accepted risk.

Compliance: the acceptance criteria and `## Proof` tests are unchanged from round 1 and still pass. Spec concern 2 and the plan's Risks and Out of scope sections are updated to match the workflow change. No test weakened, skipped or deleted.

Findings:

- [ ] Nit: the workflow comment says the list matches what `install/tasks/40_install_default_ruby_gems.sh` installs on every machine, but `RUBY_GEMS` in `packages.conf` has no `rubocop-minitest` (and has `rubocop-factory_bot` and `rubocop-rspec_rails`, which CI does not install). The CI list is the correct one for the fallback; the comment is not accurate. The missing `rubocop-minitest` in `packages.conf` means a fresh machine cannot load the fallback, which is a separate change for another branch — `.github/workflows/dotfiles-tests.yml:20` →
- [ ] Nit: now that CI installs the plugins, the exit-status-2 skip means a plugin that fails to load in CI leaves the job green with only a skip line in the log, so CI stops checking the fallback without anyone seeing it. The plan records this as accepted; noting it because the tradeoff changed when the workflow step was added — `test/rubocop_fallback_test.rb:86` →

## Round 3 — 2026-09-29T15:20Z — ff44e337

Fetch from origin failed (SSH `Permission denied (publickey)`), so the comparison uses the local `origin/main` at `30cf94dd`, which is also the merge base.

Suite state: every `test/*_test.rb` green except the known local-only failures in `test/lefthook_pull_hooks_test.rb`. `test/rubocop_fallback_test.rb`: 2 runs, 13 assertions, 0 skips, with and without `CI=true`. `rubocop -c rubocop/.rubocop.yml test/rubocop_fallback_test.rb`: no offenses.

Round 2 nits:

- Nit 1 (workflow comment claims parity with the installer) resolved by `8cfc1fdc`: the comment now says only that the gems are latest releases, unpinned like `RUBY_GEMS` in `packages.conf`.
- Nit 2 (exit-status-2 skip hides a broken CI run) resolved by `ff44e337`: `skip_unless_ci` flunks when `ENV["CI"]` is set, both for a missing `rubocop` in `setup` and for exit status 2 in `run_fallback`. A flunk in `setup` leaves `@project` nil, and `teardown` already guards on it, so no second error. Exit status 1 still never skips.

Bugs: nothing found beyond the finding below.

Security: nothing found.

Compliance: acceptance criteria and `## Proof` tests unchanged from round 1 and still pass. No test weakened, skipped or deleted; the change makes the skip stricter in CI.

Findings:

- [ ] Nit: the plan's risk line still says CI installs the plugins "the same as `install/tasks/40_install_default_ruby_gems.sh` does on every machine" — the parity claim `8cfc1fdc` removed from the workflow comment, and still not accurate while `packages.conf` lacks `rubocop-minitest` — `docs/changes/rubocop-refute-methods/plan.md:51` →

## Round 4 — 2026-09-29T15:40Z — 8951035c

Fetch from origin succeeded; `origin/main` is `30cf94dd`, which is also the merge base. No uncommitted changes.

Suite state: `test/rubocop_fallback_test.rb` 2 runs, 13 assertions, 0 skips, with and without `CI=true`. `rubocop -c rubocop/.rubocop.yml` on the 14 touched `.rb` files: no offenses. The known local-only failures in `test/lefthook_pull_hooks_test.rb` remain. In this pane `test/worktree_create_test.rb`, `test/worktree_pane_test.rb` and `test/herdr_worker_scripts_test.rb` also error in `setup`: `git commit` in their temporary repos fails with `error: 1Password: agent returned an error`, because commit signing through the 1Password agent is unavailable here. A bare `git init` plus `git commit --allow-empty` outside the suite fails the same way, so this is the environment, not the branch. The two `worktree_create_test.rb` call sites this branch rewrote were green in rounds 1-3.

Round 3 nit:

- Nit 1 (plan risk line claims parity with the installer) resolved by `8951035c`: the line now says the plugins are the ones the fallback loads, unpinned like `RUBY_GEMS` in `packages.conf`.

Bugs: nothing found. The fallback config sets `Enabled: false` for both cops, the comment gives the reason, and `git grep` finds no `assert_not` / `assert_no_match` definitions or calls left under `test/`.

Security: nothing found. The CI step installs unpinned gems from rubygems.org, an accepted risk in the plan.

Compliance: acceptance criteria and `## Proof` tests unchanged from round 1 and still pass. Spec, plan and workflow comment now agree on how the CI gems relate to `packages.conf`. No test weakened, skipped or deleted.

Findings: none.
