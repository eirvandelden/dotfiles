---
name: review
description: Ask a Claude reviewer on opus to review this branch in a pane beside the current one.
disable-model-invocation: true
allowed-tools: Bash(/Users/etienne.vandelden/.config/herdr/scripts/start-review.sh)
---

# Review

Get this branch reviewed by another model. Do not review it yourself.

```bash
/Users/etienne.vandelden/.config/herdr/scripts/start-review.sh
```

Run it from the repository being reviewed: the reviewer inherits that directory.

The script splits the current pane to the right, starts Claude on opus there, and asks it to read
the branch diff against the base branch plus the uncommitted changes, and to report findings
without changing code.

Tell the user which reviewer is looking at what. Its findings appear in its own pane, not here.
Only act on them when the user brings them back.
