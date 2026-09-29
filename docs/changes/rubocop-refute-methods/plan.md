# Plan: Stop `Rails/RefuteMethods` and `Rails/AssertNot` firing in non-Rails repos

From `intent.md` and `spec.md` (2026-09-29). Status: accepted.

## Context

`rubocop/.rubocop.yml` is the global RuboCop fallback. It is stowed as `~/.rubocop.yml` and used by every repo without its own config, including this one. It inherits `rubocop-rails-omakase`, which declares `Rails/AssertNot` and `Rails/RefuteMethods` for `test/**/*`. The fallback also declares them for `**/test/**/*`. The lefthook pre-commit hook runs `rubocop -a --force-exclusion` and rewrites `refute`, `refute_match` and `assert !` into `assert_not` and `assert_no_match`. Those methods exist only in Rails' `ActiveSupport::TestCase`, so plain Minitest tests break.

As a workaround, 13 test files in this repo define local `assert_not` / `assert_no_match` helpers.

Checked on 2026-09-28: deleting the two sections from the fallback does not help, because omakase still turns both cops on. `Enabled: false` gives 0 offenses, and `rubocop -a` leaves the file unchanged.

## Files that change

- `test/rubocop_fallback_test.rb` (new): runs the real `rubocop` with `rubocop/.rubocop.yml` against a fixture test file in a temporary folder.
  - Asserts there is no `Rails/RefuteMethods` or `Rails/AssertNot` offense.
  - Asserts `rubocop -a` leaves the file unchanged.
  - Skips with a message when `rubocop` is not on `PATH`, or cannot load the config (exit status 2). This follows the `skip(...) unless CSPELL_DIR` pattern in `test/lefthook_local_hooks_test.rb:29-46`.
- `rubocop/.rubocop.yml` (lines 77-82): replace both `Include:` sections with `Enabled: false`. Keep a short comment giving the reason: omakase declares them, and they rewrite to ActiveSupport-only methods.
- 13 test files, each loses its `assert_not` and/or `assert_no_match` definitions, and call sites are rewritten:
  - `assert_not(x, msg)` becomes `refute(x, msg)`.
  - `assert_no_match(pattern, value, msg)` becomes `refute_match(pattern, value, msg)`.
  - The files: `change_folder_test.rb`, `change_scope_test.rb`, `codex_agent_generation_test.rb`, `editor_test.rb`, `fill_pr_template_test.rb`, `lefthook_local_hooks_test.rb`, `lefthook_posix_sh_test.rb`, `lefthook_pull_hooks_test.rb`, `no_hardwrap_rule_test.rb`, `review_report_check_test.rb`, `rv_ci_fallback_test.rb`, `skill_parity_test.rb`, `worktree_create_test.rb` (all under `test/`).
- Default failure messages move across. `assert_no_match` in `editor_test.rb` and `rv_ci_fallback_test.rb` builds a default message. Minitest's `refute_match` already prints the pattern and the value, so drop the custom default and keep only messages passed in explicitly.
- `test/editor_test.rb` `assert_not_logged` and `test/lefthook_pull_hooks_test.rb` `refute_command_ran`: keep the names and call sites. Their bodies call `refute_match` directly.

## Order of work

1. RED: write `test/rubocop_fallback_test.rb`. Run `ruby -Itest test/rubocop_fallback_test.rb`. Watch it fail with `Rails/RefuteMethods` and `Rails/AssertNot` offenses in the message, not with a skip or a load error.
2. GREEN: set both cops to `Enabled: false` in `rubocop/.rubocop.yml`. Run the new test: green. Commit (config and test together).
3. Rewrite one file at a time, starting with a simple one (`lefthook_posix_sh_test.rb`, 1 call site). For each file:
   1. Delete the helpers and rewrite the call sites.
   2. Run that file and confirm it is green.
   3. Run `rubocop <file>` and confirm it is clean, which also proves the fallback no longer rewrites it.
   4. Commit on green, one small commit per file or per few files.
4. `editor_test.rb` and `lefthook_pull_hooks_test.rb`: rewrite the domain helper bodies too. Check that each helper can still fail, once, by hand:
   1. Temporarily change one `assert_not_logged(/neovide/)` pattern to one the log does match (for example `/nvim/`), and do the same for one `refute_command_ran`.
   2. Watch each test fail.
   3. Revert. Never commit the change.
