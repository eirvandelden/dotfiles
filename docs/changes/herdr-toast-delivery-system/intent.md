# Intent: Fix red CI on the herdr toast delivery test

Author: Etienne van Delden de la Haije. Status: accepted (2026-11-03). Type: bugfix. Delivery: autonomous. Codex review: no.

## Problem

The `Dotfiles tests` workflow fails on `main` and on open pull requests. `test/herdr_config_test.rb` expects `[ui.toast] delivery = "terminal"`, but commit `8363835d` set it to `"system"` on purpose. Etienne tested both values with `herdr notification show`; both gave the same macOS banner, so the test's premise (terminal delivery avoids a blocking notifier) is not proven.

## Proposed outcome

CI is green, and the test describes the config that Etienne wants: system delivery.

## Affected users and systems

- Etienne's herdr config at `herdr/.config/herdr/config.toml`.
- The `Dotfiles tests` GitHub Actions workflow.

## Constraints

- Keep the `state_text` sidebar row change from `8363835d`.
- Do not touch `claude/.claude/settings.json` or other uncommitted files in the main checkout.

## In scope

- Keep `delivery = "system"` in `herdr/.config/herdr/config.toml`.
- Update `test/herdr_config_test.rb` so it asserts `"system"` and its name no longer claims a terminal guarantee.

## Out of scope

- Fixing the herdr freeze that a hung `terminal-notifier` can cause.
- Any other herdr setting or other CI workflow.

## Acceptance criteria

- `ruby test/herdr_config_test.rb` passes with 0 failures.
- The full `test/*_test.rb` run on CI is green: 93 files, 0 failed.
- `herdr config check` accepts the config.

## Decisions

- Keep `"system"` and change the test — "set it back to system, that 'works'", because the CLI test showed no difference between the two values.

## Open questions

None.
