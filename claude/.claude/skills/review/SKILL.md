---
name: review
description: Report-only review of this branch — a fresh reviewer in a herdr pane by default, or the reviewer agent forked in-session with "here".
disable-model-invocation: true
arguments:
  - name: backend
    description: "(default) a fresh reviewer in a herdr pane via start-review.sh; \"here\": the reviewer agent forked in-session instead."
---

# Review

Get this branch reviewed. Report-only: the reviewer reads `REVIEW.md` (or `REVIEW.local.md`),
`docs/changes/<slug>/spec.md` and `plan.md`, and the diff — branch vs base plus the uncommitted
changes on top — and appends a dated round to `docs/changes/<slug>/review.md`, which it commits
alone. It never edits code.

## Choosing a backend

- No argument, `HERDR_ENV` set: pane backend. A fresh agent with an empty context is the reason
  to review in a pane rather than this session, which has been steering the implementation and
  cannot see it fresh.
- `here`, or `HERDR_ENV` unset: fork the `reviewer` agent in this session (Agent tool,
  `subagent_type: reviewer`). Outside herdr this is the only option — say so in one line before
  running it, so the pane behaviour isn't silently missed.

## Pane backend

```bash
~/.config/herdr/scripts/start-review.sh
```

Run it from the repository being reviewed: the reviewer inherits that directory. The script
splits the current pane to the right, starts Claude on opus there, and points it at the
`reviewer` agent's instructions — the single source both backends read, so a pane review and an
in-session review ask the same questions. Tell the user which reviewer is looking at what, and
where its report will land, then carry on with work outside this branch's files: the reviewer
reads the uncommitted changes as they are now, so anything edited meanwhile makes its findings
describe a state that no longer exists.

The reviewer writes its round to `docs/changes/<slug>/review.md` and commits it, then sends one
line back: `Review ready: <path>`. It arrives as an ordinary message, possibly mid other work,
and retries while the caller is busy — but the report is never lost, since the path was printed
when the reviewer started.

## `here` backend

Dispatch the `reviewer` agent as a fork of this session. Give it the branch's base (same
resolution `start-review.sh` uses: `origin/HEAD`, else local `main`, else `master`) so it knows
what to diff against. Read its round back directly; there is no pane message to wait for.

## After either backend

Read `docs/changes/<slug>/review.md`, summarise the round worst first, and stop — do not start
fixing anything until the user says so. The `code-review` skill implements fixes: it writes
`fixed (<sha>)` or `dismissed: <reason>` on each finding's `→` slot, in the same commit as the
fix or its own commit.

A round left with an open finding and no newer round means the review is not closed; this skill
reports that plainly. The pre-push freshness check does not enforce closure, only recency — that
part is the habit, not the tool.

## Codex

Same report-only contract, same file. Spawn the `reviewer` agent (multi-agent tools); if
spawning is unavailable in the session, run the same instructions — read `REVIEW.md`/
`REVIEW.local.md`, `spec.md`, `plan.md`, the diff, write the round, commit it — in a fresh
`codex` session instead. `$review` invokes it; `here` is the only backend, since Codex has no
herdr pane of its own.
