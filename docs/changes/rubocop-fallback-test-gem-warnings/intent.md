# Intent: RuboCop fallback test fails on RubyGems load warnings

Author: Etienne van Delden de la Haije. Status: accepted (2026-11-23). Type: bugfix.
Delivery: autonomous. Codex review: no.

## Problem

`test/rubocop_fallback_test.rb` fails all 16 tests on a machine where an installed gem has unbuilt native extensions. RubyGems then prints `Ignoring ffi-1.17.4 because its extensions are not built. Try: gem pristine ffi --version 1.17.4` on stderr each time RuboCop starts. The test demands an empty stderr, so it reports a RubyGems environment notice as a fallback failure. The fallback config itself works: RuboCop exits normally and its JSON report is correct.

## Proposed outcome

The fallback test passes when RuboCop's stderr holds only RubyGems "Ignoring … because its extensions are not built" notices. Any other stderr output, such as a crashing cop or a config warning, still fails the test.

## Affected users and systems

- `test/rubocop_fallback_test.rb`, both `run_fallback` and `run_with_project_fallback`.
- `bin/test` runs on Etienne's machines. CI is not affected today, because it has no unbuilt gems.

## Constraints

- Playbook rule 8: the fix never rebuilds, reinstalls or removes a gem (`gem pristine` is a system change).
- Playbook rule 14: the test keeps its strictness for real RuboCop errors on stderr.
- Permissions: none needed. No gem, system tool, migration or deploy file changes.

## In scope

- The stderr check in `test/rubocop_fallback_test.rb`.

## Out of scope

- Running `gem pristine ffi` or any other change to the installed gems.
- The other tests that assert an empty stderr (`question_wording_guard_test.rb`, `worktree_sweep_test.rb`): they run no RubyGems-loading subprocess that fails today.
- The fallback config `rubocop/.rubocop.yml`.

## Acceptance criteria

- With `ffi` installed without built extensions, `bin/test test/rubocop_fallback_test.rb` passes all 16 tests.
- When RuboCop prints a stderr line other than the RubyGems "Ignoring … extensions are not built" notice, the test fails and shows that line.
- On a machine with clean gems, the test results are the same as today.

## Decisions

- Tolerate only the unbuilt-extensions notice — the narrowest allowance keeps the test strict for every other stderr line.
- Deliver autonomously, no Codex review — a small test-only bug fix needs no extra gate or second reviewer.

## Open questions

None.
