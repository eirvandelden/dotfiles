---
name: handoff
description: Hand the plan for this task to a fresh Claude worker on sonnet, in a new Herdr tab.
disable-model-invocation: true
allowed-tools: Bash(~/.config/herdr/scripts/hand-off-plan.sh *)
---

# Handoff

Hand this task's plan to another worker and stop. Do not implement the plan yourself.

## 1. Make sure a self-contained plan exists

The worker gets the plan file and nothing else — no conversation, no follow-up questions.

- This session already wrote a plan under `~/.claude/plans/`: use that file.
- Otherwise: write one to `~/.claude/plans/<kebab-case-task-slug>.md` following the
  `plan-handoff` skill's rules for writing a plan for another agent — context, concrete steps,
  files involved, verification, explicit out-of-scope list, and no references back to this chat.

## 2. Hand it over

```bash
~/.config/herdr/scripts/hand-off-plan.sh <absolute-plan-path>
```

Run it from the repository this work belongs to. The worker starts in that repository's main
checkout even when you call this from a worktree, so it can branch off cleanly instead of landing
on the branch you are on.

The script opens a background tab, starts Claude on sonnet there, and tells it to create its own
worktree before writing anything. The tab lands at the end of the tab list — Herdr cannot insert
one next to the current tab.

## 3. Report and stop

Tell the user which worker took the plan, using the name the script printed, and where its report
will land. The work is theirs now: do not start on it, and do not check up on it unless asked.

## When the worker finishes

The worker writes what it did, and anything it could not finish, to a Markdown file inside the
repository's shared git directory, then sends you one line: `Handoff done: <path>`. It arrives as
an ordinary message, possibly in the middle of other work, and it retries while you are busy — but
the report is never lost either way, because the script printed the path when it started.

Read the file and tell the user what came back. Do not pick up the leftovers yourself unless the
user asks.

Reports pile up in that directory over time. Nothing prunes it — that is the user's to clear.
