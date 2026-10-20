# Intent: Lean test rule

Author: Etienne van Delden de la Haije. Status: accepted. Type: chore. Delivery: autonomous

## Problem

Playbook rule 3 says "never generate code without a corresponding test". Agents write many tests that add little: tests for private methods, tests for configuration, and unit tests that restate the implementation.

## Proposed outcome

Rule 3 asks for tests where they pay off. Every code change has tests, configuration has none, a new feature has an integration test, and private methods have no tests of their own.

## Affected users and systems

Etienne and every agent that reads the playbook, in Claude and Codex. The rule is mirrored in `agents.md`, `claude/.claude/PLAYBOOK.md`, `claude/.claude/core-values.yml`, the `rails-testing`, `implement`, `plan`, `code-review` and `hotwire-native` skills, and the `test-writer` and `implementer` agents for Claude and Codex. `test/mobile_testing_exception_test.rb` checks these mirrors.

## Constraints

- Every mirror carries the same wording, and the drift test enforces it.
- No new dependencies, system tools, destructive migrations or deploy files.
- Bug fixes keep the regression test first.

## In scope

- Rewrite rule 3 in every mirror:
  - All code changes need tests.
  - Configuration needs no tests.
  - A new feature needs an integration test that proves it works and keeps working, in addition to unit tests of its public methods and classes.
  - Private methods never need tests. Only public methods and classes do.
  - Tests no longer need to be written before the code, except the regression test of a bug fix.
- Delete the mobile exception paragraph in every mirror, since the new rule covers it.
- Rewrite `test/mobile_testing_exception_test.rb` (rename it if it no longer fits) so it checks the new wording in every mirror.

## Out of scope

- The `implement` red/green loop and the `test-writer`/`implementer` split stay test-first by design. Only their scope wording changes.
- Changes to `systematic-debugging`, `37signals-style` and `rails-guides` reference texts.
- Removing existing tests from any repository.

## Acceptance criteria

- Playbook rule 3 states that code changes need tests and configuration does not.
- Playbook rule 3 states that a new feature needs an integration test in addition to unit tests.
- Playbook rule 3 states that private methods never need tests and public methods and classes do.
- Playbook rule 3 states that a bug fix still gets its regression test first.
- No mirror still says "never generate code without a corresponding test" or carries the mobile exception.
- The drift test fails when one mirror differs from the playbook and passes when they all agree.
- The full test suite and the linters are green.

## Decisions

- Test-first is dropped for work other than bug fixes — "Drop test-first for non-bugfix", tests must exist but may follow the code.
- A new feature gets an integration test in addition to unit tests — chosen over "integration test replaces units".
- All mirrors get the new wording — one consistent rule.
- The `implement` pipeline stays test-first — chosen over making test-first optional there.
- The mobile exception is deleted — the new global rule makes it redundant.
- Delivery is autonomous — no reason given.

## Open questions

None.
