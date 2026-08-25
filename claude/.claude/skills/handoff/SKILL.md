---
name: handoff
description: Hand the plan for this task to a fresh Claude worker on sonnet, in a new Herdr tab.
disable-model-invocation: true
allowed-tools: Bash(/Users/etienne.vandelden/.config/herdr/scripts/hand-off-plan.sh *)
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
/Users/etienne.vandelden/.config/herdr/scripts/hand-off-plan.sh <absolute-plan-path>
```

Run it from the repository this work belongs to: the worker inherits that directory.

The script opens a background tab, starts Claude on sonnet there, and tells it to create its own
worktree before writing anything. The tab lands at the end of the tab list — Herdr cannot insert
one next to the current tab.

## 3. Report and stop

Tell the user which worker took the plan and where its tab is. The work is theirs now: do not
start on it, and do not check up on it unless asked.
