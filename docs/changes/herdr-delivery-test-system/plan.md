# Plan: Herdr notification delivery test expects system

From `intent.md` (2026-11-04). Status: accepted.

## Design

Not affected: a one-line test change. No objects, signatures, complexity or invariants.

## Design decisions

None. The intent fixes the expected value.

## Integration points

None.

## Files that change

- `test/herdr_config_test.rb` — rename the delivery test and expect `"system"`.

## Order of work

1. Change the test.
2. Run `ruby test/herdr_config_test.rb`.

## Risks

None. The test only reads `config.toml`.

## Proof

- `ruby test/herdr_config_test.rb` passes with no failure → check: `ruby test/herdr_config_test.rb`

---
Domain skills applied: None.
