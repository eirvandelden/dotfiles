# Intent: Keep design internals out of the PR body

Author: Etienne van Delden de la Haije. Status: accepted (2026-11-11). Type: bugfix.
Delivery: autonomous
Codex review: no

## Problem

Agents put signatures, proof, invariants and alternatives in pull request bodies. Etienne wants these only in `intent.md` and `plan.md`. The `fill-pr-template` script causes it: since commit `0298076e` (2026-10-12) it copies the plan's whole `## Design` section into the Implementation part, and it also appends the Proof criteria and the file list. No earlier session or branch changed this. The repository holds no branch that touches `fill-pr-template`.

## Proposed outcome

A PR body that `deliver` opens states the problem and outcome, and shows the Design's diagrams. It never holds signatures, complexity, invariants, alternatives, proof lines or the file list.

## Affected users and systems

- Etienne, as the reader of PR bodies.
- `agents/.agents/skills/finish/scripts/fill-pr-template`, called by `deliver`, and its test `test/fill_pr_template_test.rb`.
- The `deliver`, `finish` and `plan` skill text that describes the PR body, and any agent that writes a PR body by hand.

## Constraints

- The repository's own PR template still decides the headings; a heading nothing matches keeps its own text.
- Work and personal repositories behave the same.
- Playbook rule 5 stays: the body follows the repo's PR template.

## In scope

- `fill-pr-template` stops copying Signatures, Complexity, Invariants, Alternatives, Proof and Files that change into the body.
- The Design's diagrams and domain terms stay in the body.
- The skill text and playbook say what a PR body holds and what it never holds, so a hand-written body follows the same rule.

## Out of scope

- The content of `intent.md` and `plan.md`; they keep every section.
- The PR template of any repository.
- Reviewing or rewriting PR bodies that are already open.

## Acceptance criteria

- A plan with Signatures, Complexity, Invariants and Alternatives gives a body with none of those headings or their text.
- A plan with a Mermaid diagram in its Design gives a body that still holds the diagram.
- A plan with a Proof list gives a body with no Proof lines.
- A plan with a `Files that change` section gives a body with no file list.
- A template with a "Tests" heading keeps its own text instead of receiving Proof lines.
- The `deliver` skill text names what the body holds and what it leaves out.

## Flagged concerns

None.

## Decisions

- The file list stays out of the PR body — Etienne's note on the question: "not the file list".
- The body keeps the Design's diagrams and domain terms — Etienne answered "agreed" to the read-back that proposed it; no reason given.
- Autonomous delivery, no Codex review — Etienne's choice; no reason given.

## Open questions

None.
