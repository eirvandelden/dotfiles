# Intent: every stage after intent runs in a fresh agent pane

Author: Etienne van Delden. Status: accepted (2026-09-25). Type: feature.

## Problem

The session that runs `intent` keeps steering every later stage in the same context. By the time it writes `spec.md`, plans, implements and reads the review, it carries the whole conversation: assumptions from the interview, corrections made mid-build, the reviewer's earlier rounds. That is the context the artifact chain was built to leave behind — each stage was meant to start from the committed file alone. Today only `implement` can hand off to a fresh pane (`implement handoff`), and only when asked; `spec` and `plan` cannot at all, and `review` is the one stage where the fresh pane is already the default. The session that started `intent` also ends up crowded with stage output it does not need.

## Proposed outcome

The session that runs `intent` becomes the coordinator of the change. Each following stage — `spec`, `plan`, `implement`, `review` — opens by default as a fresh agent in a new pane, rooted in the change's worktree, reading only the committed artifacts. The stage's conversation with Etienne (the plan's interrogation, "accepted") happens in that pane. When Etienne accepts the stage's artifact there, the pane commits it, pushes the branch, reports one line back to the coordinator, and closes itself. Etienne then starts the next stage from the coordinator, one deliberate step at a time. `finish` runs in the coordinator. Outside herdr, every stage falls back to the current session with a one-line notice, as `review here` does today.

## Affected users and systems

Etienne, in Claude and Codex, in every repository. The `spec`, `plan`, `implement` and `review` skills and their Codex links; `herdr/.config/herdr/scripts/hand-off-plan.sh` (or a successor that starts a named stage in a pane rooted in an existing worktree — the `<worktree-name>` argument and `worktree-create` reuse from the `herdr-worktree-panes` change are the base); `test/herdr_worker_scripts_test.rb`; the `finish` skill (closing the change's stage panes it knows about, if any remain); `habits.md` of the umbrella change.

## Constraints

- Builds on `herdr-worktree-panes` (worker pane rooted in an existing worktree, `worktree-pane` reuse) — that change merges first.
- A stage pane must start from the artifacts only: no chat history crosses; the prompt names the change folder and the stage, nothing else.
- `plan` must still run in plan mode; a fresh Claude pane can be started with `--permission-mode plan`.
- Pushing an accepted stage must pass the pre-push freshness check: artifact-only commits are not code, so `review-report-fresh` exits 0 for spec and plan; after `implement`, the push waits for the review pane's round.
- Decided 2026-09-24: interaction in the stage's own pane; chaining by Etienne from the coordinator; fall back to in-session outside herdr; a stage pane closes itself after "accepted" and the push.
- Claude and Codex parity: the skills are one file; Codex has no herdr pane of its own, so it uses the in-session fallback, and a Codex coordinator may still start Claude panes through the same script, as `handoff`/`review` do today.

## Open questions

- How does a stage pane know which pane to report to and to close itself? `hand-off-plan.sh` already passes `$HERDR_PANE_ID` for the report; the close needs the pane's own id (`herdr pane current`). The spec decides the exact contract.
- Does `implement` keep its `here` and `split` modes as explicit options next to the new default? Likely yes; the spec confirms.
