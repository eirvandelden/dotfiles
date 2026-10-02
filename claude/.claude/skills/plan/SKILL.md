---
name: plan
description: Use once intent.md is accepted, before any code — writes docs/changes/<slug>/plan.md in plan mode, critically reviews an existing plan, or absorbs a plan another agent should execute.
arguments:
  - name: backend
    description: "(default) a fresh Opus pane below via hand-off-plan.sh; \"here\": write in this session instead; \"here auto\": write, critique and accept without Etienne on a personal autonomous change."
---

# Plan

Three roles. Do only the one asked for.

## Write

### Choosing a backend

- No argument, `HERDR_ENV` set: pane backend. A fresh agent with an empty context reads only the committed `intent.md` — no chat history from the coordinator crosses into the interrogation.
- `here`, or `HERDR_ENV` unset: run in this session instead. Outside herdr this is the only option — say so in one line before starting, so the pane behaviour isn't silently missed.

### Pane backend

```bash
~/.config/herdr/scripts/hand-off-plan.sh plan <slug>
```

Run it from anywhere inside the repository. The script creates `.worktrees/<slug>` if it does not exist yet, splits a pane below the caller, and starts a fresh Opus agent there, rooted in that worktree, told to invoke this skill's Write role, `here` backend, for `docs/changes/<slug>` — and, in the same prompt, to write `plan.md` and touch nothing else in that worktree until Etienne says the literal word "accepted" or "agreed." Tell the user which worker took the plan stage and where its report will land, then carry on: the interrogation that follows is that pane's own.

`<slug>` must equal the branch name — the naming rule forbids a prefixed branch, and the script only reuses an existing `.worktrees/<slug>` when it is already checked out on that branch, refusing otherwise.

The pane writes `plan.md`, and once Etienne says "accepted" or "agreed", commits it alone, pushes the branch, writes a short report to the shared git directory, and sends one line back: `Plan ready: <path>`. It arrives as an ordinary message, possibly mid other work, and retries while the caller is busy — but the report is never lost, since the path was printed when the pane started. Read the file and tell the user what came back.

### `here` backend

Must run in plan mode — this is where the codebase gets read and the approach gets decided, so nothing is edited until the user accepts. Not already in plan mode: call `EnterPlanMode` before reading code (Codex: tell the user to run `/plan` first; there is no equivalent tool call).

1. Run `~/.claude/skills/plan/scripts/change-folder` for the folder path. Refuse and say why unless `<folder>/intent.md` exists and is `Status: accepted`; then read it.
2. Read the codebase enough to know which files change and in what order. Apply the domain skills that match the work (Rails architecture, API design, UI, dependencies, and so on). Flag conflicts they raise against each other or against the playbook in the plan, rather than silently picking a side.
3. Write `<folder>/plan.md`:

   ```markdown
   # Plan: <title>

   From `intent.md` (<date>). Status: draft.

   ## Design decisions

   <choices made and why, only where intent left them open>

   ## Integration points

   <other systems, APIs, or code this touches>

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

   ---
   Domain skills applied: <list, or "None">.
   ```

   `## Proof` is structured, not prose: one line per acceptance criterion from `intent.md` naming the test file and test name that proves it, then per changed file the unit tests expected. Step 1 of `## Order of work` is always the first failing acceptance test, run, watched fail — the walking skeleton.
