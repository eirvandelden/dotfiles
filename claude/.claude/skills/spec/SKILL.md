---
name: spec
description: Use once intent.md is accepted, before any plan or code — turns the accepted intent into requirements, design decisions and testable acceptance criteria at docs/changes/<slug>/spec.md, in a fresh pane by default.
arguments:
  - name: backend
    description: "(default) a fresh Sonnet pane to the right of the change's worktree via hand-off-plan.sh; \"here\": interview and write in this session instead."
---

# Spec

Turns an accepted `intent.md` into requirements a plan can be built from. Reads the intent, applies whichever domain skills match the work, and writes `docs/changes/<slug>/spec.md`. Every requirement in it must be testable — a requirement with no example is not done.

## Choosing a backend

- No argument, `HERDR_ENV` set: pane backend. A fresh agent with an empty context reads only the committed `intent.md` — no chat history from the coordinator crosses into the interview.
- `here`, or `HERDR_ENV` unset: run the interview in this session instead. Outside herdr this is the only option — say so in one line before starting, so the pane behaviour isn't silently missed.

## Pane backend

```bash
~/.config/herdr/scripts/hand-off-plan.sh spec <slug>
```

Run it from anywhere inside the repository. The script creates `.worktrees/<slug>` if it does not exist yet, splits a pane to the right of the caller, and starts a fresh Sonnet agent there, rooted in that worktree, told to invoke this skill's `here` backend for `docs/changes/<slug>`. Tell the user which worker took the spec stage and where its report will land, then carry on: the interview that follows is that pane's own.

`<slug>` must equal the branch name — the naming rule forbids a prefixed branch, and the script only reuses an existing `.worktrees/<slug>` when it is already checked out on that branch, refusing otherwise.

The pane writes `spec.md`, and once Etienne says "accepted", commits it alone, pushes the branch, writes a short report to the shared git directory, and sends one line back: `Spec ready: <path>`. It arrives as an ordinary message, possibly mid other work, and retries while the caller is busy — but the report is never lost, since the path was printed when the pane started. Read the file and tell the user what came back.

## `here` backend

### 1. Read the intent

Run `~/.claude/skills/plan/scripts/change-folder` for the folder path. Read `<folder>/intent.md`. Refuse and say why if its `Status:` line is not `accepted`.

### 2. Apply domain skills

Load whichever domain skills match what the intent describes (Rails architecture, API design, UI, dependencies, and so on). Name which ones were used at the bottom of `spec.md`, so a later reader knows what shaped the requirements.

### 3. Write `spec.md`

```markdown
# Spec: <title>

From `intent.md` (<date>). Status: draft.

## Flagged concerns

<policies or requirements that conflict, with the tradeoff named — omit the section if there are none>

## Requirements

<what the system must do>

## Design decisions

<choices made and why, only where intent left them open>

## Integration points

<other systems, APIs, or code this touches>

## Acceptance criteria

- <one concrete example per behaviour, in the domain's words, as a sentence a domain expert
  would agree with — "Paying empties the basket", not "calls Basket#pay">

---
Domain skills applied: <list, or "None">.
```

Each acceptance criterion becomes exactly one acceptance test later, at whatever level (system, request, feature) this repository already tests at. A requirement that cannot be written as an example is not clear enough yet — ask for the example rather than writing a vague one.

Flag conflicts your domain skills raise against each other or against the playbook at the top, under `## Flagged concerns`, rather than silently picking a side.

### 4. Accept

Refuse to flip `Status:` to `accepted` while any requirement has no matching acceptance criterion — name which one is missing. Otherwise, on the user's literal word "accepted", flip it, then commit `spec.md` alone: `docs: spec for <slug>`. Inside herdr (`HERDR_ENV` set), also start the plan stage yourself: `~/.config/herdr/scripts/hand-off-plan.sh plan <slug>`; if that command fails, say so and stop there instead of leaving it silent. Outside herdr, stop here.

## Codex

Same reading, writing and refusal rules. `here` is the only backend, since Codex has no herdr pane of its own; a Codex coordinator may still start a Claude spec pane through the same script, as `implement`/`review` do today. Invoked as `$spec`.
