---
name: spec
description: Use once intent.md is accepted, before any plan or code — turns the accepted intent into requirements, design decisions and testable acceptance criteria at docs/changes/<slug>/spec.md.
---

# Spec

Turns an accepted `intent.md` into requirements a plan can be built from. Reads the intent,
applies whichever domain skills match the work, and writes `docs/changes/<slug>/spec.md`. Every
requirement in it must be testable — a requirement with no example is not done.

## 1. Read the intent

Run `claude/.claude/skills/plan/scripts/change-folder` (installed at
`~/.claude/skills/plan/scripts/change-folder`) for the folder path. Read `<folder>/intent.md`.
Refuse and say why if its `Status:` line is not `accepted`.

## 2. Apply domain skills

Load whichever domain skills match what the intent describes (Rails architecture, API design,
UI, dependencies, and so on). Name which ones were used at the bottom of `spec.md`, so a later
reader knows what shaped the requirements.

## 3. Write `spec.md`

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

Each acceptance criterion becomes exactly one acceptance test later, at whatever level (system,
request, feature) this repository already tests at. A requirement that cannot be written as an
example is not clear enough yet — ask for the example rather than writing a vague one.

Flag conflicts your domain skills raise against each other or against the playbook at the top,
under `## Flagged concerns`, rather than silently picking a side.

## 4. Accept

Refuse to flip `Status:` to `accepted` while any requirement has no matching acceptance
criterion — name which one is missing. Otherwise, on the user's "accepted", flip it.

## Codex

Same reading, writing and refusal rules. Invoked as `$spec`.
