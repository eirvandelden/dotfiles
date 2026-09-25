# Spec: every stage after intent runs in a fresh agent pane

From `intent.md` (2026-09-25). Status: accepted.

## Requirements

1. `spec`, `plan`, `implement` open, by default, a fresh agent in a new herdr pane rooted in the
   change's worktree, reading only the committed artifacts named by the change folder — no chat
   history crosses. `review` already does this (`start-review.sh`) and needs no behavior change.
2. The successor script generalizes `hand-off-plan.sh`: it takes a stage name (`spec`, `plan`,
   `implement`) and the change folder, not a literal artifact file. The pane derives its own
   paths (`change-folder`, then the stage's own upstream artifact) the same way `start-review.sh`'s
   reviewer already derives its own change folder and report path, rather than being handed one
   — a fixed path computed by the launcher would go stale the moment the pane checks out a
   different worktree.
3. `start-review.sh` is untouched. Only `hand-off-plan.sh` generalizes.
4. Per-stage model, matching playbook §7.24 (Opus for planning and research, Sonnet for
   implementing):
   - `spec`: Opus.
   - `plan`: Opus, started with `--permission-mode plan` (per intent's constraint) so the pane is
     already in plan mode.
   - `implement`: Sonnet (unchanged from today's `handoff` mode).
5. The stage's own conversation with Etienne — the interview, the literal word "accepted" —
   happens in that pane, not in the coordinator.
6. When Etienne accepts the stage's artifact in that pane: the pane commits the artifact alone,
   pushes the branch (`git push -u origin <branch>`; artifact-only commits pass the pre-push
   freshness check), writes a short report (what it decided, anything Etienne deferred) to a
   Markdown file in the shared git directory (`$(git rev-parse --path-format=absolute
   --git-common-dir)/herdr/<agent-name>.md`), sends the coordinator's pane one line naming that
   report's path, retrying up to twelve times while the coordinator is busy, then closes its own
   pane and stops.
7. Report-to and close-self both use `$HERDR_PANE_ID`:
   - Report-to: the launcher captures its own `$HERDR_PANE_ID` at launch time and bakes it into
     the stage pane's prompt, exactly as `hand-off-plan.sh` and `start-review.sh` already do.
   - Close-self: herdr sets `$HERDR_PANE_ID` in every pane's own environment, including the
     stage pane's. The stage pane reads that value from its own environment and runs
     `herdr pane close $HERDR_PANE_ID` on itself after sending the report line. No new herdr
     command is needed.
8. Etienne starts the next stage from the coordinator, one deliberate step at a time — the
   coordinator does not chain stages automatically.
9. `implement` keeps its `single` and `split` build logic, now behind an explicit `here`
   argument (mirroring `review`'s `here`/pane split). No argument is the new default: pane,
   rooted in the worktree, fresh Sonnet — what `handoff` mode does today. `here` keeps today's
   choice between `single` and `split` (three-or-more-criteria threshold), built in this session
   instead of a pane.
10. `finish` closes any of the change's stage panes still open when it runs, using
    `worktree-pane close` against the change's worktree path (the same close-if-idle,
    leave-open-if-an-agent-is-running behavior `worktree-pane close` already implements) — so a
    forgotten stage pane does not outlive the change folder it was reading.
11. Outside herdr, every stage falls back to the current session with a one-line notice, exactly
    as `review here` does today. Codex has no herdr pane of its own, so this is its only path;
    a Codex coordinator may still start Claude stage panes through the same script, as
    `handoff`/`review` do today.
12. `test/herdr_worker_scripts_test.rb` is rewritten for the generalized script's new contract
    (stage name + change folder, not a literal plan file) and gains coverage for the three
    stages it now drives (`spec`, `plan`, `implement`) plus the close-self behavior.

## Design decisions

- **Script scope stays narrow.** Only `hand-off-plan.sh` generalizes; `start-review.sh` stays as
  it is. Intent's affected-systems list names only `hand-off-plan.sh`, and review already meets
  the "fresh pane by default" bar — folding it into a shared script would touch working
  mechanics for no requirement gain.
- **Paths are derived, not passed.** `hand-off-plan.sh` today takes a literal plan file path.
  That only made sense because `implement handoff` hands off an *already-written*, accepted
  `plan.md` to build. `spec` and `plan` stages have no artifact to hand off — the fresh pane is
  what writes it. Generalizing to "stage name + change folder, pane derives the rest" covers all
  three stages with one contract instead of a special case per stage.
- **Self-close needs no new herdr surface.** `$HERDR_PANE_ID` is already set per-pane by herdr
  (this session itself reads it from its own environment); reusing it for self-close avoids
  inventing a `herdr pane current` lookup for a value already available for free.
- **`implement`'s explicit modes move behind `here`, not removed.** Removing `single`/`split`
  outright would take away steering a build from the coordinator's own session when that is
  genuinely wanted (per `implement`'s existing modes). Renaming the trigger to `here` keeps that
  option while matching `review`'s existing here/pane naming, so the two skills read the same
  way.

## Integration points

- `claude/.claude/skills/spec/SKILL.md`, `plan/SKILL.md`, `implement/SKILL.md`: each gains a
  "choosing a backend" section matching `review/SKILL.md`'s shape (pane by default inside herdr,
  `here` outside it or on request).
- `herdr/.config/herdr/scripts/hand-off-plan.sh`: generalizes to accept a stage name and change
  folder; still creates the worktree via `worktree-create --no-pane` when given a worktree name,
  still splits a pane down, still writes the empty report file before starting the pane.
- `git/.config/git/worktree-tools/worktree-pane`: `close` command reused by `finish` for leftover
  stage panes; no change to the script itself.
- `claude/.claude/skills/finish/SKILL.md`: gains a step closing the change's stage panes, if any
  remain, before or alongside removing `docs/changes/<slug>/`.
- `test/herdr_worker_scripts_test.rb`: rewritten for the generalized script.
- Codex links for `spec`, `plan`, `implement` (their `## Codex` sections): same fallback wording
  `review`'s already has — `here` is the only backend, since Codex has no herdr pane of its own.
- `docs/changes/ai-native-workflow/habits.md`: habits 2–4 (Spec, Plan, Implement) describe the
  new pane-by-default flow once this change lands, matching habit 5 (Review)'s existing wording.

## Acceptance criteria

- Running `/spec` inside herdr, with no `here` argument, opens a fresh Opus pane rooted in the
  change's worktree; the coordinator's own session is not the one reading `intent.md` or talking
  to Etienne about the spec.
- The spec pane interviews Etienne, and only the literal word "accepted" flips `spec.md`'s
  status; "looks fine" does not.
- Once accepted, the spec pane commits `spec.md` alone, pushes the branch, writes its report,
  sends the coordinator one line naming the report's path, closes its own pane, and the
  coordinator's pane is unaffected and still open.
- Running `/plan` the same way starts its pane already in plan mode, so no code is edited before
  Etienne accepts `plan.md`.
- Running `/implement` with no argument hands the accepted `plan.md` to a fresh Sonnet pane, the
  same as `/implement handoff` does today; running `/implement here` builds in the current
  session instead, picking `single` or `split` by the existing three-criteria rule.
- Running `/spec` outside herdr (no `HERDR_ENV`) runs the interview in the current session and
  prints one line saying the pane behavior was skipped, before doing anything else.
- Running `/finish` on a change that still has an idle stage pane open (its work done, report
  sent, but the pane itself never closed) closes that pane; a stage pane with an agent still
  running in it is left open, the same as `worktree-pane close` already behaves elsewhere.
- A coordinator pane that starts three stages in sequence (spec, then plan, then implement) never
  carries interview context between them — each stage pane, read on its own, has no way to know
  what was discussed in the one before it, because each reads only the committed artifacts.

---
Domain skills applied: dotfiles-maintenance.