4. Self-contained, no chat references: a plan is the only context its executor gets, whether that is this same session later, a fresh worker pane, or another agent entirely. State context, concrete steps, files, verification, and an explicit out-of-scope list — nothing assumes the reader was in this conversation. Phased plans: one file per phase, each stating which decisions need a conversation with the user before that phase starts.
5. Before offering acceptance, ask the user at least one interrogation question — "what could break", "what did you reject", "what's riskiest" — so the plan gets challenged before it is frozen.
6. For anything non-trivial, offer a second-model critique (below) before acceptance.
7. `Status: accepted` only on the user's literal word "accepted" or "agreed" — never on "looks fine" or "ok". On either word, commit `plan.md` alone: `docs: plan for <slug>`. Then push (`git push -u origin HEAD`). Inside herdr (`HERDR_ENV` set), start the implement stage, in its own fresh pane: `HERDR_PANE_ID=<coordinator> ~/.config/herdr/scripts/hand-off-plan.sh implement '<slug>'`, where `<coordinator>` is the pane id your starting prompt named if a stage pane started you, else your own `$HERDR_PANE_ID`. If that command fails, say so and do not retry — in a stage pane, in your report file, as your starting prompt says. Outside herdr, stop after the push. Either way, writing a plan is not permission for *this session* to implement it — deliver the plan and stop; the implementing, if it happens, happens in that other pane.

## Auto mode

Only valid when `intent.md` has `Delivery: autonomous`; otherwise refuse and say why. Invoked as the `auto` argument of the `here` backend, normally by `hand-off-plan.sh plan <slug> --auto`. It never asks Etienne anything and never starts the next stage; the coordinator does. A choice that would change the behaviour agreed in `intent.md` becomes a `Decision needed:` line in the report, not a guess.

1. Write `plan.md` as usual, with `Status: draft`.
2. Run the critique with the other model family's local CLI. A Claude author uses Codex: `codex exec -p terra -s read-only -o <findings-file> "<prompt>"`. A Codex author uses Claude: `claude -p --model opus --permission-mode plan "<prompt>"`. The prompt asks it to read `plan.md` and the code it names, and to list disagreements with reasons.
3. Record the result in `plan.md` under `## Critique`, as `### Round 1 (<critic>)` with one finding per list item, written `- <finding> → fixed (<what changed>)` or `- <finding> → dismissed: <reason>`. The closure is the text after the line's last arrow, so a reason or subject may not contain `→`. Indented sub-bullets may explain a closed finding. Fix the artifact for every `fixed` item.
4. Run `~/.claude/skills/plan/scripts/auto-accept plan.md`. It flips `Status: draft` to `Status: accepted` only on a personal origin with a closed critique. If it refuses, fix what it names; do not edit the status line by hand.
5. Commit `plan.md` alone (`docs: plan for <slug>`), push (`git push -u origin HEAD`) and report. Plan mode does not apply: the pane has no human to accept the plan. The `## Proof` structure still applies.

A critique CLI that fails or is missing is a blocker: put it in the report as a `Decision needed:` line. Never skip the critique.

## Critique

Read the plan, then read the actual code it touches. Be critical: does the approach hold? Can it be done better? Verify the plan's claims against the code — a file it says exists, a pattern it says is already used, a test level it assumes. Report disagreements with reasons and propose the better alternative. Meant for a second model: `codex -p terra` reviewing a Claude-written plan, or an Opus session reviewing one Sonnet wrote.

## Execute a handed-over plan

- Read the project's `AGENTS.md` fully first, following links — the shared playbook already applies from the user config.
- Execute only the assigned phase or scope — nothing beyond it, no handing the work onward.
- An approved plan means: stop asking what to do next; work through it.
- When the plan no longer matches reality (main moved, a file it names is gone), rebase, re-verify the plan against the current code, and report the difference instead of improvising.
- Done = all tests green, all linters green, self-reviewed diff (playbook §7).

This role exists for a plan handed over outside the artifact chain (a plan pasted in, or one without a `docs/changes/<slug>/` folder). A plan that does live in that folder is executed by the `implement` skill instead, which reads `plan.md`'s structured `## Proof` directly.

## Codex

Same three roles. `plan` role needs Codex's own plan mode (`/plan`); `here` is the only backend, since Codex has no herdr pane of its own. `critique` role is what `codex -p terra` is for. In auto mode a Codex author runs the critique with Claude: `claude -p --model opus --permission-mode plan "<prompt>"`.
