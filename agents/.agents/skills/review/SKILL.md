---
name: review
description: Reviews this branch — a fresh reviewer in a herdr pane by default, or the reviewer agent forked in-session with "here". The reviewer stays report-only; a clean review hands over to the deliver skill, which opens the draft PR.
disable-model-invocation: true
arguments:
  - name: backend
    description: "(default) a fresh reviewer in a herdr pane via start-review.sh; \"here\": the reviewer agent forked in-session instead."
---

# Review

Get this branch reviewed. The reviewer is report-only: it reads `REVIEW.md` (or `REVIEW.local.md`), `docs/changes/<slug>/intent.md` and `plan.md`, and the diff — branch vs base plus the uncommitted changes on top — and appends a dated round to `docs/changes/<slug>/review.md`, which it leaves uncommitted until the review converges, then commits alone through `commit-review` and pushes. It never edits code.

## Choosing a backend

- No argument, `HERDR_ENV` set: pane backend. A fresh agent with an empty context is the reason to review in a pane rather than this session, which has been steering the implementation and cannot see it fresh.
- `here`, or `HERDR_ENV` unset: fork the `reviewer` agent in this session (Agent tool, `subagent_type: reviewer`). Outside herdr this is the only option — say so in one line before running it, so the pane behaviour isn't silently missed.

## Pane backend

```bash
~/.config/herdr/scripts/start-review.sh
```

Run it from the repository being reviewed: the reviewer inherits that directory. The script opens the next column of the change's row, right of its last pane (right of the current pane on a branch with no change folder), starts Claude on opus there, and points it at the `reviewer` agent's instructions — the single source both backends read, so a pane review and an in-session review ask the same questions. Tell the user which reviewer is looking at what, and where its report will land, then carry on with work outside this branch's files: the reviewer reads the uncommitted changes as they are now, so anything edited meanwhile makes its findings describe a state that no longer exists.

The reviewer writes its round to `docs/changes/<slug>/review.md` and leaves it uncommitted. It runs `~/.claude/skills/review/scripts/commit-review`, which commits that file alone only when no finding is open, and pushes the branch only when `commit-review` exits 0. Then it runs `deliver --check`. It sends one line back: `Review clean: <path>` when that exits 0 (no open finding, review fresh), else `Review ready: <path>`. It arrives as an ordinary message, possibly mid other work, and retries while the caller is busy — but the report is never lost, since the path was printed when the reviewer started.

## `here` backend

Dispatch the `reviewer` agent as a fork of this session. Give it the branch's base (same resolution `start-review.sh` uses: `origin/HEAD`, else local `main`, else `master`) so it knows what to diff against. Read its round back directly; there is no pane message to wait for.

## After either backend

Outside auto mode, read the signal and act on it:

- `Review clean: <path>` (or, in the `here` backend, `~/.claude/skills/deliver/scripts/deliver --check` exiting 0): the review is closed. Read `~/.claude/skills/deliver/SKILL.md` and run `deliver` without asking. Report what it printed, as that skill says.
- `Review ready: <path>`: read `docs/changes/<slug>/review.md`, summarise the round worst first, and stop. Do not start fixing anything until the user says so.

The `code-review` skill implements fixes: it writes `fixed (<commit subject>)` or `dismissed: <reason>` on each finding's `→` slot, in the working tree, never in a commit of its own and never in the fix commit: `commit-review` commits `review.md` once the review converges. The subject, not the SHA, because a rebase changes the SHA but not the subject line. Any other text after the last `→`, or none, leaves the finding open. Its last step re-reviews, and a clean re-review ends in `Review clean:`, so delivery follows the last fix without a further command.

A round left with an open finding and no newer round means the review is not closed; `deliver --check` exits 1 and this skill reports that plainly. The pre-push freshness check does not enforce closure, only recency.

## Auto mode

Only valid when `intent.md` has `Delivery: autonomous`; the coordinator runs this, and "stop, do not start fixing" under "After either backend" does not apply, and this skill does not run `deliver`: the coordinator does, once a round of each enabled reviewer is clean (intent skill, Autonomous delivery). The Claude reviewer always looks at the diff. Run the Codex round only when `intent.md` records `Codex review: yes`; a missing field means `no`, and then never run `codex review`. With the Codex round enabled, run it before the Claude round: the `reviewer` agent's own `commit-review` then sees both rounds, so a Codex finding never forces a second `review.md` commit.

1. Claude: a Claude coordinator uses the `reviewer` agent through either backend above. A Codex coordinator uses the read-only Claude CLI backend below. A native Codex reviewer cannot replace this Claude round.
2. The Codex CLI, only on `Codex review: yes`: `codex review --base <base>`, with `<base>` resolved as in `start-review.sh`. The coordinator transcribes its output as its own round in `review.md`, in the reviewer's round format: the heading `## Round <n> — <UTC timestamp> — <short SHA reviewed>`, then one finding per line as ``- [ ] Important: <finding> — `<file>:<line>` →`` (or `Nit:`), with the `→` slot left empty to close. Add `(codex)` after the heading so the source is clear. Leave it uncommitted. Run `commit-review`; push the branch (`git push -u origin HEAD`) only when it exits 0. A Codex coordinator transcribes the rounds itself, so it runs `commit-review` once after the last.

Fix every finding through `code-review`, then run each enabled reviewer again. Repeat until a round of each enabled reviewer leaves no open finding. A finding disputed for two rounds goes to Etienne (see `code-review`).

### Read-only Claude CLI backend

Run `claude -p --model opus --permission-mode plan "<review prompt>"` from the worktree being reviewed. Pass the resolved base and the accepted intent and plan paths. Tell Claude to read the `reviewer` agent instructions and the repository's review rules. It must review the branch diff and uncommitted changes using all three passes.

State that this prompt replaces the reviewer's fetch step, write step, commit step and Output section. Do not fetch; diff against the passed base. Return findings to stdout in the round's line format, or `No findings.`. Never edit files, commit, or request plan approval. The coordinator writes the report instead and runs `commit-review`. On `Codex review: yes`, this backend runs the Codex round before the Claude round.

The coordinator transcribes the output into `review.md`, using the round format above with `(claude)` after the heading. Run `commit-review`; push the branch (`git push -u origin HEAD`) only when it exits 0. If Claude is unavailable or the review does not complete, report `Decision needed:`. Keep delivery blocked until every enabled reviewer completes its review.

## Codex

Same report-only contract, same file. Spawn the `reviewer` agent (multi-agent tools); if spawning is unavailable in the session, run the same instructions — read `REVIEW.md`/ `REVIEW.local.md`, `intent.md`, `plan.md`, the diff, write the round, run `commit-review` — in a fresh `codex` session instead. `$review` invokes it; `here` is the only backend, since Codex has no herdr pane of its own.

For autonomous delivery, follow Auto mode instead: run the read-only Claude CLI backend, plus the separate Codex review round only on `Codex review: yes`.
