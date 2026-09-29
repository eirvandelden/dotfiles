# Intent: Stop `Rails/RefuteMethods` and `Rails/AssertNot` firing in non-Rails repos

Author: coordinating agent (handoff). Status: accepted. Type: bugfix.

## Problem

The global RuboCop fallback, stowed from this repo's `rubocop/.rubocop.yml`, enables `Rails/AssertNot` and `Rails/RefuteMethods` for every `**/test/**/*` path, with no check that the project is a Rails application. In plain Minitest repositories (this repo, `dotfiles-work`), the pre-commit hook's `rubocop -a --force-exclusion` autocorrects `refute`, `refute_match`, `refute_includes`, and `assert !x` into `assert_not`, `assert_no_match`, `assert_not_includes` — methods that only exist on Rails' `ActiveSupport::TestCase`. The next commit then has tests calling undefined methods.

This has already cost real time: workers worked around it twice (2026-09-22, 2026-09-23) by defining local `assert_not`/`assert_no_match` helpers in test files, which two reviewers then flagged as duplication. `dotfiles-work`'s `test/finish_after_push_test.rb` kept `refute_includes` with a note instead.

The `rubocop-eirvandelden` gem already models the correct separation: `config/default.yml` disables the whole `Rails` department by default (`Rails: Enabled: false`) with a comment explaining exactly why — "every one of these cops suggests an ActiveSupport method, so in a plain Ruby project they autocorrect into a method that does not exist" — and `config/rails.yml` re-enables `Rails/AssertNot` and `Rails/RefuteMethods` as a layer a Rails project opts into. This repo's own global fallback config does not follow that pattern; it enables the two cops unconditionally.

## Proposed outcome

The global RuboCop fallback no longer enables `Rails/AssertNot` or `Rails/RefuteMethods` (or any other Rails-department cop) for repos that don't opt into the Rails layer. Rails projects that explicitly layer in `rubocop-eirvandelden`'s `config/rails.yml` keep getting both cops enforced, unchanged. The local `assert_not`/`assert_no_match` workaround helpers added to this repo's test files as a result of the bug are removed, since the cop that forced them is gone.

## Affected users and systems

- This repo (`~/Developer/dotfiles`) — its own test suite, and every machine that stows `rubocop/.rubocop.yml` as the global RuboCop fallback.
- `dotfiles-work` — its `test/finish_after_push_test.rb` currently keeps `refute_includes` with a note working around the same bug; fixed by this same global change, no separate PR needed there (out of scope for this change to touch, per the brief).
- Any other personal, non-Rails repo relying on the global fallback.
- Rails repositories are unaffected in outcome (cops still enforced via `rails.yml`) but are out of scope for changes in this task.

## Constraints

- Must not weaken `Rails/AssertNot` / `Rails/RefuteMethods` enforcement for actual Rails apps — they still opt in via `rubocop-eirvandelden`'s `config/rails.yml` layer.
- Only the Rails test-assertion cop family is in scope; no other cop.
- `rubocop-eirvandelden` gem changes (if any) go in `~/Developer/rubocop-eirvandelden`, a separate repository from this dotfiles checkout — spec/plan must call out if that repo needs touching at all, since the gem's `default.yml` already disables `Rails` by default.

## Open questions

None — the three open decisions from the handoff brief were confirmed with Etienne during this interview:

1. Fix lives in the global fallback (`rubocop/.rubocop.yml`); the gem's own default already matches the intended pattern, so gem changes are not expected but will be confirmed in spec.
2. The global fallback drops the two cops outright; Rails repos keep them via the gem's `rails.yml` layer.
3. The local `assert_not`/`assert_no_match` workaround helpers in this repo's test files are removed as part of this change.
