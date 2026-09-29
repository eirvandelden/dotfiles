# Spec: Stop `Rails/RefuteMethods` and `Rails/AssertNot` firing in non-Rails repos

From `intent.md` (2026-09-25). Status: accepted.

## Flagged concerns

1. **Intent contradicts itself on scope.** "Proposed outcome" says the fallback enables no Rails-department cop at all. "Constraints" says only the test-assertion cop family is in scope. The fallback also enables `Rails/IndexBy` and `Rails/IndexWith`, which have the same defect: run against a plain Ruby file on 2026-09-28, `Rails/IndexBy` flagged `[1].to_h { |x| [x.to_s, x] }` with "Prefer `index_by`", an ActiveSupport method. This spec follows the narrower constraint and leaves both cops alone. Removing them too would be one extra requirement and one extra acceptance criterion. Decide before accepting.
2. **CI cannot run RuboCop.** `.github/workflows/dotfiles-tests.yml` installs only `minitest`. The global fallback needs `rubocop` plus eight plugins and `rubocop-rails-omakase`, installed locally by `40_install_default_ruby_gems.sh`. A test that runs RuboCop either needs those gems installed in CI, which is a workflow change that needs approval (playbook §7 rule 13), or skips itself when RuboCop is missing, so CI never checks it. This spec takes the skip route and records it as a known gap. Say so if you want the workflow change instead. **Update 2026-09-29:** Etienne chose to install RuboCop and the plugins in CI after all, so the test runs there too.

## Requirements

1. The global fallback `rubocop/.rubocop.yml` explicitly turns off `Rails/AssertNot` and `Rails/RefuteMethods` with `Enabled: false`.
2. `rubocop-eirvandelden` (`~/Developer/rubocop-eirvandelden`) is not changed. Its `config/default.yml` already turns off the whole `Rails` department, and `config/rails.yml` turns both cops back on for Rails projects that add that layer.
3. The 13 test files in this repo that define local `assert_not` and/or `assert_no_match` helpers lose those helpers. Their call sites go back to plain Minitest `refute` and `refute_match`.
4. Two domain helpers keep their names and call sites but call `refute_match` directly: `assert_not_logged` in `test/editor_test.rb` and `refute_command_ran` in `test/lefthook_pull_hooks_test.rb`.
5. A new Minitest test runs the real `rubocop` binary with `rubocop/.rubocop.yml` against a fixture test file. It proves that the fallback neither reports nor autocorrects `refute`, `refute_match` or `assert !`. It skips itself, with a message saying why, when `rubocop` cannot load the config.

## Design decisions

- **`Enabled: false`, not deleting the two sections.** The old draft proposed deleting them on the grounds that `AllCops.DisabledByDefault: true` makes an absent cop count as disabled. That turned out to be wrong. The fallback starts with `inherit_gem: rubocop-rails-omakase`, and omakase declares both cops for `test/**/*`. Checked on 2026-09-28 against a fixture file:
  - current config: 3 offenses (`refute`, `refute_match`, `assert !`)
  - both sections deleted: the same 3 offenses
  - both set to `Enabled: false`: 0 offenses, and `rubocop -a` leaves the file unchanged
- **The test checks what RuboCop does, not what the YAML says.** Reading the YAML alone would have approved the deleted-sections version that doesn't work. Only running RuboCop proves the fix works.
- **Deleted helpers become plain `refute`/`refute_match`.** They behave the same. The local `assert_not(value)` is `assert_equal(false, !!value)`, which fails in exactly the cases where `refute(value)` fails. The local `assert_no_match` is `assert_not(pattern.match?(value))`, which fails in exactly the cases where `refute_match` fails. Any custom failure message moves across as the `refute_match` message argument.
- **Fixture lives in a temporary folder.** The test writes the fixture file to a temporary `test/` folder, the same way `test/stow_package_roots_test.rb` builds its fixture repositories. The fixture never touches this repo's own files.

## Integration points

- `lefthook.yml` `pre-commit.commands.rubocop` (`rubocop -a --force-exclusion`) is where the bug turns into broken tests. It stays unchanged; the new test runs the same `rubocop -a`.
- `rubocop-rails-omakase` (inherited gem) declares the two cops. It is the reason the fix needs `Enabled: false`. Not changed.
- `~/.rubocop.yml` is the stowed link to `rubocop/.rubocop.yml`. The fix reaches other repos with no restow, because the link already points at the source file.
- `dotfiles-work`'s `test/finish_after_push_test.rb` benefits automatically. It is not touched in this change.
- `.github/workflows/dotfiles-tests.yml`: not changed. See flagged concern 2.

## Acceptance criteria

- A plain Minitest test file that calls `refute`, `refute_match` and `assert !` gets no `Rails/RefuteMethods` or `Rails/AssertNot` offense from the global fallback.
- Autocorrecting that same file with the global fallback leaves `refute`, `refute_match` and `assert !` as they were.
- No test file in this repo defines its own `assert_not` or `assert_no_match`, and the full test suite still passes.
- A log line that matches the pattern given to `assert_not_logged` still fails the editor test, and a line that doesn't match still passes.
- A command that ran still fails `refute_command_ran`, and a command that didn't run still passes.
- A Rails project that adds `rubocop-eirvandelden`'s `config/rails.yml` still gets `Rails/RefuteMethods` and `Rails/AssertNot`: that file still sets `Enabled: true` for both, and this change doesn't touch the gem.

---
Domain skills applied: `dotfiles-maintenance`.
