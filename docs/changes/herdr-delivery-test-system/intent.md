# Intent: Herdr notification delivery test expects system

Author: Etienne van Delden. Status: accepted. Type: chore.

## Problem

`test/herdr_config_test.rb` expects `[ui.toast] delivery = "terminal"`. The config sets `"system"`, and Etienne says `"system"` is correct. CI on `main` fails on this test.

## Proposed outcome

The test expects `"system"`. CI is green again.

## Affected users and systems

- `test/herdr_config_test.rb`.
- CI on `main` and on open branches.

## Constraints

- The config stays as it is.

## In scope

- Rename the test and change its expected value to `"system"`.

## Out of scope

- Any change to `herdr/.config/herdr/config.toml`.
- Any other test.

## Acceptance criteria

- `ruby test/herdr_config_test.rb` passes with no failure.

## Decisions

- `"system"` is the correct delivery — Etienne: "system should be the correct config for herdr".

## Open questions

None.
