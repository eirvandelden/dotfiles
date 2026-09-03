# Token hygiene

## Session length

Around every 100 messages in a session, suggest running `/compact`. When the
conversation switches to an unrelated task, suggest `/clear` instead. Long
sessions re-send the whole history on every turn; splitting them is the
single biggest context saving.

## Test and build output

Covered by `agents.md` rule 23 (Test runs and output) — that file is
project instructions in every personal repo, not Claude-only, so the rule
lives there instead of being duplicated here.
