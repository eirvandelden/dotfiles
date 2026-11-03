# Plan: Fix red CI on the herdr toast delivery test

From `intent.md` (2026-11-03). Status: accepted.

## Design

### Domain terms

- **Toast delivery** — the `delivery` value in the `[ui.toast]` section of `herdr/.config/herdr/config.toml`. herdr accepts `"terminal"` and `"system"`. New term; no glossary conflict.
- **Test file** — one `test/*_test.rb`, run as its own process (glossary).
- **Runner** — `bin/test` (glossary).

### Diagrams

Not affected: one test method changes. No objects, tables or flows change.

### Signatures

`HerdrConfigTest` (`test/herdr_config_test.rb`) checks that the tracked herdr config holds the agreed settings.

The method `test_notifications_go_through_the_terminal_so_no_notifier_program_can_block_the_client` becomes:

```ruby
  def test_notifications_are_delivered_by_the_system
    assert_equal("system", toast_delivery)
  end
```

The private helper `toast_delivery` stays as it is. It still calls `flunk` when the section or the key is missing. No other method changes.

Not checked: the dotfiles repository declined Steep and rbs_rails; test methods carry no signatures.

### Complexity

Not affected: one file read and two regex matches, as before.

### Invariants

- `[ui.toast] delivery` in `herdr/.config/herdr/config.toml` is `"system"`. Enforced by `HerdrConfigTest#test_notifications_are_delivered_by_the_system`.
- herdr accepts the config. Enforced by the existing `HerdrConfigTest#test_herdr_accepts_the_config`, which skips where herdr is not installed, as on CI.

### Alternatives

1. Rename the test and assert `"system"`. Chosen: it is the agreed outcome and the smallest change.
2. Assert only that the value is one herdr accepts (`"terminal"` or `"system"`). Rejected: `intent.md` asks the test to describe the config Etienne wants, so it must pin `"system"`; a valid-value check also duplicates `test_herdr_accepts_the_config`.
3. Delete the test and rely on `test_herdr_accepts_the_config`. Rejected: that test skips on CI, so CI would no longer check the value at all.
4. Drift-resistant variant: scan every live `delivery` line and every `[ui.toast]` table, assert exactly one of each, and add a reason comment above `delivery` in `config.toml`. Rejected: the extra cases (a duplicate key, a second table) are invalid TOML that herdr itself rejects, and the config comment falls outside the in-scope file list of `intent.md`.

## Design decisions

- Test name `test_notifications_are_delivered_by_the_system`: it states the configured behaviour and makes no claim about blocking. This follows `intent.md`'s `## Decisions`; there is no conflict.
- No explaining comment in `config.toml`: `intent.md` scopes the change to the test file and keeps the config as it is.

## Integration points

- `Dotfiles tests` GitHub Actions workflow (`.github/workflows/dotfiles-tests.yml`), which runs `bin/test` over every `test/*_test.rb`.
- herdr CLI (`herdr config check`), locally only.

## Files that change

- `test/herdr_config_test.rb` — rename the toast test and assert `"system"` instead of `"terminal"`.

Nothing else changes. `herdr/.config/herdr/config.toml` already holds `delivery = "system"` and the `state_text` sidebar row from `8363835d`; both stay.

## Order of work

1. Sync first (playbook rule 20, `sync` skill): `git fetch origin` and `git rebase origin/main`. At plan time the branch is 14 commits behind `origin/main`; none of them touches the two herdr files.
2. Run `ruby test/herdr_config_test.rb` and watch it fail: `Expected: "terminal"  Actual: "system"`. This is the red state CI shows today.
3. Edit the test method as in `### Signatures`.
4. Run `ruby test/herdr_config_test.rb`: 5 runs, 0 failures.
5. Run `HERDR_CONFIG_PATH="$PWD/herdr/.config/herdr/config.toml" herdr config check` and confirm exit status 0.
6. Run `bin/test`: 93 test files, 0 failed.
7. Lint: `unset GIT_DIR; rubocop --force-exclusion test/herdr_config_test.rb`. If RuboCop cannot load a plugin, stop and report it; never install a gem (playbook rules 8 and 11).
8. Re-read the diff. Commit only `test/herdr_config_test.rb`: `Assert system toast delivery in the herdr config test`.
9. Push the branch. The implement stage stops here. The coordinator then runs `review` and `deliver`, and confirms the `Dotfiles tests` run on the draft pull request is green.

## Risks

- herdr's `"system"` delivery once froze the client through a hung `terminal-notifier`. The renamed test no longer guards against that. `intent.md` puts that freeze out of scope, and Etienne chose `"system"` after he tested both values.
- On this machine RuboCop with the repository config fails: `cannot load such file -- rubocop-rbs_inline`. The gem is in `packages.conf` but not installed. The pre-commit RuboCop hook may refuse the commit. Installing it needs Etienne's consent.
- Another test file may fail on CI for an unrelated reason. Then playbook rule 25 applies, and the work stops for a separate fix.

Rejected: changing the config back to `"terminal"` (contradicts `intent.md`'s decision).

## Proof

- `ruby test/herdr_config_test.rb` passes with 0 failures → `test/herdr_config_test.rb` `HerdrConfigTest#test_notifications_are_delivered_by_the_system`
- The full `test/*_test.rb` run on CI is green, 93 files, 0 failed → check: `bin/test` locally, then the coordinator confirms the `Dotfiles tests` workflow run on the draft pull request is green
- `herdr config check` accepts the config → `test/herdr_config_test.rb` `HerdrConfigTest#test_herdr_accepts_the_config`, and check: `HERDR_CONFIG_PATH="$PWD/herdr/.config/herdr/config.toml" herdr config check` exits 0
- Invariant: toast delivery is `"system"`, enforced by `herdr/.config/herdr/config.toml` → `test/herdr_config_test.rb` `HerdrConfigTest#test_notifications_are_delivered_by_the_system`

Per changed file, the unit tests expected, named as behaviour:

- `test/herdr_config_test.rb`: `HerdrConfigTest#test_notifications_are_delivered_by_the_system`. The other four tests stay unchanged.

Test setup: none. The test reads the tracked `config.toml` directly.

Out of scope: the herdr freeze from a hung `terminal-notifier`; any other herdr setting; any other CI workflow; `claude/.claude/settings.json` and every other file.

---
Domain skills applied: software-design, glossary, ruby-style, rails-testing (Minitest conventions).

## Critique

### Round 1 (codex exec -p terra)

- The plan expects the output `Config: ok`, but the critic saw `config: ok` → fixed (step 5 and the Proof line now check the exit status, not the text)
- The plan commits and pushes without a rebase, and the branch is 14 commits behind origin/main → fixed (step 1 of Order of work now fetches and rebases onto origin/main)
- The plan asks for pull-request CI but never schedules `review` and `deliver` → fixed (step 9 and the Proof line now hand review, deliver and the CI check to the coordinator)
- The renamed test method has no inline RBS signature → dismissed: only 3 of 1357 test methods in test/ carry one, and test/herdr_config_test.rb has none, so the change matches the surrounding code
