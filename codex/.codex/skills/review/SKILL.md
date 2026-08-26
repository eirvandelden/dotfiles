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
the branch diff against the base branch plus the uncommitted changes, and to report its findings
without changing any code. The only file it writes is that report.

Tell the user which reviewer is looking at what, and where its report will land. Then carry on with
work outside this branch's files. The reviewer reads the uncommitted changes as they are now, so
anything you edit meanwhile makes its findings describe a state that no longer exists.

## When the review comes back

The reviewer writes its findings to a Markdown file inside the repository's shared git directory,
then sends you one line: `Review ready: <path>`. It arrives as an ordinary message, possibly in the
middle of other work, and it retries while you are busy — but a report is never lost either way,
because the script printed the path when it started.

Read the file and summarise the findings for the user, worst first. Do not start fixing anything
until the user says so — the reviewer works on the same files you do, and two agents editing them
at once will clobber each other.

Reports pile up in that directory over time. Nothing prunes it — that is the user's to clear.
