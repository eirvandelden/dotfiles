---
name: rails-testing
description: Use when writing or reviewing Ruby/Rails tests, choosing test data setup, or deciding between Minitest and RSpec conventions.
---

# Rails Testing

## Framework choice

- Personal projects: Minitest, aim for idiomatic Ruby tests.
- Work projects: RSpec, follow advice from betterspecs.org.

## Style

- Think in behaviour-driven terms, even when using Minitest.
- Group related tests using nested classes instead of comment headers:
  - Use inner classes (`class WhenClosed < ActiveSupport::TestCase`) to create context groupings,
    mirroring RSpec's `context` blocks.
  - Never use comment headers (e.g. `# === given X ===`) to group tests.
- Focus on observable behaviour and outcomes.
- Write lots of integration tests (both personal and work): prefer request/integration/system
  tests for core flows. For APIs, test real HTTP requests, JSON parsing, status codes, and auth
  behavior.
- Test-driven development: all generated code must be driven from tests. If no test exists for the
  code you're about to write, create the test first.

## Data setup

- Personal projects: prefer Rails fixtures.
- Work projects: comfortable using FactoryBot.
- Test data selection discipline:
  - Before creating any object, scan existing fixtures/factories. Use one that already has the
    right state — no mutation needed.
  - If no suitable record exists, build the correct object directly with the right attributes from
    the start.
  - NEVER create a generic base object and then update it to fit the test.

See `references/examples.md` for the fixture/factory pattern.

## Front end tests

- Use `@hotwired/stimulus-testing` for Stimulus controllers.
- Run JavaScript tests with Jest in a separate repository or folder.
- Use Capybara system tests for Hotwire flows.
