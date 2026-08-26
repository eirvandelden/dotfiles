---
name: review
description: Ask a Claude reviewer on opus to review this branch in a pane beside the current one.
---

# Review

Get this branch reviewed by another model. Do not review it yourself.

```bash
~/.config/herdr/scripts/start-review.sh
```

Run it from the repository being reviewed: the reviewer inherits that directory.

The script splits the current pane to the right, starts Claude on opus there, and asks it to read
the branch diff against the base branch plus the uncommitted changes, and to report findings
without changing code.

Tell the user which reviewer is looking at what, and where its report will land. Then carry on
with whatever you were doing.

## When the review comes back

The reviewer writes its findings to a Markdown file inside the repository's git directory, then
sends you one line: `Review ready: <path>`. That line arrives as an ordinary message, possibly in
the middle of other work.

Read the file and summarise the findings for the user, worst first. Do not start fixing anything
until the user says so — the reviewer works on the same files you do, and two agents editing them
at once will clobber each other.
