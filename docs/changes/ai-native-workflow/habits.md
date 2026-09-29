# Habits: what Etienne changes

Tooling makes the new way possible; habits make it happen. The first six habits are the workflow, in the order a change moves: intent, spec, plan, implement, review, finish. They start together on the day phase 4 merges. The last three are cross-cutting and follow their phases. Each entry: the cue that triggers it, the habit, the tooling that backs it, the old habit it replaces, and the slip to watch. Read this before starting any phase; re-read the current entries at the start of each working day for the first two weeks.

The playbook's own rule for tuning applies to this file too: when the same slip happens twice, add the cue that would have caught it.

## 1. Intent — start every change with `intent.md`

**Cue**: you are about to type a request that would change code — a bug, a feature, a refactor, a config change. Personal or work.

**Habit**: say `/intent` first (or "write the intent") and answer the questions, one at a time. Give the issue number if there is one. Do not describe the solution; describe what someone cannot do today and what better looks like. Accept the file before anything else happens. Small change? Still an intent — three lines is a valid intent. `/intent handoff <slug-or-issue>` moves the interview to a fresh Opus pane below instead, when you would rather keep this session free. Either way, inside herdr, saying "accepted" also starts the spec stage on its own — no separate `/spec` needed.

**Backing**: the `intent` skill creates the worktree through `worktree-first` when needed and writes `docs/changes/<branch-slug>/intent.md`. Playbook §7.17 says "no code before an accepted intent and plan".

**Replaces**: starting in chat and letting the agent guess scope from the first message; plans appearing in `~/.claude/plans/` under random names.

**Slip to watch**: "this one is trivial, skip it". Trivial changes still get an intent; the plan may be one line.

## 2. Spec — no requirement without an example

**Cue**: the intent is accepted.

**Habit**: `/spec` opens a fresh Sonnet pane to the right of the change's worktree; the interview happens there, not in your coordinator session. Read the acceptance criteria twice. Each one is a sentence you would say to a colleague about what the system does, and each one becomes a test. A requirement without an example is not done; ask for the example before anything else. Fix what is wrong, then say "accepted" in that pane. It pushes, starts the plan stage on its own, reports back, and closes itself — you never have to go back to the coordinator to say "now plan it".

**Backing**: the `spec` skill refuses acceptance while a requirement has no example; pane by default, `here` without herdr.

**Replaces**: requirements that live in your head until the review finds the gap; steering the interview from a session that also carries the intent conversation.

**Slip to watch**: accepting criteria that describe the solution ("uses a background job") instead of the behaviour ("the export arrives by mail within a minute").

## 3. Plan — interrogate, then accept by name

**Cue**: the spec is accepted.

**Habit**: `/plan` opens a fresh Opus pane below the change's worktree; the interrogation happens there. It is told to write `plan.md` and touch nothing else in that worktree until you accept it — check it kept to that. Check that Proof names a test for every criterion and that step 1 is a failing acceptance test. Interrogate it — "what could break?", "what is riskiest?", "what did you reject?" — until a new engineer could implement from `plan.md` alone. For anything non-trivial, let the other model critique it first ("critically review this plan"). Then say "accepted" in that pane. Do not approve with "ok" or "looks fine"; the word is "accepted" so the agent flips the status line, pushes, starts the implement stage on its own, reports back, and closes itself.

**Backing**: `plan` skill's Write role; pane by default, no `--permission-mode plan` — a prompt instruction restrains it instead; `here` without herdr.

**Replaces**: agreeing to a plan in chat that never becomes a file; correcting course mid-build instead of in the document where correcting is cheap.

**Slip to watch**: accepting a plan you did not read. Ask one question per plan minimum.

## 4. Implement — steer through the plan, not through chat

**Cue**: the plan is accepted — usually not by you: the plan pane starts this stage itself the moment you say "accepted" there.

**Habit**: most of the time there is nothing to do here — watch the new pane arrive. `/implement` also still works on its own, to hand a plan to a fresh Sonnet worker pane by hand; `/implement here` builds in this session instead, when you want to steer it directly. Watch the first thing it does: the acceptance test must fail before any production code exists. If it does not, stop it. When you want to change direction mid-build, edit `plan.md` and say so; do not steer with chat corrections the plan never records. Three or more acceptance criteria: let `split` mode run, and expect two reports (tests, then implementation). The worker commits but does not push — that waits for `/review`.

