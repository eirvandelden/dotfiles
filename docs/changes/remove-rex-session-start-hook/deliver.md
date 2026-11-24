# Delivery account: remove-rex-session-start-hook

## Behaviour delivered

A Claude session no longer runs `rex __internal session-start` at start. The SessionStart hook is gone from `claude/.claude/settings.json`, and the two tests that expected it now assert that no SessionStart command runs `rex`.

## Evidence

- Stub-`rex` check: `claude -p` with `HERDR_ENV` unset and the fixed settings left the stub log empty. Before the fix it logged `__internal session-start --agent claude`.
- Rubocop on both test files: no offenses.
- `bin/test` inside `delivery-evidence run`: 102 runs, 0 failures, 130 files, all at 6c5d653a.

## Review

One Claude round, no findings. The Codex review was not requested.

## Limits

The regression guard is a text heuristic and misses an absolute or quoted `rex` path. An earlier note about a hand-recorded full-suite entry is superseded by a note in the evidence.
