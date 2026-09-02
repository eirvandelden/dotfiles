# Token hygiene

## Session length

Around every 100 messages in a session, suggest running `/compact`. When the
conversation switches to an unrelated task, suggest `/clear` instead. Long
sessions re-send the whole history on every turn; splitting them is the
single biggest context saving.

## Test and build output

Run test suites fail-fast and trimmed — full passing output burns context
Claude ignores:

- Rails/Minitest: `bin/rails test ... 2>&1 | tail -20`, single failing file
  first, whole suite only when that's green
- RSpec: `--fail-fast`
- Jest: `--bail`
- pytest: `-x --tb=short`

Never re-run the identical failing command more than twice; change the
command (narrower scope, more diagnostics) or stop and reason instead.