**Backing**: `implement` skill, pane backend by default, `here` backend's `single`/`split` modes; the `implementer` agent cannot write test files; `plan.md` is updated in the same commit when the work departs from it.

**Replaces**: "just build it" followed by a long chat of corrections that a second session cannot see.

**Slip to watch**: saying "just do it" to skip the plan. Say it to skip *discussion*, after the plan exists.

## 5. Review — read the findings, close every one

**Cue**: the agent says the work is done and the Proof list is green.

**Habit**: run `/review` before anything is pushed for others. It opens a fresh reviewer in a pane; wait for `Review ready`. Read findings worst first. Every finding is either fixed or explicitly dismissed with a reason, written on its line in `docs/changes/<slug>/review.md`; nothing is left "for later". Change code after the review? Run it again.

**Backing**: `review` skill (pane by default, `here` without herdr) reading `REVIEW.md` + `plan.md` + `spec.md`; pre-push lefthook check fails when the newest code commit is newer than the newest `review.md` commit.

**Replaces**: eyeballing the diff, or trusting the implementer session's own summary.

**Slip to watch**: editing code after the review and pushing without re-running it. The hook catches the stale review; the habit is to expect that and re-run.

## 6. Finish — the change folder leaves with the change

**Cue**: personal — review closed, ready to merge. Work — ready for the team.

**Habit**: `/finish`, in both scopes. Both: check the PR body it wrote from the intent and plan, removes `docs/changes/<slug>/` (and `docs/changes/` itself when that was the last folder), commits, pushes, and creates or updates the PR — ending with it open in the browser. Personal: merge from there. Work: answer the ADR question honestly before the delete, then confirm the reviewer list once it opens the PR in your work browser profile; you set the review-board status on that page. Never delete the folder by hand.

**Backing**: the `finish` skill, scope detected from the remote; ADR prompt for cross-application changes at work.

**Replaces**: leaving artifacts around, or forgetting them in a PR the team sees.

**Slip to watch**: a work change that touches an API contract and you answer "no" to the ADR question to save time. The ADR is the only artifact that survives; it is the point.

## 7. Mistake twice → one line in the right file

**Cue**: an agent does something wrong that it (or another agent) already did before. You feel the "again?!".

**Habit**: stop. Decide where the correction belongs, add one line, move on:

- Applies to this repository only → the repo's `AGENTS.md` gotchas.
- Applies everywhere → playbook "Things agents get wrong here".
- Applies to one kind of task → that skill.
- Must never happen regardless of instructions → a hook or lefthook check.

**Backing**: playbook section exists and is capped at ten lines (phase 5); `REVIEW.md` "do not report" grows the same way. Quarterly: remove lines that have not fired in three months.

**Replaces**: correcting in chat and losing the correction when the session ends.

**Slip to watch**: writing a paragraph. One line. If it needs more, it is a skill.

## 8. Switch tools, not process

**Cue**: Claude is capped, or the task needs a work integration Codex has and Claude does not, or you want a second opinion on a plan.

**Habit**: open the other tool in the same worktree, point it at the change folder, continue from the file. For plans: have the other model critique `plan.md` before you accept it — the `plan` skill's second role.

**Backing**: shared skills, drift test, both tools reading the same `docs/changes/<slug>/` (phases 1 and 6).

**Replaces**: re-explaining the task in the second tool; Codex and Claude having different habits.

**Slip to watch**: pushing or opening a PR from Codex before phase 6 lands. Until then its guard is a prompt, not a block; push from Claude.

## 9. Parallel only as wide as you can review

**Cue**: two independent tasks, both planned.

**Habit**: two worktrees, two sessions, each from its own `plan.md`, each through `/implement`. Not three until two feels boring. Review capacity, not agent capacity, is the limit.

**Backing**: `worktree-first`, `/implement` sending each plan to its own pane, herdr panes.

**Replaces**: one long session doing everything in sequence, or five sessions you cannot follow.

## Things to stop doing, from day one

- Reading `~/.claude/plans/`. It is no longer written to.
- Steering a build with chat corrections. Edit `plan.md`.
- Re-enabling a disabled plugin because a session felt less guided. Two weeks first; then decide with `/audit-token` numbers.
- Running `stow` from an agent session. New skill files need a re-stow; that is yours, by hand.

## How you will know it is working

Not metrics — out of scope — but three observable signs after a month:

1. You can open any in-flight branch and know what it is for without scrolling chat history.
2. A second session (or Codex) picks up a plan and needs no explanation.
3. Review findings repeat less, because the second time went into a file.
