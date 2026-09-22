---
name: plan
description: Use once spec.md is accepted, before any code — writes docs/changes/<slug>/plan.md in plan mode, critically reviews an existing plan, or absorbs a plan another agent should execute.
---

# Plan

Three roles. Do only the one asked for.

## Write

Must run in plan mode — this is where the codebase gets read and the approach gets decided, so
nothing is edited until the user accepts. Not already in plan mode: call `EnterPlanMode` before
reading code (Codex: tell the user to run `/plan` first; there is no equivalent tool call).

1. Run `claude/.claude/skills/plan/scripts/change-folder` for the folder path. Read
   `<folder>/intent.md` and `<folder>/spec.md`; refuse and say why if either is not
   `Status: accepted`.
2. Read the codebase enough to know which files change and in what order.
3. Write `<folder>/plan.md`:

   ```markdown
   # Plan: <title>

   From `intent.md` and `spec.md` (<date>). Status: draft.

   ## Files that change

   <path — what changes and why>

   ## Order of work

   1. Write the acceptance test for the first acceptance criterion, run it, watch it fail.
   2. <next step>
   ...

   ## Risks

   <what could break, what was rejected and why>

   ## Proof

   - <acceptance criterion> → `<test file>` `<test name>`
   ...

   Per changed file, the unit tests expected, named as behaviour:
   - `<file>`: `<Thing#does_this>`, `<refuses that>`, ...

   Test setup: <fixtures, test data, faked boundaries — short; if this paragraph grows long,
   the change is too big and should be split>
   ```

   `## Proof` is structured, not prose: one line per acceptance criterion naming the test file
   and test name that proves it, then per changed file the unit tests expected. Step 1 of
   `## Order of work` is always the first failing acceptance test, run, watched fail — the
   walking skeleton.
4. Self-contained, no chat references: a plan is the only context its executor gets, whether
   that is this same session later, `implement handoff`, or another agent entirely. State
   context, concrete steps, files, verification, and an explicit out-of-scope list — nothing
   assumes the reader was in this conversation. Phased plans: one file per phase, each stating
   which decisions need a conversation with the user before that phase starts.
5. Before offering acceptance, ask the user at least one interrogation question — "what could
   break", "what did you reject", "what's riskiest" — so the plan gets challenged before it is
   frozen.
6. For anything non-trivial, offer a second-model critique (below) before acceptance.
7. `Status: accepted` only on the user's literal word "accepted" — never on "looks fine" or
   "ok". Writing a plan is not permission to implement it; deliver the plan and stop.

## Critique

Read the plan, then read the actual code it touches. Be critical: does the approach hold? Can it
be done better? Verify the plan's claims against the code — a file it says exists, a pattern it
says is already used, a test level it assumes. Report disagreements with reasons and propose the
better alternative. Meant for a second model: `codex -p terra` reviewing a Claude-written plan,
or an Opus session reviewing one Sonnet wrote.

## Execute a handed-over plan

- Read the project's `AGENTS.md` fully first, following links — the shared playbook already
  applies from the user config.
- Execute only the assigned phase or scope — nothing beyond it, no handing the work onward.
- An approved plan means: stop asking what to do next; work through it.
- When the plan no longer matches reality (main moved, a file it names is gone), rebase,
  re-verify the plan against the current code, and report the difference instead of improvising.
- Done = all tests green, all linters green, self-reviewed diff (playbook §7).

This role exists for a plan handed over outside the artifact chain (a plan pasted in, or one
without a `docs/changes/<slug>/` folder). A plan that does live in that folder is executed by the
`implement` skill instead, which reads `plan.md`'s structured `## Proof` directly.

## Codex

Same three roles. `plan` role needs Codex's own plan mode (`/plan`); `critique` role is what
`codex -p terra` is for.