5. Run the full suite as CI does: `for f in test/*_test.rb; do ruby -Itest "$f" || break; done`. Run `rubocop` on every touched `.rb` file. Re-read the full diff against `origin/main`.
6. Run `git grep -n 'def assert_not\b\|def assert_no_match' test`. It must print nothing.

## Split-mode notes

- The worktree has no root `.rubocop.yml`, so RuboCop uses `~/.rubocop.yml`, which links to the main checkout's `rubocop/.rubocop.yml`. Until this branch merges, that config still has both cops on. Run every commit and push in the worktree with `RUBOCOP_OPTS="-c /Users/etienne.vandelden/Developer/dotfiles/.worktrees/rubocop-refute-methods/rubocop/.rubocop.yml"`. Without it, pre-commit rewrites `refute` into `assert_not` again. Checked on 2026-09-29: `RUBOCOP_OPTS="-c <file>"` overrides the config.
- The reproduction test is committed before the fix. So `test/rubocop_fallback_test.rb` itself must not call `refute`, `refute_*` or `assert !`. The fixture code lives in a string, which RuboCop does not lint.
- `intent.md` is `Type: bugfix`. After the reproduction commit, `plan.md` ends with the reproduction marker line, and the test guard refuses every edit under `test/`. The helper cleanup (order-of-work steps 3-4) edits 13 test files, so it runs as a second `test-writer` pass after the config fix is green. It needs Etienne's approval to remove that marker line first.

## Risks

- **CI never runs the new test.** `.github/workflows/dotfiles-tests.yml` installs only `minitest`, so the test skips there. You accepted this in the spec (flagged concern 2). The skip message must say why, so a skip is never read as a pass.
- **Skip check too loose.** If the test skips on any non-zero exit, a real offense (exit status 1) could turn into a skip. Only exit status 2 (RuboCop could not load the config) or a missing binary may skip. Exit status 1 must fail.
- **Behaviour change in the rewrite.** The local `assert_not(v)` is `assert_equal(false, !!v)`, which fails in exactly the cases where `refute(v)` fails. The only difference is the failure message. Accepted.
- **Ruby version.** CI runs Ruby 3.4, locally 4.0. Plain Minitest `refute` / `refute_match` behave the same on both.
- **Rejected:** deleting the sections, because omakase turns them back on. A YAML-only test, because it would have approved the broken deletion. Turning off `Rails/IndexBy` / `Rails/IndexWith`, which the spec left out of scope.

## Out of scope

- `rubocop-eirvandelden` (separate repo) and the `dotfiles-work` repo.
- The CI workflow.
- `Rails/IndexBy`, `Rails/IndexWith` and any other Rails cop.
- Running stow again, which is not needed: `~/.rubocop.yml` already links to the source file.

## Proof

- A plain test file with `refute`, `refute_match`, `assert !` gets no Rails assertion offense: `test/rubocop_fallback_test.rb` `test_fallback_reports_no_rails_assertion_offense_in_a_plain_minitest_file`.
- Autocorrect leaves those calls unchanged: `test/rubocop_fallback_test.rb` `test_fallback_autocorrect_leaves_refute_and_assert_bang_unchanged`.
- No test file defines its own `assert_not` / `assert_no_match`, and the suite passes: order-of-work step 6 (`git grep` prints nothing), plus the full `test/*_test.rb` run green.
- `assert_not_logged` still fails on a matching log line and passes on a non-matching one: `test/editor_test.rb` existing tests (`test_non_interactive_macos_selects_neovide_with_reuse_instance`, `test_headless_linux_falls_back_to_nvim`, and the others that call it) cover the passing case. The one-time mutation check in step 4 covers the failing case.
- `refute_command_ran` still fails when the command ran and passes when it didn't: `test/lefthook_pull_hooks_test.rb` existing test at line 111 covers the passing case. The mutation check in step 4 covers the failing case.
- A Rails project with `rubocop-eirvandelden`'s `config/rails.yml` still gets both cops: not an automated test (the spec accepted this). `rails.yml` still sets `Enabled: true` for both, and this change doesn't touch the gem.

Per changed file, the unit tests expected:

- `test/rubocop_fallback_test.rb`: the two tests above.
- The 13 rewritten test files: no new tests. Their existing tests must stay green.

Test setup: `Dir.mktmpdir` with a `test/sample_test.rb` fixture calling `refute(false)`, `refute_match(/a/, "b")`, `assert !false`. Run `Open3.capture3("rubocop", "-c", <repo>/rubocop/.rubocop.yml, "--format", "emacs", path)`. For autocorrect, add `-a` and compare file contents before and after.
