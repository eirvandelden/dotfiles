# Habits: what Etienne changes

Tooling makes the new way possible; habits make it happen. One habit per phase, adopted in this order. Each entry: the cue that triggers it, the habit, the tooling that backs it, and the old habit it replaces. Read this before starting any phase; re-read the current phase's entry at the start of each working day for the first two weeks of that phase.

The playbook's own rule for tuning applies to this file too: when the same slip happens twice, add the cue that would have caught it.

## Phase 1 — Start every change with `intent.md`

**Cue**: you are about to type a request that would change code — a bug, a feature, a refactor, a config change. Personal or work.

**Habit**: say `/intent` first (or "write the intent") and answer the questions. Do not describe the solution; describe what someone cannot do today and what better looks like. Accept the file before anything else happens. Small change? Still an intent — three lines is a valid intent.

**Backing**: the `intent` skill writes `docs/changes/<branch-slug>/intent.md`. Playbook §7.17 now says "no code before an accepted intent and plan". Later phases add a check that refuses a plan without an intent.

**Replaces**: starting in chat and letting the agent guess scope from the first message; plans appearing in `~/.claude/plans/` under random names.

**Slip to watch**: "this one is trivial, skip it". Trivial changes still get an intent; the plan may be one line.

## Phase 2 — Spec before plan, plan before code, accept each by name

**Cue**: the intent is accepted.

**Habit**: `/spec`, read it, and read the acceptance criteria twice: each one is a sentence you would say to a colleague about what the system does, and each one becomes a test. A requirement without an example is not done; ask for the example before anything else. Fix what is wrong, say "accepted". Then start plan mode, `/plan`, check that Proof names a test for every criterion and that step 1 is a failing acceptance test, interrogate it — "what could break?", "what is riskiest?", "what did you reject?" — until a new engineer could implement from `plan.md` alone. Then say "accepted" and let it implement. Do not approve with "ok" or "looks fine"; the word is "accepted" so the agent flips the status line.

**Backing**: `spec` and `plan` skills; plan mode refuses edits until you accept.

**Replaces**: agreeing to a plan in chat that never becomes a file; correcting course mid-build instead of in the document where correcting is cheap.

**Slip to watch**: accepting a plan you did not read. Ask one question per plan minimum.

## Phase 3 — Review reads the plan, not your memory

**Cue**: the agent says the work is done and tests are green.

**Habit**: run `/review-branch` before anything is pushed for others. Read findings worst first. Every finding is either fixed or explicitly dismissed with a reason in the report; nothing is left "for later".

**Backing**: `review-branch` report-only agent reading `REVIEW.md` + `plan.md` + `spec.md`; pre-push lefthook check fails when a change folder exists without a fresh review report.

**Replaces**: eyeballing the diff, or trusting the implementer session's own summary.

**Slip to watch**: editing code after the review and pushing without re-running it. The hook catches the stale report; the habit is to expect that and re-run.

## Phase 4 — Mistake twice → one line in the right file

**Cue**: an agent does something wrong that it (or another agent) already did before. You feel the "again?!".

**Habit**: stop. Decide where the correction belongs, add one line, move on:

- Applies to this repository only → the repo's `AGENTS.md` gotchas.
- Applies everywhere → playbook "Things agents get wrong here".
- Applies to one kind of task → that skill.
- Must never happen regardless of instructions → a hook or lefthook check.

**Backing**: playbook section exists and is capped at ten lines; `REVIEW.md` "do not report" grows the same way. Quarterly: remove lines that have not fired in three months.

**Replaces**: correcting in chat and losing the correction when the session ends.

**Slip to watch**: writing a paragraph. One line. If it needs more, it is a skill.

## Phase 5 — Finish means delete

**Cue**: personal — review clean, ready to merge. Work — ready for the team.

**Habit**: personal: `/finish-change`, then merge. Work: `/prepare-for-team`, check the PR body it wrote, then let it flip status and request reviewers. Never delete the folder by hand; never open the team PR by hand any more.

**Backing**: `finish-change` and `prepare-for-team` skills; ADR prompt for cross-application changes.

**Replaces**: leaving artifacts around, or forgetting them in a PR the team sees.

**Slip to watch**: work change that touches an API contract and you answer "no" to the ADR question to save time. The ADR is the only artifact that survives; it is the point.

## Phase 6 — Same file, either tool

**Cue**: Claude is capped, or the task needs a work integration Codex has and Claude does not, or you want a second opinion on a plan.

**Habit**: switch tools, not process. Open the other tool in the same worktree, point it at the change folder, continue from the file. For plans: have the other model critique `plan.md` before you accept it ("critically review this plan" — the `plan` skill's second role).

**Backing**: shared skills, drift test, both tools reading the same `docs/changes/<slug>/`.

**Replaces**: re-explaining the task in the second tool; Codex and Claude having different habits.

**Slip to watch**: pushing or opening a PR from Codex. Its guard is a prompt, not a block. Push from Claude until the Codex guard shim is verified.

## Phase 7 — Parallel only as wide as you can review

**Cue**: two independent tasks, both planned.

**Habit**: two worktrees, two sessions, each from its own `plan.md`. Not three until two feels boring. Review capacity, not agent capacity, is the limit.

**Backing**: `worktree-first`, `handoff` reading the change folder, herdr panes.

**Replaces**: one long session doing everything in sequence, or five sessions you cannot follow.

## Things to stop doing, from day one

- Reading `~/.claude/plans/`. It is no longer written to.
- Saying "just do it" to skip the intent. Say it to skip *discussion*, after the intent exists.
- Re-enabling a disabled plugin because a session felt less guided. Two weeks first; then decide with `/audit-token` numbers.
- Running `stow` from an agent session. New skill files need a re-stow; that is yours, by hand.

## How you will know it is working

Not metrics — out of scope — but three observable signs after a month:

1. You can open any in-flight branch and know what it is for without scrolling chat history.
2. A second session (or Codex) picks up a plan and needs no explanation.
3. Review findings repeat less, because the second time went into a file.
